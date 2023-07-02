/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/MainHeaderBar.ui")]
public class MainHeaderBar : Adw.Bin
{
  public Adw.ViewStack stack {get; set;}
  public bool actions_sensitive {get; set;}
  public bool title_visible {get; set; default = true;}

  public void bind_search_bar(Gtk.SearchBar search_bar)
  {
    search_bar.bind_property("search-mode-enabled", search_button,
                             "active", BindingFlags.BIDIRECTIONAL);
  }

  [GtkChild]
  unowned Gtk.Button previous_button;
  [GtkChild]
  unowned Gtk.ToggleButton search_button;

  [GtkChild]
  unowned Adw.HeaderBar adw_bar;
  [GtkChild]
  unowned Adw.ViewSwitcher switcher;

  construct {
    notify["stack"].connect(reset_stack);

    bind_property("actions-sensitive", search_button, "sensitive", BindingFlags.SYNC_CREATE);

    switcher.ref();
    notify["title-visible"].connect(update_header_title);

    update_stack_buttons();
    update_header_title();
  }

  void reset_stack()
  {
    if (stack != null) {
      stack.notify["visible-child-name"].connect(update_stack_buttons);
      switcher.stack = stack;
    }
  }

  void update_stack_buttons()
  {
    var is_restore = stack != null && stack.visible_child_name == "restore";
    previous_button.visible = is_restore;
    search_button.visible = is_restore;
  }

  void update_header_title()
  {
    if (title_visible)
      adw_bar.title_widget = switcher;
    else
      adw_bar.title_widget = null; // switcher stays alive because of our ref()
  }
}
