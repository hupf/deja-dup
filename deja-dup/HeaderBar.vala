/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class HeaderBar : BuilderWidget
{
  public HeaderBar(Gtk.Builder builder)
  {
    Object(builder: builder);
  }

  Settings settings;
  construct {
    adopt_name("header-stack");

    unowned var stack = get_object("stack") as Gtk.Stack;
    stack.notify["visible-child-name"].connect(update_header);

    settings = DejaDup.get_settings();
    settings.changed[DejaDup.LAST_RUN_KEY].connect(update_header);

    update_header();
  }

  void update_header()
  {
    unowned var stack = get_object("stack") as Gtk.Stack;
    unowned var previous = get_object("previous-button") as Gtk.Button;
    unowned var search = get_object("search-button") as Gtk.Button;
    unowned var selection = get_object("selection-button") as Gtk.Button;
    unowned var switcher = get_object("switcher") as Hdy.ViewSwitcher;

    var is_restore = stack.visible_child_name == "restore";
    var welcome_state = settings.get_string(DejaDup.LAST_RUN_KEY) == "";

    previous.visible = is_restore;
    search.visible = is_restore;
    selection.visible = is_restore;
    switcher.sensitive = is_restore || !welcome_state;
  }
}
