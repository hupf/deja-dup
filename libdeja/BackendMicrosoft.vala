/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

/**
 * This backend is for the consumer-focused storage offering by Microsoft.
 * At the time of this writing, it is called Microsoft OneDrive.
 *
 * https://docs.microsoft.com/en-us/onedrive/developer/rest-api
 */

using GLib;

namespace DejaDup {

public const string MICROSOFT_ROOT = "Microsoft";
public const string MICROSOFT_FOLDER_KEY = "folder";

public const string MICROSOFT_SERVER = "microsoft.com";

public class BackendMicrosoft : BackendOAuth
{
  public string drive_id {get; private set;}

  public BackendMicrosoft(Settings? settings) {
    Object(kind: Kind.MICROSOFT,
           settings: (settings != null ? settings : get_settings(MICROSOFT_ROOT)));
  }

  Rclone rclone;
  construct {
    // OAuth class properties
    brand_name = "Microsoft";
    client_id = Config.MICROSOFT_CLIENT_ID;
    auth_url = "https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize";
    token_url = "https://login.microsoftonline.com/consumers/oauth2/v2.0/token";
    scope = "offline_access Files.ReadWrite";
  }

  public override string[] get_dependencies() {
    return Config.REQUESTS_OAUTHLIB_PACKAGES.split(",");
  }

  public override Icon? get_icon() {
    return new ThemedIcon("deja-dup-microsoft-onedrive");
  }

  public override async bool is_ready(out string reason, out string message) {
    reason = "microsoft-reachable";
    message = _("Backup will begin when a network connection becomes available.");
    return yield Network.get().can_reach("https://%s/".printf(MICROSOFT_SERVER));
  }

  internal string get_folder() {
    return get_folder_key(settings, MICROSOFT_FOLDER_KEY);
  }

  public override string get_location_pretty()
  {
    var folder = get_folder();
    if (folder == "")
      return _("Microsoft OneDrive");
    else
      // Translators: %s is a folder.
      return _("%s on Microsoft OneDrive").printf(folder);
  }

  public override async void cleanup()
  {
    rclone = null;
  }

  public override async uint64 get_space(bool free = true)
  {
    var message = new Soup.Message(
      "GET", "https://graph.microsoft.com/v1.0/me/drive?select=quota"
    );
    Json.Reader reader;

    try {
      reader = yield send_message(message);
    }
    catch (Error e) {
      return INFINITE_SPACE;
    }

    // Parse metadata
    reader.read_member("quota");
    reader.read_member("total");
    var total = reader.get_int_value();
    reader.end_member();
    reader.read_member("remaining");
    var remaining = reader.get_int_value();
    reader.end_member();

    return free ? remaining : total;
  }

  protected override async void got_credentials() throws Error
  {
    if (get_folder() == "") {
      // Duplicity requires a folder, and this is a reasonable restriction.
      throw new IOError.FAILED("%s", _("You must provide a Microsoft OneDrive folder."));
    }

    // Grab the drive ID in case a tool needs it
    var message = new Soup.Message(
      "GET", "https://graph.microsoft.com/v1.0/me/drive?select=id"
    );
    var reader = yield send_message(message);
    reader.read_member("id");
    drive_id = reader.get_string_value();
    reader.end_member();
  }
}

} // end namespace
