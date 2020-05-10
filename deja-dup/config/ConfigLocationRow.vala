/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class ConfigLocationRow : BuilderWidget
{
  public ConfigLocationRow(Gtk.Builder builder) {
    Object(builder: builder);
  }

  List<Settings> all_settings;
  construct {
    adopt_name("location");

    var settings = DejaDup.get_settings();
    settings.changed["backend"].connect(update_text);
    all_settings.prepend(settings);

    string[] roots = {DejaDup.DRIVE_ROOT, DejaDup.GOOGLE_ROOT,
                      DejaDup.LOCAL_ROOT, DejaDup.REMOTE_ROOT};
    foreach (var root in roots) {
      settings = DejaDup.get_settings(root);
      settings.change_event.connect(update_text_handler);
      all_settings.prepend(settings);
    }

    update_text();

    // TODO: libhandy 1.0 makes this easier with a direct ActionRow "activated" signal
    var group = builder.get_object("storage_group") as Hdy.PreferencesGroup;
    var location = builder.get_object("location") as Hdy.ActionRow;
    var listbox = location.get_ancestor(typeof(Gtk.ListBox)) as Gtk.ListBox;
    if (listbox != null) {
      listbox.row_activated.connect((row) => {
        if (row == location) {
          show_location_options();
        }
      });
    }

    new ConfigLocationGrid(builder);
  }

  void update_text() {
    var backend = DejaDup.Backend.get_default();
    var description = builder.get_object("location_description") as Gtk.Label;
    description.label = backend.get_location_pretty();
  }

  bool update_text_handler() {
    update_text();
    return false;
  }

  void show_location_options() {
    var dialog = builder.get_object("location_dialog") as Gtk.Dialog;
    dialog.show();
  }
}
