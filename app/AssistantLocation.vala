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

    location_grid = new ConfigLocationGrid(true);
    location_grid.set_location_label(_("_Backup location"));
    append_page(location_grid, Type.NORMAL, _("_Search"));

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
