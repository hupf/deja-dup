/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

internal class Rclone : Object
{
  static string fill_envp_from_google(DejaDup.BackendGoogle google_backend, ref List<string> envp)
  {
    envp.append("RCLONE_CONFIG_DEJADUPDRIVE_TYPE=drive");
    envp.append("RCLONE_CONFIG_DEJADUPDRIVE_CLIENT_ID=" + Config.GOOGLE_CLIENT_ID);
    envp.append("RCLONE_CONFIG_DEJADUPDRIVE_TOKEN=" + google_backend.full_token);
    envp.append("RCLONE_CONFIG_DEJADUPDRIVE_SCOPE=drive.file");
    envp.append("RCLONE_CONFIG_DEJADUPDRIVE_USE_TRASH=false");
    return "dejadupdrive:" + google_backend.get_folder();
  }

  static string fill_envp_from_microsoft(DejaDup.BackendMicrosoft microsoft_backend, ref List<string> envp)
  {
    envp.append("RCLONE_CONFIG_DEJADUPONEDRIVE_TYPE=onedrive");
    envp.append("RCLONE_CONFIG_DEJADUPONEDRIVE_CLIENT_ID=" + Config.MICROSOFT_CLIENT_ID);
    envp.append("RCLONE_CONFIG_DEJADUPONEDRIVE_TOKEN=" + microsoft_backend.full_token);
    envp.append("RCLONE_CONFIG_DEJADUPONEDRIVE_DRIVE_ID=" + microsoft_backend.drive_id);
    envp.append("RCLONE_CONFIG_DEJADUPONEDRIVE_DRIVE_TYPE=personal");
    return "dejaduponedrive:" + microsoft_backend.get_folder();
  }

  public static string? fill_envp_from_backend(DejaDup.Backend backend, ref List<string> envp)
  {
    var google_backend = backend as DejaDup.BackendGoogle;
    if (google_backend != null)
      return fill_envp_from_google(google_backend, ref envp);

    var microsoft_backend = backend as DejaDup.BackendMicrosoft;
    if (microsoft_backend != null)
      return fill_envp_from_microsoft(microsoft_backend, ref envp);

    return null;
  }

  public static string rclone_command()
  {
    var testing_str = Environment.get_variable("DEJA_DUP_TESTING");
    if (testing_str != null && int.parse(testing_str) > 0)
      return "rclone";
    else
      return Config.RCLONE_COMMAND;
  }
}
