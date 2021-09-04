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

  construct {
    // OAuth class properties
    brand_name = "Google";
    client_id = Config.GOOGLE_CLIENT_ID;
    auth_url = "https://accounts.google.com/o/oauth2/v2/auth";
    token_url = "https://www.googleapis.com/oauth2/v4/token";
    scope = "https://www.googleapis.com/auth/drive.file";
  }

  public override string[] get_dependencies() {
    return Config.PYDRIVE_PACKAGES.split(",");
  }

  public override Icon? get_icon() {
    return new ThemedIcon("deja-dup-google-drive");
  }

  public override async bool is_ready(out string reason, out string message) {
    reason = "google-reachable";
    message = _("Backup will begin when a network connection becomes available.");
    return yield Network.get().can_reach("https://%s/".printf(GOOGLE_SERVER));
  }

  public string get_folder() {
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
}

} // end namespace
