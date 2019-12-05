/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public class ConfigLabelLocation : ConfigLabel
{
  Gtk.Image img;
  public ConfigLocation location {get; construct;}

  public ConfigLabelLocation(ConfigLocation location)
  {
    Object(key: null, location: location);
  }

  construct {
    img = new Gtk.Image.from_icon_name("folder", Gtk.IconSize.MENU);
    fill_box();
    foreach (var setting in location.get_all_settings()) {
      watch_key(null, setting);
    }
    set_from_config.begin();
  }

  protected override void fill_box()
  {
    if (img == null)
      return;

    img.expand = false;
    box.add(img);

    label.xalign = 0.0f;
    label.ellipsize = Pango.EllipsizeMode.MIDDLE;
    box.add(label);
  }

  protected override async void set_from_config()
  {
    if (img == null)
      return;

    var backend = location.get_backend();

    string desc = backend.get_location_pretty();
    if (desc == null)
      desc = "";
    label.label = desc;

    Icon icon = backend.get_icon();
    if (icon == null)
      img.set_from_icon_name("folder", Gtk.IconSize.MENU);
    else
      img.set_from_gicon(icon, Gtk.IconSize.MENU);
  }
}

}
