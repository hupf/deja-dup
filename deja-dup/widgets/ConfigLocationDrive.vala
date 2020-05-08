/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public class ConfigLocationDrive : ConfigLocationTable
{
  public ConfigLocationDrive(Gtk.SizeGroup sg, FilteredSettings settings) {
    Object(label_sizes: sg, settings: settings);
  }

  construct {
    var entry = new ConfigFolder(DejaDup.DRIVE_FOLDER_KEY, DejaDup.DRIVE_ROOT, settings);
    entry.set_accessible_name("VolumeFolder");
    add_widget(_("_Folder"), entry);
  }
}

}
