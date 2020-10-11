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

  DejaDup.BackendWatcher watcher;
  construct {
    adopt_name("location");

    watcher = new DejaDup.BackendWatcher();
    watcher.changed.connect(update_text);

    update_text();

    var location = builder.get_object("location") as Hdy.ActionRow;
    location.activated.connect(show_location_options);

    new ConfigLocationGrid(builder);
  }

  void update_text() {
    var backend = DejaDup.Backend.get_default();
    var description = builder.get_object("location_description") as Gtk.Label;
    description.label = backend.get_location_pretty();
  }

  void show_location_options() {
    var dialog = builder.get_object("location_dialog") as Gtk.Dialog;
    dialog.show();
  }
}
