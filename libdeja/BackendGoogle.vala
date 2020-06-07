/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

/**
 * This backend is for the consumer-focused storage offering by Google.
 * At the time of this writing, it is called Google Drive.
 *
 * See the following doc for more info on how we authorize ourselves:
 * https://developers.google.com/identity/protocols/OAuth2InstalledApp
 */

using GLib;

namespace DejaDup {

public const string GOOGLE_ROOT = "Google";
public const string GOOGLE_FOLDER_KEY = "folder";

public const string GOOGLE_SERVER = "google.com";

public class BackendGoogle : Backend
{
  Soup.Server server;
  Soup.Session session;
  string local_address;
  string pkce;
  string credentials_dir;
  string access_token;
  string refresh_token;

  public BackendGoogle(Settings? settings) {
    Object(settings: (settings != null ? settings : get_settings(GOOGLE_ROOT)));
  }

  construct {
    session = new Soup.Session();
    session.user_agent = "%s/%s ".printf(Config.PACKAGE, Config.VERSION);
  }

  public override async void cleanup() {
    clean_credentials_dir();
  }

  void clean_credentials_dir() {
    if (credentials_dir != null) {
      FileUtils.remove("%s/settings.yaml".printf(credentials_dir));
      FileUtils.remove("%s/credentials.json".printf(credentials_dir));
      FileUtils.remove(credentials_dir);
      credentials_dir = null;
    }
  }

  public override string[] get_dependencies()
  {
    return Config.PYDRIVE_PACKAGES.split(",");
  }

  public override bool is_native() {
    return false;
  }

  public override Icon? get_icon() {
    return new ThemedIcon("deja-dup-google-drive");
  }

  public override async bool is_ready(out string when) {
    when = _("Backup will begin when a network connection becomes available.");
    return yield Network.get().can_reach("https://%s/".printf(GOOGLE_SERVER));
  }

  public override string get_location(ref bool as_root)
  {
    var folder = get_folder_key(settings, GOOGLE_FOLDER_KEY);

    // The hostname is unused
    return "pydrive://google/%s".printf(folder);
  }

  public override string get_location_pretty()
  {
    var folder = get_folder_key(settings, GOOGLE_FOLDER_KEY);
    if (folder == "")
      return _("Google Drive");
    else
      // Translators: %s is a folder.
      return _("%s on Google Drive").printf(folder);
  }

  public override async uint64 get_space(bool free = true)
  {
    var message = Soup.Form.request_new(
      "GET",
      "https://www.googleapis.com/drive/v3/about",
      "access_token", access_token,
      "fields", "storageQuota"
    );
    Json.Reader reader;

    try {
      reader = yield send_message(message);
    }
    catch (Error e) {
      return INFINITE_SPACE;
    }

    // Parse metadata
    reader.read_member("storageQuota");
    if (!reader.read_member("limit"))
      return INFINITE_SPACE; // no limit present means an unlimited quota
    var limit = uint64.parse(reader.get_string_value());
    reader.end_member();
    reader.read_member("usage");
    var usage = uint64.parse(reader.get_string_value());
    reader.end_member();

    return free ? limit - usage : limit;
  }

  static Secret.Schema get_secret_schema()
  {
    return new Secret.Schema(
      Config.APPLICATION_ID + ".Google", Secret.SchemaFlags.NONE,
      "client_id", Secret.SchemaAttributeType.STRING
    );
  }

  void stop_login(string? reason)
  {
    var full_reason = _("Could not log into Google servers.");
    if (reason != null)
      full_reason = "%s %s".printf(full_reason, reason);

    envp_ready(false, null, full_reason);
  }

  async Json.Reader? send_message_raw(Soup.Message message) throws Error
  {
    var response = yield session.send_async(message);
    if (message.status_code != Soup.Status.OK)
      return null;
    var data = new uint8[5000]; // assume anything we read will be 5k or smaller
    yield response.read_all_async(data, GLib.Priority.DEFAULT, null, null);
    return new Json.Reader(Json.from_string((string)data));
  }

  async Json.Reader send_message(Soup.Message message) throws Error
  {
    var reader = yield send_message_raw(message);
    if (reader == null)
      throw new IOError.FAILED(message.reason_phrase);
    return reader;
  }

  async void get_tokens(Soup.Message message) throws Error
  {
    Json.Reader reader;

    try {
      reader = yield send_message_raw(message);
    }
    catch (Error e) {
      stop_login(e.message);
      return;
    }

    if (reader == null) {
      // Problem with authorization -- maybe we were revoked?
      // Let's restart the auth process.
      start_authorization();
      return;
    }

    // Parse token
    reader.read_member("access_token");
    access_token = reader.get_string_value();
    reader.end_member();
    if (reader.read_member("refresh_token")) {
      refresh_token = reader.get_string_value();
      yield store_credentials();
    }
    reader.end_member();

    got_credentials();
  }

  public static async string? lookup_refresh_token()
  {
    var schema = get_secret_schema();
    try {
      return Secret.password_lookup_sync(schema,
                                                  null,
                                                  "client_id",
                                                  Config.GOOGLE_CLIENT_ID);
    } catch (Error e) {
      // Ignore, just act like we didn't find it
      return null;
    }
  }

  public static async void clear_refresh_token()
  {
    var schema = get_secret_schema();
    try {
      Secret.password_clear_sync(schema, null,
                                 "client_id", Config.GOOGLE_CLIENT_ID);
    } catch (Error e) {
      // Ignore
    }
  }

