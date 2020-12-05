/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/MainWindow.ui")]
public class MainWindow : Hdy.ApplicationWindow
{
  public unowned MainHeaderBar get_header()
  {
    return header;
  }

  [GtkChild]
  MainHeaderBar header;
  [GtkChild]
  Gtk.Stack stack;
  [GtkChild]
  Gtk.StackPage backups_page;
  [GtkChild]
  Gtk.Stack overview_stack;
  [GtkChild]
  Gtk.Image app_logo;
  [GtkChild]
  Gtk.Switch auto_backup;
  [GtkChild]
  Browser browser;

  construct {
    var deja_app = DejaDupApp.get_instance();

    // Set a few icons that are hardcoded in ui files
    app_logo.icon_name = Config.ICON_NAME;
    backups_page.icon_name = Config.ICON_NAME + "-symbolic";

    var settings = DejaDup.get_settings();
    settings.bind_with_mapping(DejaDup.LAST_RUN_KEY, overview_stack, "visible-child-name",
                               SettingsBindFlags.GET, get_visible_child, set_visible_child,
                               null, null);

    // If a custom restore backend is set, we switch to restore.
    // If we switch away, we undo the custom restore backend.
    stack.notify["visible-child-name"].connect(on_stack_child_changed);
    deja_app.notify["custom-backend"].connect(on_custom_backend_changed);

    ConfigAutoBackup.bind(auto_backup);
    browser.bind_to_window(this);
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

  [GtkCallback]
  void on_initial_restore()
  {
    DejaDupApp.get_instance().start_custom_restore();
  }

  static bool get_visible_child(Value val, Variant variant, void *data)
  {
    if (variant.get_string() == "")
      val.set_string("initial");
    else
      val.set_string("normal");
    return true;
  }

  // Never called, just here to shut up valac
  static Variant set_visible_child(Value val, VariantType expected_type, void *data)
  {
    return new Variant.string("");
  }
}
