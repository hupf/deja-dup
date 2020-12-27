/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

/**
 * This abstract backend is for cloud services that use OAuth authentication.
 */

using GLib;

public abstract class DejaDup.BackendOAuth : Backend
{
  public async string? lookup_refresh_token()
  {
    var schema = get_secret_schema();
    try {
      return Secret.password_lookup_sync(schema, null,
                                         "client_id", client_id);
    } catch (Error e) {
      // Ignore, just act like we didn't find it
      return null;
    }
  }

  public async void clear_refresh_token()
  {
    var schema = get_secret_schema();
    try {
      Secret.password_clear_sync(schema, null,
                                 "client_id", client_id);
    } catch (Error e) {
      // Ignore
    }
  }

  // subclasses should set these properties during construction
  protected string brand_name; // Like 'Google' or 'Microsoft', untranslated
  protected string client_id;
  protected string auth_url;
  protected string token_url;
  protected string scope;

  // subclasses can read but should not set these tokens
  protected string access_token;
  protected string refresh_token;

  Soup.Server server;
  Soup.Session session;
  string local_address;
  string pkce;

  construct {
    session = new Soup.Session();
    session.user_agent = "%s/%s ".printf(Config.PACKAGE, Config.VERSION);
  }

  public override bool is_native() {
    return false;
  }

  // This will be called during envp gathering, once access_token has been set.
  // Should either call stop_login or envp_ready.
  protected abstract void got_credentials() throws Error;

  protected void stop_login(string? reason)
  {
    // Translators: %s is a brand name like Microsoft or Google
    var full_reason = _("Could not log into %s servers.").printf(brand_name);
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

  internal async Json.Reader send_message(Soup.Message message) throws Error
  {
    message.request_headers.replace("Authorization", "Bearer " + access_token);
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

  Secret.Schema get_secret_schema()
  {
    return new Secret.Schema(
      Config.APPLICATION_ID + "." + brand_name, Secret.SchemaFlags.NONE,
      "client_id", Secret.SchemaAttributeType.STRING
    );
  }

  async void store_credentials()
  {
    var schema = get_secret_schema();
    try {
      Secret.password_store_sync(schema,
                                 Secret.COLLECTION_DEFAULT,
                                 // Translators: %s is a brand name like Google or Microsoft
                                 _("%s credentials for Déjà Dup"),
                                 refresh_token,
                                 null,
                                 "client_id", client_id);
    } catch (Error e) {
      warning("%s\n", e.message);
    }
  }

  string get_consent_location()
  {
    var message = Soup.Form.request_new(
      "GET", auth_url,
      "client_id", client_id,
      "redirect_uri", local_address,
      "response_type", "code",
      "code_challenge", pkce,
      "scope", scope
    );
    return message.uri.to_string(false);
  }

  async void get_credentials(string code) throws Error
  {
    var message = Soup.Form.request_new(
      "POST", token_url,
      "client_id", client_id,
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
      "POST", token_url,
      "client_id", client_id,
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
        // Translators: %s is a brand name like Google or Microsoft
        _("You first need to allow Backups to access your %s account.").printf(brand_name),
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
}
