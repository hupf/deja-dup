/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/WelcomePage.ui")]
public class WelcomePage : Gtk.Box
{
  [GtkChild]
  unowned Adw.StatusPage status_page;

  construct {
    status_page.icon_name = Config.ICON_NAME;
  }

  [GtkCallback]
  void on_initial_restore()
  {
    DejaDupApp.get_instance().start_custom_restore();
  }
}