  async void store_credentials()
  {
    var schema = get_secret_schema();
    try {
      Secret.password_store_sync(schema,
                                 Secret.COLLECTION_DEFAULT,
                                 _("Google credentials for Déjà Dup"),
                                 refresh_token,
                                 null,
                                 "client_id", Config.GOOGLE_CLIENT_ID);
    } catch (Error e) {
      warning("%s\n", e.message);
    }
  }

  string get_consent_location()
  {
    var message = Soup.Form.request_new(
      "GET",
      "https://accounts.google.com/o/oauth2/v2/auth",
      "client_id", Config.GOOGLE_CLIENT_ID,
      "redirect_uri", local_address,
      "response_type", "code",
      "code_challenge", pkce,
      "scope", "https://www.googleapis.com/auth/drive.file"
    );
    return message.uri.to_string(false);
  }

  async void get_credentials(string code) throws Error
  {
    var message = Soup.Form.request_new(
      "POST",
      "https://www.googleapis.com/oauth2/v4/token",
      "client_id", Config.GOOGLE_CLIENT_ID,
      "redirect_uri", local_address,
      "grant_type", "authorization_code",
      "code_verifier", pkce,
      "code", code
    );
    yield get_tokens(message);
  }

  async void refresh_credentials() throws Error
  {
    var message = Soup.Form.request_new(
      "POST",
      "https://www.googleapis.com/oauth2/v4/token",
      "client_id", Config.GOOGLE_CLIENT_ID,
      "refresh_token", refresh_token,
      "grant_type", "refresh_token"
    );
    yield get_tokens(message);
  }

  void oauth_server_request_received(Soup.Server server, Soup.Message message,
                                     string path,
                                     HashTable<string, string>? query,
                                     Soup.ClientContext client)
  {
    if (path != "/") {
      message.status_code = Soup.Status.NOT_FOUND;
      return;
    }

    message.status_code = Soup.Status.ACCEPTED;
    server = null;

    string? error = query == null ? null : query.lookup("error");
    if (error != null) {
      stop_login(error);
      return;
    }

    string? code = query == null ? null : query.lookup("code");
    if (code == null) {
      stop_login(null);
      return;
    }

    // Show consent granted screen
    var html = DejaDup.get_access_granted_html();
    message.response_body.append_take(html.data);

    show_oauth_consent_page(null, null); // continue on from paused screen
    get_credentials.begin(code);
  }

  void start_authorization() throws Error
  {
    // Start a server and listen on it
    server = new Soup.Server("server-header",
                             "%s/%s ".printf(Config.PACKAGE, Config.VERSION));
    server.listen_local(0, Soup.ServerListenOptions.IPV4_ONLY);
    local_address = server.get_uris().data.to_string(false);

    // Prepare to handle requests that finish the consent process
    server.add_handler(null, oauth_server_request_received);

    // We need a random string between 43 and 128 chars. UUIDs are an easy way
    // to get random strings, but they are only 37 chars long. So just add two.
    pkce = Uuid.string_random() + Uuid.string_random();

    // And show the oauth consent page finally
    var location = get_consent_location();
    if (location != null)
      show_oauth_consent_page(
        _("You first need to allow Backups to access your Google account."),
        location
      );
  }

  public override async void get_envp() throws Error
  {
    refresh_token = yield lookup_refresh_token();
    if (refresh_token == null)
      start_authorization();
    else {
      // We refresh the tokens ourselves (rather than duplicity) for two reasons:
      // 1) We can snapshot the current access/refresh tokens into libsecret
      // 2) We'll have a valid access token for our own get_space calls
      // Duplicity might refresh the token on its own if it goes longer than
      // an hour. And we won't have an up to date token, but that's OK. Ours
      // should still work.
      yield refresh_credentials();
    }
  }

  void got_credentials() {
    // Pydrive only accepts credentials from a file. So we create a temporary
    // directory and put our settings file and credentials both in there.
    // Make sure it's all readable only by the user, and we should delete them
    // when we're done.

    // Clear any existing credentials dir from a previous op
    clean_credentials_dir();

    try {
      credentials_dir = DirUtils.make_tmp("deja-dup-XXXXXX");
      var prefix = "/org/gnome/DejaDup%s/".printf(Config.PROFILE);

      // Add settings.yaml
      var yaml_path = prefix + "pydrive-settings.yaml";
      var yaml_bytes = resources_lookup_data(yaml_path, ResourceLookupFlags.NONE);
      var yaml = (string)yaml_bytes.get_data();
      yaml = yaml.replace("$CLIENT_ID", Config.GOOGLE_CLIENT_ID);
      yaml = yaml.replace("$PATH", credentials_dir);
      FileUtils.set_contents("%s/settings.yaml".printf(credentials_dir), yaml);

      // Add credentials.json
      var json_path = prefix + "pydrive-credentials.json";
      var json_bytes = resources_lookup_data(json_path, ResourceLookupFlags.NONE);
      var json = (string)json_bytes.get_data();
      json = json.replace("$CLIENT_ID", Config.GOOGLE_CLIENT_ID);
      json = json.replace("$ACCESS_TOKEN", access_token);
      json = json.replace("$REFRESH_TOKEN", refresh_token);
      FileUtils.set_contents("%s/credentials.json".printf(credentials_dir), json);
    }
    catch (Error e) {
      stop_login(e.message);
      return;
    }

    List<string> envp = new List<string>();
    envp.append("GOOGLE_DRIVE_SETTINGS=%s/settings.yaml".printf(credentials_dir));
    envp_ready(true, envp);
  }
}

} // end namespace
