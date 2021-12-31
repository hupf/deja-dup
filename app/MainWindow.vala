/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/MainWindow.ui")]
public class MainWindow : Adw.ApplicationWindow
{
  public unowned MainHeaderBar get_header()
  {
    return header;
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
  unowned MainHeaderBar header;
  [GtkChild]
  unowned Adw.ViewStack stack;
  [GtkChild]
  unowned Adw.ViewStackPage backups_page;
  [GtkChild]
  unowned Gtk.Stack overview_stack;
  [GtkChild]
  unowned Browser browser;
  [GtkChild]
  unowned Adw.ViewSwitcherBar bar;

  construct {
    var deja_app = DejaDupApp.get_instance();

    // Set a few icons that are hardcoded in ui files
    backups_page.icon_name = Config.ICON_NAME + "-symbolic";

    if (Config.PROFILE == "Devel")
      add_css_class("devel"); // changes look of headerbars usually

    var settings = DejaDup.get_settings();
    settings.bind_with_mapping(DejaDup.LAST_RUN_KEY, overview_stack, "visible-child-name",
                               SettingsBindFlags.GET, get_visible_child, set_visible_child,
                               null, null);

    header.notify["title-visible"].connect(on_title_visible_changed);
    on_title_visible_changed();

    // If a custom restore backend is set, we switch to restore.
    // If we switch away, we undo the custom restore backend.
    stack.notify["visible-child-name"].connect(on_stack_child_changed);
    deja_app.notify["custom-backend"].connect(on_custom_backend_changed);

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

  void on_title_visible_changed()
  {
    // Without this width check, I've noticed that the status page "settles"
    // after a second or two once you interact with the window - by shifting
    // down a bit. Seems that during startup, the title is visible for a moment,
    // but the bar isn't ready yet? I haven't debugged the exact race condition
    // issue. But this prevents the bad settling behavior:
    if (bar.get_allocated_width() > 0)
      bar.reveal = header.title_visible;
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
