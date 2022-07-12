/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/OverviewPage.ui")]
public class OverviewPage : Adw.Bin
{
  [GtkChild]
  unowned Adw.StatusPage status_page;

  construct {
    status_page.icon_name = Config.ICON_NAME;
  }
}
