/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class RestoreHeaderBar : HeaderBar
{
  public bool search_sensitive {get; set;}
  public bool search_active {get; set;}

  construct {
    var previous_button = new Gtk.Button();
    previous_button.action_name = "restore.go-up";
    previous_button.icon_name = "go-previous-symbolic";
    previous_button.receives_default = true;
    previous_button.tooltip_text = _("Back");
    previous_button.name = _("Back");
    header.pack_start(previous_button);

    var search_button = new Gtk.ToggleButton();
    search_button.icon_name = "edit-find-symbolic";
    search_button.receives_default = true;
    search_button.tooltip_text = _("Search");
    search_button.name = _("Search");
    bind_property("search-active", search_button, "active", BindingFlags.BIDIRECTIONAL);
    bind_property("search-sensitive", search_button, "sensitive", BindingFlags.SYNC_CREATE);
    header.pack_end(search_button);
  }
}
