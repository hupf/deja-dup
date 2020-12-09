/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/PreferencesWindow.ui")]
public class PreferencesWindow : Hdy.PreferencesWindow
{
  [GtkChild]
  Gtk.Label location_description;

  [GtkChild]
  Gtk.Switch auto_backup;

  DejaDup.BackendWatcher watcher;
  construct
  {
    watcher = new DejaDup.BackendWatcher();
    watcher.changed.connect(update_location_description);
    update_location_description();

    ConfigAutoBackup.bind(auto_backup);
  }

  ~PreferencesWindow()
  {
    debug("Finalizing PreferencesWindow\n");
  }

  void update_location_description()
  {
    var backend = DejaDup.Backend.get_default();
    location_description.label = backend.get_location_pretty();
  }
}
