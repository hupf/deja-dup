/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/RestoreToolbarView.ui")]
public class RestoreToolbarView : Adw.Bin
{
  const ActionEntry[] ACTIONS = {
    {"select-all", select_all},
    {"go-up", go_up},
    {"search", activate_search},
  };

  [GtkChild]
  unowned HeaderBar header;
  [GtkChild]
  unowned Gtk.SearchBar search_bar;
  [GtkChild]
  unowned Gtk.SearchEntry search_entry;
  [GtkChild]
  unowned Browser browser;
  [GtkChild]
  unowned Gtk.Button restore_button;
  [GtkChild]
  unowned TimeCombo timecombo;
  [GtkChild]
  unowned Adw.ViewSwitcherBar switcher_bar;

  unowned MainWindow app_window;
  SimpleActionGroup action_group;

  construct
  {
    var application = DejaDupApp.get_instance();

    // Set up actions
    action_group = new SimpleActionGroup();
    action_group.add_action_entries(ACTIONS, this);
    application.set_accels_for_action("restore.select-all", {"<Control>A"});
    application.set_accels_for_action("restore.go-up", {"<Alt>Left", "<Alt>Up"});
    application.set_accels_for_action("restore.search", {"<Control>F"});

    var go_up_action = action_group.lookup_action("go-up");
    browser.bind_property("can-go-up", go_up_action, "enabled", BindingFlags.SYNC_CREATE);

    var select_all_action = action_group.lookup_action("select-all");
    browser.bind_property("files-filled", select_all_action, "enabled", BindingFlags.SYNC_CREATE);

    search_bar.bind_property("search-mode-enabled", header,
                             "search-active", BindingFlags.BIDIRECTIONAL);
    browser.bind_property("files-filled", header, "search-sensitive",
                          BindingFlags.SYNC_CREATE);
    browser.notify["has-selection"].connect(selection_changed);

    search_entry.search_changed.connect(update_search_filter);
    browser.folder_changed.connect(folder_changed);
  }

  public void bind_to_window(MainWindow win)
  {
    var main_stack = win.get_view_stack();
    app_window = win;
    header.stack = main_stack;
    switcher_bar.stack = main_stack;

    app_window.notify["thin-mode"].connect(update_header_bar);
    update_header_bar();

    // Drop action group when not in focus
    main_stack.notify["visible-child"].connect(() => {
      var is_visible_page = main_stack.visible_child == this;
      browser.is_visible_page = is_visible_page;
      if (is_visible_page) {
        app_window.insert_action_group("restore", action_group);
      } else {
        app_window.insert_action_group("restore", null);
      }
    });

    browser.bind_to_window(win, timecombo);
  }

  void go_up() {
    browser.go_up();
  }

  void select_all() {
    browser.select_all();
  }

  void activate_search() {
    search_bar.search_mode_enabled = true;
    search_entry.grab_focus();
  }

  void update_search_filter()
  {
    browser.search_filter = search_entry.text;
  }

  void folder_changed() {
    search_bar.search_mode_enabled = false;
  }

  void selection_changed() {
    print("MIKE: receiving selection as %d\n", (int)browser.has_selection);
    restore_button.sensitive = browser.has_selection;
  }

  [GtkCallback]
  void start_restore()
  {
    browser.start_restore();
  }

  void update_header_bar()
  {
    header.title_visible = !app_window.thin_mode;
    switcher_bar.reveal = app_window.thin_mode;
  }
}
