/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/ConfigServerEntry.ui")]
class ConfigServerEntry : Gtk.Entry
{
  [GtkChild]
  unowned ServerHintPopover popover;

  [GtkCallback]
  void on_icon_press(Gtk.EntryIconPosition icon_pos)
  {
    var rect = get_icon_area(icon_pos);
    popover.set_pointing_to(rect);
    popover.popup();
  }

  public override void dispose()
  {
    popover.unparent();
    base.dispose();
  }

  public override void size_allocate(int width, int height, int baseline)
  {
    base.size_allocate(width, height, baseline);
    popover.present();
  }
}
