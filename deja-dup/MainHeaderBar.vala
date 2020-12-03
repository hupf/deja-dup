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
    search_bar.bind_property("search-mode-enabled", selection_search_button,
                             "active", BindingFlags.BIDIRECTIONAL);
  }

  public bool in_selection_mode()
  {
    return header_stack.visible_child_name == "selection";
  }

  public void set_selection_count(uint count)
  {
    if (count == 0) {
      selection_menu_button.label = _("Click on items to select them");
    } else {
      selection_menu_button.label = ngettext("%u selected", "%u selected",
                                             count).printf(count);
    }
  }

  public void open_menu()
  {
    primary_menu_button.popup();
  }

  [GtkChild]
  Gtk.Stack header_stack;

  [GtkChild]
  Gtk.Button previous_button;
  [GtkChild]
  Gtk.ToggleButton search_button;
  [GtkChild]
  Gtk.ToggleButton selection_search_button;
  [GtkChild]
  Gtk.Button selection_button;

  [GtkChild]
  Gtk.MenuButton primary_menu_button;
  [GtkChild]
  Gtk.MenuButton selection_menu_button;

  [GtkChild]
  Hdy.ViewSwitcher switcher;

  Settings settings;
  construct {
    notify["stack"].connect(reset_stack);

    settings = DejaDup.get_settings();
    settings.changed[DejaDup.LAST_RUN_KEY].connect(update_header);

    update_header();

    bind_property("actions-sensitive", search_button, "sensitive", BindingFlags.SYNC_CREATE);
    bind_property("actions-sensitive", selection_search_button, "sensitive", BindingFlags.SYNC_CREATE);
    bind_property("actions-sensitive", selection_button, "sensitive", BindingFlags.SYNC_CREATE);

    // Cancel selection mode if user presses Escape
    var key_event = new Gtk.EventControllerKey();
    key_event.key_pressed.connect((val, code, state) => {
      var modifiers = Gtk.accelerator_get_default_mod_mask();
      if (val == Gdk.Key.Escape && (state & modifiers) == 0 && in_selection_mode())
      {
        on_selection_cancel_clicked();
        return true;
      }
      return false;
    });
    header_stack.add_controller(key_event);
  }

  void reset_stack()
  {
    if (stack != null) {
      stack.notify["visible-child-name"].connect(update_header);
      switcher.stack = stack;
    }
  }

  [GtkCallback]
  void on_selection_clicked()
  {
    header_stack.visible_child_name = "selection";
  }

  [GtkCallback]
  void on_selection_cancel_clicked()
  {
    header_stack.visible_child_name = "main";
  }

  void update_header()
  {
    var is_restore = stack != null && stack.visible_child_name == "restore";
    var welcome_state = settings.get_string(DejaDup.LAST_RUN_KEY) == "";

    previous_button.visible = is_restore;
    search_button.visible = is_restore;
    selection_button.visible = is_restore;
    switcher.sensitive = is_restore || !welcome_state;
  }
}
