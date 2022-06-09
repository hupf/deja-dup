/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

// This class just simplifies the job of asking "has anything in the backend
// changed?" -- e.g. to display a label based off the backend, or to refresh
// the restore display if the backend changes.

public class DejaDup.BackendWatcher : Object
{
  public signal void changed();
  public signal void new_backup();

  static BackendWatcher instance;
  public static BackendWatcher get_instance()
  {
    if (instance == null)
      instance = new BackendWatcher();
    return instance;
  }

  private BackendWatcher()
  {
    Object();
  }

  List<Settings> all_settings; // hold refs to keep signals alive
  construct {
    var settings = DejaDup.get_settings();
    settings.changed[DejaDup.BACKEND_KEY].connect(handle_change);
    settings.changed[DejaDup.TOOL_KEY].connect(handle_change);
    settings.changed[DejaDup.LAST_BACKUP_KEY].connect(() => {new_backup();});
    all_settings.prepend(settings);

    string[] roots = {DejaDup.GOOGLE_ROOT, DejaDup.LOCAL_ROOT, DejaDup.REMOTE_ROOT};
    foreach (var root in roots) {
      settings = DejaDup.get_settings(root);
      settings.change_event.connect(handle_change_event);
      all_settings.prepend(settings);
    }

    // Handle drive specially, since we don't care about name/icon changes
    settings = DejaDup.get_settings(DejaDup.DRIVE_ROOT);
    settings.changed[DRIVE_UUID_KEY].connect(handle_change);
    settings.changed[DRIVE_FOLDER_KEY].connect(handle_change);
    all_settings.prepend(settings);
  }

  void handle_change() {
    changed();
  }

  bool handle_change_event() {
    changed();
    return false;
  }
}
