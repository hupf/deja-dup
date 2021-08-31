/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

// Just a thin convenience class to talk to the main backup process and ask it
// to start or stop backups.

using GLib;

[DBus (name = "org.gtk.Actions")]
interface ActionsInterface : Object {
  public abstract async void activate(
    string action, Variant[] paramters, HashTable<string, Variant> platform_data
  ) throws Error;
}

class BackupInterface : Object
{
  public static async void notify_not_ready(string message)
  {
    DejaDup.run_deja_dup({"--delay", message});
  }

  public static async void start_auto()
  {
    // Done by calling the executable rather than a dbus call because we want
    // to call it with nice / ionice, etc if possible. That stuff won't matter
    // if the main process is already up. But it might help. We need a more
    // robust way to control resource prioritization if the deja-dup process
    // is already running.

    if (DejaDup.in_testing_mode()) {
      // fake successful backup and schedule next run
      DejaDup.update_last_run_timestamp(DejaDup.LAST_BACKUP_KEY);
    }
    else {
      DejaDup.run_deja_dup({"--backup", "--auto"});
    }
  }

  public static async void stop_auto()
  {
    if (!DejaDup.in_testing_mode())
      yield activate_action("backup-auto-stop");
  }

  ///////////////

  private static async void activate_action(string command)
  {
    try {
      var connection = yield Bus.get(BusType.SESSION);
      ActionsInterface iface = yield connection.get_proxy(
        Config.APPLICATION_ID, DejaDup.get_application_path()
      );

      Variant[] parameters = {};
      var platform_data = new HashTable<string, Variant>(str_hash, str_equal);
      yield iface.activate(command, parameters, platform_data);
    }
    catch (Error error) {
      warning("%s", error.message);
    }
  }
}
