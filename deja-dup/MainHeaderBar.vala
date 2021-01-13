/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/MainHeaderBar.ui")]
public class MainHeaderBar : Gtk.Box
{
  public Gtk.Stack stack {get; set;}
  public bool actions_sensitive {get; set;}

  public void bind_search_bar(Gtk.SearchBar search_bar)
  {
    search_bar.bind_property("search-mode-enabled", search_button,
                             "active", BindingFlags.BIDIRECTIONAL);
  }

  public void open_menu()
  {
    primary_menu_button.popup();
  }

  [GtkChild]
  Gtk.Button previous_button;
  [GtkChild]
  Gtk.ToggleButton search_button;

  [GtkChild]
  Gtk.MenuButton primary_menu_button;

  [GtkChild]
  Adw.ViewSwitcher switcher;

  Settings settings;
  construct {
    notify["stack"].connect(reset_stack);

    settings = DejaDup.get_settings();
    settings.changed[DejaDup.LAST_RUN_KEY].connect(update_header);

    update_header();

    bind_property("actions-sensitive", search_button, "sensitive", BindingFlags.SYNC_CREATE);
  }

  void reset_stack()
  {
    if (stack != null) {
      stack.notify["visible-child-name"].connect(update_header);
      switcher.stack = stack;
    }
  }

  void update_header()
  {
    var is_restore = stack != null && stack.visible_child_name == "restore";
    var welcome_state = settings.get_string(DejaDup.LAST_RUN_KEY) == "";

    previous_button.visible = is_restore;
    search_button.visible = is_restore;
    switcher.sensitive = is_restore || !welcome_state;
  }
}
