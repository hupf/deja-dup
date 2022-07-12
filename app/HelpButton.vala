/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/HelpButton.ui")]
public class HelpButton : Adw.Bin, Gtk.Buildable
{
  [GtkChild]
  unowned Gtk.Box box;

  public void add_child(Gtk.Builder builder, Object child, string? type)
  {
    var widget = child as Gtk.Widget;
    if (box != null && widget != null)
      box.append(widget);
    else
      base.add_child(builder, child, type);
  }
}
