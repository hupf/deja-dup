/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*- */
/*
    This file is part of Déjà Dup.
    For copyright information, see AUTHORS.

    Déjà Dup is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Déjà Dup is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Déjà Dup.  If not, see <http://www.gnu.org/licenses/>.
*/

/**
 * This backend is for the consumer-focused storage offering by Google.
 * At the time of this writing, it is called Google Drive.
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
    // Duplicity up to 0.7.18.2 has a bug in its pydrive backend where it makes
    // a file called i_am_in_root in the root dir of your Google Drive. They do
    // this to find the root id. I think because the author of the backend
    // didn't know you can use 'root' as an identifier alias for root. Anyway,
    // to keep the user's Drive clean, we'll delete it for the user. This
    // should eventually be removed, once we depend on a version of duplicity
    // higher than 0.7.18.2.
    yield delete_root_finder();

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

  async List<File> find_target_folders(File cwd, string[] needles)
  {
    // Are we done? Then just return the current folder.
    if (needles.length == 0 || needles[0] == "") {
      var found = new List<File>();
      found.append(cwd);
      return found;
    }

    // Not done yet, dig through the files here.
    var answers = new List<File>();
    var needle = needles[0];
    try {
      var enumerator = yield cwd.enumerate_children_async(
        "%s,%s".printf(FileAttribute.STANDARD_DISPLAY_NAME, FileAttribute.STANDARD_NAME),
        FileQueryInfoFlags.NONE);
      var children = yield enumerator.next_files_async(50);
      while (children.length() > 0) {
        foreach (var child in children) {
          if (child.get_display_name() == needle) {
            var found = enumerator.get_child(child);
            answers.concat(yield find_target_folders(found, needles[1:needles.length]));
          }
        }
        children = yield enumerator.next_files_async(50);
      }
    }
    catch (Error e) {
      // ignore, fall through to return answers we do have
    }

    return answers;
  }

  async void delete_root_finder()
  {
    var message = Soup.Form.request_new(
      "GET",
      "https://www.googleapis.com/drive/v3/files",
      "access_token", access_token,
      "q", "name = 'i_am_in_root' and 'root' in parents",
      "fields", "files(id)"
    );
    Json.Reader reader;

    try {
      reader = yield send_message(message);
    }
    catch (Error e) {
      return;
    }

    reader.read_member("files");
    for (int i = 0; i < reader.count_elements(); ++i) {
      reader.read_element(i);
      reader.read_member("id");
      yield delete_id(reader.get_string_value(), access_token);
      return;
    }
  }

  async void delete_id(string id, string token)
  {
    var message = new Soup.Message(
      "DELETE",
      "https://www.googleapis.com/drive/v3/files/%s?access_token=%s".printf(id, token)
    );
    try {
      yield send_message(message);
    }
    catch (Error e) {} // ignore
  }

#if HAS_GOA
  async GenericSet<string?> find_duplicity_ids(string token, List<File> parents) throws Error
  {
    string[] parent_ids = {};
    foreach (File f in parents) {
      parent_ids += "'%s' in parents".printf(f.get_basename());
    }
    var parent_q = string.joinv(" or ", parent_ids);

    var message = Soup.Form.request_new(
      "GET",
      "https://www.googleapis.com/drive/v3/files",
      "access_token", token,
      "q", "name contains 'duplicity-' and (%s)".printf(parent_q),
      "fields", "files(id)"
    );
    var reader = yield send_message(message);

    var ids = new GenericSet<string>(str_hash, str_equal);

    // Parse ids
    reader.read_member("files");
    for (int i = 0; i < reader.count_elements(); ++i) {
      reader.read_element(i);
      reader.read_member("id");
      ids.add(reader.get_string_value());
      reader.end_member();
      reader.end_element();
    }

    return ids;
  }

  async GenericSet<string?> find_old_ids(List<File> parents, string goa_token)
  {
    try {
      var all_ids = yield find_duplicity_ids(goa_token, parents);
      var new_ids = yield find_duplicity_ids(access_token, parents);

      foreach (var id in new_ids)
        all_ids.remove(id);

      return all_ids;
    }
    catch (Error e) {
      warning("%s\n", e.message);
      return new GenericSet<string>(str_hash, str_equal);
    }
  }

  async void delete_old_ids(BackendGOA goa_backend, List<File> parents)
  {
    var goa_token = yield goa_backend.get_access_token();
    if (goa_token == null)
      return;

    var old_ids = yield find_old_ids(parents, goa_token);

    foreach (var id in old_ids) {
      yield delete_id(id, goa_token);
    }
  }

  async void delete_if_empty_folder(File folder)
  {
    // Delete if empty and do same to parent
    var parent = folder.get_parent();
    try {
      var enumerator = yield folder.enumerate_children_async(
        FileAttribute.STANDARD_NAME, FileQueryInfoFlags.NONE);
      var children = yield enumerator.next_files_async(1);
      if (children.length() == 0) {
        yield folder.delete_async();
        yield delete_if_empty_folder(parent);
      }
    }
    catch (Error e) {
      // ignore
    }
  }

  async void cleanup_old_files(BackendGOA goa_backend)
  {
    var root = goa_backend.get_root_from_settings();
    if (root == null)
      return;

    var folder = goa_backend.get_folder();
    var folder_parts = folder.split("/");
    var parents = yield find_target_folders(root, folder_parts);

    yield delete_old_ids(goa_backend, parents);
    foreach (File f in parents)
      yield delete_if_empty_folder(f);
  }

  public override async Backend? report_full_backups(bool first_backup)
  {
    // As part of the migration from GNOME's keys to our own, we are moving
    // from full access to the user's files to only having access to the files
    // that we ourselves write. But we don't want to leave old backups just
    // sitting there! So as we write new full backups under our own key, we
    // delete old full backups under GNOME's key. The odd part is that Google
    // allows multiple directories with the same name - so we'll have to search
    // all of the ones that match our folder name. We can eventually drop this
    // code after a suitable amount of time.

    BackendGOA goa_backend = new BackendGOA(null);

    // Check GOA backend, skip if it's not holding the user's old google config
    if (goa_backend.settings.get_string(GOA_TYPE_KEY) != "google" ||
        goa_backend.settings.get_string(GOA_ID_KEY) == "" ||
        goa_backend.settings.get_boolean(GOA_MIGRATED_KEY)) {
      return null;
    }

    try {
      yield goa_backend.mount();
    }
    catch (Error e) {
      warning("%s\n", e.message);
      return null;
    }

    // If we don't have any backups yet, by returning the GOA backend, the job
    // will use it to clean all but one full backup. We can't do this after
    // we have backups, because it will have a hard time distinguishing the old
    // and new backups. In that case, we'll manually delete files below.
    if (first_backup)
      return goa_backend;

    // Actually delete the old files
    yield cleanup_old_files(goa_backend);

    // And stop us from doing this again by marking it as migrated
    goa_backend.settings.set_boolean(GOA_MIGRATED_KEY, true);

    return null;
  }
#endif

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
    reader.read_member("limit");
    var limit = uint64.parse(reader.get_string_value());
    reader.end_member();
    reader.read_member("usage");
    var usage = uint64.parse(reader.get_string_value());
    reader.end_member();

    return free ? limit - usage : limit;
  }

  Secret.Schema get_secret_schema()
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
      yield start_authorization();
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

  async void find_refresh_token()
  {
    var schema = get_secret_schema();
    try {
      refresh_token = yield Secret.password_lookup(schema,
                                                   null,
                                                   "client_id",
                                                   Config.GOOGLE_CLIENT_ID);
    } catch (Error e) {
      // Ignore, just act like we didn't find it
    }
  }

  async void store_credentials()
  {
    var schema = get_secret_schema();
    try {
      yield Secret.password_store(schema,
                                  Secret.COLLECTION_DEFAULT,
                                  _("Google credentials for Déjà Dup"),
                                  refresh_token,
                                  null,
                                  "client_id", Config.GOOGLE_CLIENT_ID);
    } catch (Error e) {
      warning("%s\n", e.message);
    }
  }

  async string? get_consent_location() throws Error
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
    message.set_flags(Soup.MessageFlags.NO_REDIRECT);
    yield session.send_async(message);

    var location = message.response_headers.get_one("location");
    if (location == null)
      stop_login(message.reason_phrase);

    return location;
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

  async void start_authorization() throws Error
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
    var location = yield get_consent_location();
    if (location != null)
      show_oauth_consent_page(
        _("You first need to allow Déjà Dup Backup Tool to access your Google account."),
        location
      );
  }

  public override async void get_envp() throws Error
  {
    yield find_refresh_token();
    if (refresh_token == null)
      yield start_authorization();
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
