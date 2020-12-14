/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

// This widget displays a tooltip automatically if the target label is ellipsized
public class TooltipBox : Gtk.Box
{
  public Gtk.Label label {get; set;}

  construct {
    has_tooltip = true;
    query_tooltip.connect(on_query_tooltip);
  }

  bool on_query_tooltip(int x, int y, bool keyboard_mode, Gtk.Tooltip tooltip)
  {
    if (label == null || !label.get_layout().is_ellipsized())
      return false;

    tooltip.set_text(label.label);
    return true;
  }
}
