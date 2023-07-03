/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/HeaderBar.ui")]
public class HeaderBar : Adw.Bin
{
  public Adw.ViewStack stack {get; set;}
  public bool title_visible {get; set; default = true;}

  [GtkChild]
  protected unowned Adw.HeaderBar header;
  [GtkChild]
  unowned Adw.ViewSwitcher switcher;

  construct {
    notify["stack"].connect(reset_stack);

    switcher.ref();
    notify["title-visible"].connect(update_header_title);
    update_header_title();
  }

  void reset_stack()
  {
    if (stack != null) {
      switcher.stack = stack;
    }
  }

  void update_header_title()
  {
    if (title_visible)
      header.title_widget = switcher;
    else
      header.title_widget = null; // switcher stays alive because of our ref()
  }
}
