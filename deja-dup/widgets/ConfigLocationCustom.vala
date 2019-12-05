/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public class ConfigLocationCustom : ConfigLocationTable
{
  public ConfigLocationCustom(Gtk.SizeGroup sg, FilteredSettings settings) {
    Object(label_sizes: sg, settings: settings);
  }

  Gtk.Popover hint = null;
  construct {
    var address = new ConfigEntry(DejaDup.REMOTE_URI_KEY, DejaDup.REMOTE_ROOT,
                                  settings, true);
    address.set_accessible_name("CustomAddress");
    address.entry.set_icon_from_icon_name(Gtk.EntryIconPosition.SECONDARY,
                                          "dialog-question-symbolic");
    address.entry.icon_press.connect(show_hint);
    add_widget(_("_Network Location"), address);

    hint = create_hint(address.entry);

    var folder = new ConfigFolder(DejaDup.REMOTE_FOLDER_KEY, DejaDup.REMOTE_ROOT, settings, true);
    folder.set_accessible_name("CustomFolder");
    add_widget(_("_Folder"), folder);
  }

  void show_hint(Gtk.Entry entry, Gtk.EntryIconPosition icon_pos, Gdk.Event event)
  {
    Gdk.Rectangle rect = entry.get_icon_area(icon_pos);
    hint.set_pointing_to(rect);
    hint.show_all();
  }

  Gtk.Popover create_hint(Gtk.Entry parent)
  {
    var builder = new Gtk.Builder.from_resource("/org/gnome/DejaDup%s/server-hint.ui".printf(Config.PROFILE));
    var popover = builder.get_object("server_adresses_popover") as Gtk.Popover;
    popover.relative_to = parent;
    return popover;
  }
}

}
