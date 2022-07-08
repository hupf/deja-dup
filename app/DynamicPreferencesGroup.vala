/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

// Dynamically hides rows that don't match the current mode. (Ironically, this
// does not support removing rows during operation.)
//
// The way this is implemented is that all rows are always children of the
// group and we just selectively hide or show swaths of them at a time, based
// on the `mode` property. Other simpler ways of achieving this same effect
// might have been using a GtkStack with each set of rows on their own stack
// page or some similar "swap out a parent widget's visibility" scheme.
// But libadwaita's stylesheets made that hard, because of the way they style
// rows that aren't direct members of a listbox. (At least, I didn't find an
// easy way to trick it.) So here we are.
public class DynamicPreferencesGroup : Adw.PreferencesGroup, Gtk.Buildable
{
  public string mode {get; set;}

  HashTable<unowned Gtk.Widget, string> children_types =
    new HashTable<unowned Gtk.Widget, string>(direct_hash, direct_equal);

  construct {
    notify["mode"].connect(reset_row_visibility);
    reset_row_visibility();
  }

  public void add_child(Gtk.Builder builder, Object child, string? type)
  {
    base.add_child(builder, child, null);

    var widget = child as Gtk.Widget;
    if (widget != null && type != null)
    {
      children_types.insert(widget, type);
      widget.visible = false;
    }
  }

  void reset_row_visibility()
  {
    children_types.@foreach((child, type) => {
      child.set_visible(type == mode);
    });
  }
}
