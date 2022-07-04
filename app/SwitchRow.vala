/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

// A simple action row holding a Gtk.Switch
[GtkTemplate (ui = "/org/gnome/DejaDup/SwitchRow.ui")]
public class SwitchRow : Adw.ActionRow
{
  public bool active {get; set;}
}
