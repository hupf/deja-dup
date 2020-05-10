/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class BuilderWidget : Object
{
  public Gtk.Builder builder {get; construct;}
  protected Gtk.Widget adopted;

  protected void adopt_name(string name)
  {
    adopt_widget(builder.get_object(name) as Gtk.Widget);
  }

  // After this call, we won't be destroyed until widget is
  protected void adopt_widget(Gtk.Widget widget)
  {
    ref();
    adopted = widget;
    widget.destroy.connect(() => {
      adopted = null;
      unref();
    });
  }
}
