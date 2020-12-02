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
    resizable = false;

    var builder = DejaDup.make_builder("preferences");
    location_grid = new ConfigLocationGrid(builder, true);

    unowned var location_label = builder.get_object("location_label") as Gtk.Label;
    location_label.label = _("_Backup location");

    var config_location = builder.get_object("location_grid") as Gtk.Widget;
    config_location.unparent();

    append_page(config_location, Type.NORMAL, _("_Search"));

    response.connect(handle_response);
  }

  void handle_response(int resp)
  {
    var backend = location_grid.get_backend();

    destroy();

    if (resp == FORWARD) {
      DejaDupApp.get_instance().search_custom_restore(backend);
    }
  }
}
