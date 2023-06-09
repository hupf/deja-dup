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
  public string full_token {get; private set;}
  public string access_token {get; private set;}
  public string refresh_token {get; private set;}

  public abstract string get_redirect_uri();

  // Meant to be called externally when the oauth service redirects back to us.
  // This passed-in uri will hold the code and error values from the service.
  public bool continue_authorization(string command_line_redirect_uri)
  {
    if (authorization_instance.get() == null)
      return false; // no auth in progress

    var active_backend = (BackendOAuth)authorization_instance.get();
    active_backend.continue_authorization_helper(command_line_redirect_uri);
    return true;
  }

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
      // any observers need to reset as if we have a new backend (because the
      // user may well authenticate with a whole different account next time)
      BackendWatcher.get_instance().changed();
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

  // GLOBALLY shared callback property - possibly better as an instance property
  // and then we'd just need to properly surface "the currently active backend"
  // to the application instance, so it can find the right instance.
  static WeakRef authorization_instance;
  SourceFunc authorization_callback;

  Soup.Session session;
  string pkce;
  string error_msg;
  string code;

  construct {
    session = new Soup.Session();
    session.user_agent = "%s/%s ".printf(Config.PACKAGE, Config.VERSION);
  }

  public override bool is_native() {
    return false;
  }

  // This will be called during prepare(), once access_token has been set.
  // Call stop_login() if you like for a nicer error message.
  protected virtual async void got_credentials() throws Error {}

  protected void stop_login(string? reason) throws Error
  {
    // Translators: %s is a brand name like Microsoft or Google
    var full_reason = _("Could not log into %s servers.").printf(brand_name);
    if (reason != null && reason != "")
      full_reason = "%s %s".printf(full_reason, reason);

    throw new IOError.FAILED(full_reason);
  }

  async Json.Reader? send_message_raw(Soup.Message message) throws Error
  {
    var response = yield session.send_async(message, Priority.DEFAULT, null);
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
      yield start_authorization();
      return;
    }

    // Save the full token
    full_token = Json.to_string(reader.root, false);

    // Parse token
    reader.read_member("access_token");
    access_token = reader.get_string_value();
    reader.end_member();
    if (reader.read_member("refresh_token")) {
      refresh_token = reader.get_string_value();
      yield store_credentials();
    }
    reader.end_member();

    yield got_credentials();
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
                                 _("%s credentials for Déjà Dup").printf(brand_name),
                                 refresh_token,
                                 null,
                                 "client_id", client_id);
    } catch (Error e) {
      warning("%s\n", e.message);
    }
  }

  string get_consent_location()
  {
    var form = Soup.Form.encode(
      "client_id", client_id,
      "redirect_uri", get_redirect_uri(),
      "response_type", "code",
      "code_challenge", pkce,
      "scope", scope
    );
    var message = new Soup.Message.from_encoded_form("GET", auth_url, form);
    return message.uri.to_string();
  }

  async void get_credentials(string code) throws Error
  {
    var form = Soup.Form.encode(
      "client_id", client_id,
      "redirect_uri", get_redirect_uri(),
      "grant_type", "authorization_code",
      "code_verifier", pkce,
      "code", code
    );
    var message = new Soup.Message.from_encoded_form("POST", token_url, form);
    yield get_tokens(message);
  }

  async void refresh_credentials() throws Error
  {
    var form = Soup.Form.encode(
      "client_id", client_id,
      "refresh_token", refresh_token,
      "grant_type", "refresh_token"
    );
    var message = new Soup.Message.from_encoded_form("POST", token_url, form);
    yield get_tokens(message);
  }

  async void start_authorization() throws Error
  {
    // Prepare to handle requests that finish the consent process
    error_msg = null;
    code = null;

    // We need a random string between 43 and 128 chars. UUIDs are an easy way
    // to get random strings, but they are only 37 chars long. So just add two.
    pkce = Uuid.string_random() + Uuid.string_random();

    // And show the oauth consent page finally
    show_oauth_consent_page(
      // Translators: %s is a brand name like Google or Microsoft
      _("You first need to allow Backups to access your %s account.").printf(brand_name),
      get_consent_location()
    );

    authorization_instance.set(this);
    authorization_callback = start_authorization.callback;
    yield;
    authorization_instance.set(null);
    authorization_callback = null;

    if (error_msg != null) {
      stop_login(error_msg);
      return;
    }

    show_oauth_consent_page(null, null); // continue on from paused screen
    yield get_credentials(code);
  }

  void continue_authorization_helper(string command_line_redirect_uri)
  {
    HashTable<string,string> query = null;

    try {
      var uri = Uri.parse(command_line_redirect_uri, UriFlags.NONE);
      query = Uri.parse_params(uri.get_query());
    } catch (UriError e) {
      error_msg = e.message;
    }

    if (error_msg == null && query != null)
      error_msg = query.lookup("error");

    if (error_msg == null && query != null)
      code = query.lookup("code");

    if (error_msg == null && code == null)
      error_msg = ""; // default to just a blank contextual error message

    authorization_callback();
  }

  public override async void prepare() throws Error
  {
    refresh_token = yield lookup_refresh_token();
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
}
