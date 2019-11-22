/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class PreferencesWindow : BuilderWidget
{
  public static void show(Gtk.Window parent)
  {
    var window = new PreferencesWindow();

    var widget = window.builder.get_object("preferences") as Gtk.Window;
    widget.set_transient_for(parent);

    // Emulate Gtk.Dialog's default closing on an Escape press
    widget.key_press_event.connect((w, e) => {
      uint modifiers = Gtk.accelerator_get_default_mod_mask();

      if (e.keyval == Gdk.Key.Escape && (e.state & modifiers) == 0) {
        w.destroy();
        return true;
      }
      else
        return false;
    });

    DejaDupApp.get_instance().add_window(widget);
    widget.show();
  }

  public PreferencesWindow()
  {
    Object(builder: new Builder("preferences"));
  }

  construct
  {
    adopt_name("preferences");

    new ConfigAutoBackup(builder);
    new ConfigDelete(builder);
    new ConfigFolderList(builder, "includes", DejaDup.INCLUDE_LIST_KEY);
    new ConfigFolderList(builder, "excludes", DejaDup.EXCLUDE_LIST_KEY);
    new ConfigLocationRow(builder);
    new ConfigPeriod(builder);
  }
}
