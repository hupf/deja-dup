/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/MainWindow.ui")]
public class MainWindow : Adw.ApplicationWindow
{
  public bool thin_mode {get; set; default = false;}

  public unowned Adw.ViewStack get_view_stack()
  {
    return stack;
  }

  public List<Gtk.Window> get_modals()
  {
    var modals = new List<Gtk.Window>();
    foreach (var window in Gtk.Window.list_toplevels()) {
      if (window.transient_for == this && window.modal && window.visible) {
        modals.prepend(window);
      }
    }
    return modals;
  }

  [GtkChild]
  unowned Adw.ViewStack stack;
  [GtkChild]
  unowned Adw.ViewStackPage backups_page;
  [GtkChild]
  unowned OverviewToolbarView overview_view;
  [GtkChild]
  unowned RestoreToolbarView restore_view;

  construct {
    var deja_app = DejaDupApp.get_instance();

    // Set a few icons that are hardcoded in ui files
    backups_page.icon_name = Config.ICON_NAME + "-symbolic";

    //if (Config.PROFILE == "Devel")
    //  add_css_class("devel"); // changes look of headerbars usually

    var settings = DejaDup.get_settings();
    settings.bind(DejaDup.WINDOW_WIDTH_KEY, this, "default-width", SettingsBindFlags.DEFAULT);
    settings.bind(DejaDup.WINDOW_HEIGHT_KEY, this, "default-height", SettingsBindFlags.DEFAULT);
    settings.bind(DejaDup.WINDOW_MAXIMIZED_KEY, this, "maximized", SettingsBindFlags.DEFAULT);
    settings.bind(DejaDup.WINDOW_FULLSCREENED_KEY, this, "fullscreened", SettingsBindFlags.DEFAULT);

    // If a custom restore backend is set, we switch to restore.
    // If we switch away, we undo the custom restore backend.
    stack.notify["visible-child-name"].connect(on_stack_child_changed);
    deja_app.notify["custom-backend"].connect(on_custom_backend_changed);

    overview_view.bind_to_window(this);
    restore_view.bind_to_window(this);
  }

  ~MainWindow()
  {
    debug("Finalizing MainWindow\n");
  }

  void on_stack_child_changed()
  {
    if (stack.visible_child_name != "restore")
      DejaDupApp.get_instance().custom_backend = null;
  }

  void on_custom_backend_changed()
  {
    if (DejaDupApp.get_instance().custom_backend != null)
      stack.visible_child_name = "restore";
  }
}
