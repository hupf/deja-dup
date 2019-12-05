/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public class ConfigLocationS3 : ConfigLocationTable
{
  public ConfigLocationS3(Gtk.SizeGroup sg, FilteredSettings settings) {
    Object(label_sizes: sg, settings: settings);
  }

  construct {
    add_widget(_("S3 Access Key I_D"),
               new ConfigEntry(DejaDup.S3_ID_KEY, DejaDup.S3_ROOT, settings));
    add_widget(_("_Folder"),
               new ConfigFolder(DejaDup.S3_FOLDER_KEY, DejaDup.S3_ROOT, settings));
  }
}

}
