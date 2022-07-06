/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

// A simple one-page assistant to ask where to restore from
public class AssistantLocation : Assistant
{
  ConfigLocationGroup location_group;
  construct
  {
    default_title = _("Restore From Where?");
    modal = true;
    destroy_with_parent = true;

    var clamp = new Adw.Clamp();
    DejaDup.set_margins(clamp, 12);

    location_group = new ConfigLocationGroup(true);
    clamp.child = location_group;

    append_page(clamp, Type.NORMAL, _("_Search"));

    response.connect(handle_response);
  }

  void handle_response(int resp)
  {
    var backend = location_group.get_backend();

    destroy();

    if (resp == FORWARD) {
      DejaDupApp.get_instance().search_custom_restore(backend);
    }
  }
}
