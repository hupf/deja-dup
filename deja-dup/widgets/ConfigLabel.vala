/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public class ConfigLabel : ConfigWidget
{
  public ConfigLabel(string? key, string ns="")
  {
    Object(key: key, ns: ns);
  }

  protected Gtk.Grid box;
  protected Gtk.Label label;
  construct {
    label = new Gtk.Label("");
    box = new Gtk.Grid();
    box.column_spacing = 6;
    add(box);
    fill_box();
    set_from_config.begin();
  }

  protected virtual void fill_box()
  {
    label.xalign = 0.0f;
    label.hexpand = true;
    box.add(label);
  }

  protected override async void set_from_config()
  {
    label.label = settings.get_string(key);
  }
}

}
