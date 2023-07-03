/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/OverviewToolbarView.ui")]
public class OverviewToolbarView : Adw.Bin
{
  [GtkChild]
  unowned HeaderBar header;
  [GtkChild]
  unowned Gtk.Stack overview_stack;
  [GtkChild]
  unowned Adw.ViewSwitcherBar bottom_bar;

  unowned MainWindow app_window;

  construct {
    var settings = DejaDup.get_settings();
    settings.bind_with_mapping(DejaDup.LAST_RUN_KEY, overview_stack, "visible-child-name",
                               SettingsBindFlags.GET, get_visible_child, set_visible_child,
                               null, null);
  }

  public void bind_to_window(MainWindow win)
  {
    app_window = win;
    header.stack = win.get_view_stack();
    bottom_bar.stack = win.get_view_stack();

    app_window.notify["thin-mode"].connect(update_header_bar);
    overview_stack.notify["visible-child-name"].connect(update_header_bar);
    update_header_bar();
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

  void update_header_bar()
  {
    var welcome_state = overview_stack.visible_child_name == "initial";
    header.title_visible = !app_window.thin_mode && !welcome_state;
    bottom_bar.reveal = app_window.thin_mode && !welcome_state;
  }
}
