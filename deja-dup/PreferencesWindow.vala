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

    unowned var widget = window.get_object("preferences") as Gtk.Window;
    widget.set_transient_for(parent);
    widget.application = DejaDupApp.get_instance();
    widget.show();
  }

  public PreferencesWindow()
  {
    Object(builder: DejaDup.make_builder("preferences"));
  }

  construct
  {
    adopt_name("preferences");

    new ConfigAutoBackup(builder);
    new ConfigDelete(builder);
    new ConfigFolderList(builder, "includes", DejaDup.INCLUDE_LIST_KEY, true);
    new ConfigFolderList(builder, "excludes", DejaDup.EXCLUDE_LIST_KEY, false);
    new ConfigLocationRow(builder);
    new ConfigPeriod(builder);
  }
}
