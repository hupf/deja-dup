/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

// A simple one-page assistant to ask where to restore from
public class AssistantLocation : Assistant
{
  ConfigLocationGrid location_grid;
  construct
  {
    default_title = _("Restore From Where?");
    modal = true;
    destroy_with_parent = true;
    type_hint = Gdk.WindowTypeHint.DIALOG;
    resizable = false;
    default_height = 300; // tall enough for network server URL popup height

    var builder = new Builder("preferences");
    location_grid = new ConfigLocationGrid(builder, true);

    var location_label = builder.get_object("location_label") as Gtk.Label;
    location_label.label = _("_Backup location");

    var config_location = builder.get_object("location_grid") as Gtk.Widget;
    config_location.ref();
    config_location.parent.remove(config_location);
    config_location.show_all();

    append_page(config_location, Type.NORMAL, _("_Search"));

    response.connect(handle_response);
  }

  void handle_response(int resp)
  {
    if (resp == FORWARD) {
      DejaDupApp.get_instance().search_custom_restore(location_grid.get_backend());
    }
    DejaDup.destroy_widget(this);
  }
}
