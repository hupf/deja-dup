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

public class BackendGoogle : BackendOAuth
{
  public BackendGoogle(Settings? settings) {
    Object(kind: Kind.GOOGLE,
           settings: (settings != null ? settings : get_settings(GOOGLE_ROOT)));
  }

  string credentials_dir;
  construct {
    // OAuth class properties
    brand_name = "Google";
    client_id = Config.GOOGLE_CLIENT_ID;
    auth_url = "https://accounts.google.com/o/oauth2/v2/auth";
    token_url = "https://www.googleapis.com/oauth2/v4/token";
    scope = "https://www.googleapis.com/auth/drive.file";
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

  public override string[] get_dependencies() {
    return Config.PYDRIVE_PACKAGES.split(",");
  }

  public override Icon? get_icon() {
    return new ThemedIcon("deja-dup-google-drive");
  }

  public override async bool is_ready(out string when) {
    when = _("Backup will begin when a network connection becomes available.");
    return yield Network.get().can_reach("https://%s/".printf(GOOGLE_SERVER));
  }

  internal string get_folder() {
    return get_folder_key(settings, GOOGLE_FOLDER_KEY);
  }

  public override string get_location_pretty()
  {
    var folder = get_folder();
    if (folder == "")
      return _("Google Drive");
    else
      // Translators: %s is a folder.
      return _("%s on Google Drive").printf(folder);
  }

  public override async uint64 get_space(bool free = true)
  {
    var message = Soup.Form.request_new(
      "GET", "https://www.googleapis.com/drive/v3/about",
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

  protected override void got_credentials() throws Error
  {
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
