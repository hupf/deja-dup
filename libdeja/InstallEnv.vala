/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class DejaDup.InstallEnv : Object
{
  static InstallEnv? _instance;
  public static InstallEnv instance()
  {
    if (_instance == null) {
      if (Environment.get_variable("FLATPAK_ID") != null)
        _instance = new InstallEnvFlatpak();
      else if (Environment.get_variable("SNAP_NAME") != null)
        _instance = new InstallEnvSnap();
      else
        _instance = new InstallEnv();
    }
    return _instance;
  }

  // The following methods are the default for a distro install. Containerized
  // installs can override any that interest them.

  public virtual string? get_name() { return null; }

  // handle is the string version of a window handle (in flatpak format)
  // mitigation is a user-presentable explanation of how to fix a failed request
  public virtual bool request_autostart(string handle, out string? mitigation) {
    mitigation = null;
    return true;
  }

  public virtual string[] get_system_tempdirs()
  {
    // Prefer directories that have their own cleanup logic in case ours isn't
    // run for a while.  (e.g. /tmp every boot, /var/tmp every now and then)
    return {Environment.get_tmp_dir(), "/var/tmp"};
  }

  public virtual void register_monitor_restart(MainLoop loop) {}

  // In some containers, parts of the host filesystem are not available to us
  // (e.g. in flatpak, /lib is hidden by flatpak platform files)
  public virtual bool is_file_available(File file) { return true; }

  public virtual string get_debug_info() { return ""; }
}
