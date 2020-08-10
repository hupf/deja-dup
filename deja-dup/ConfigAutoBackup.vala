/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class ConfigAutoBackup : BuilderWidget
{
  public ConfigAutoBackup(Gtk.Builder builder) {
    Object(builder: builder);
  }

  construct {
    var auto_backup = builder.get_object("auto_backup") as Gtk.Switch;
    adopt_widget(auto_backup);

    var settings = DejaDup.get_settings();
    settings.bind(DejaDup.PERIODIC_KEY, auto_backup, "active", SettingsBindFlags.GET);

    auto_backup.state_set.connect((state) => {
      if (state) {
        var bg = new Background();
        if (!bg.request_autostart(auto_backup)) {
          auto_backup.active = false;
          return true; // don't change state, skip default handler
        }
      }

      settings.set_boolean(DejaDup.PERIODIC_KEY, state);
      return false;
    });
  }
}
