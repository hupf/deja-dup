/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2015 Marius Nünnerich <mnu@google.com>
 */

using GLib;

namespace DejaDup {

public class ConfigLocationGCS : ConfigLocationTable
{
  public ConfigLocationGCS(Gtk.SizeGroup sg, FilteredSettings settings) {
    Object(label_sizes: sg, settings: settings);
  }

  construct {
    // Translators: GCS is Google Cloud Services
    add_widget(_("GCS Access Key I_D"),
               new ConfigEntry(DejaDup.GCS_ID_KEY, DejaDup.GCS_ROOT, settings));
    // Translators: "Bucket" refers to a term used by Google Cloud Services
    // see https://cloud.google.com/storage/docs/key-terms#bucket
    add_widget(_("_Bucket"),
               new ConfigEntry(DejaDup.GCS_BUCKET_KEY, DejaDup.GCS_ROOT, settings));
    add_widget(_("_Folder"),
               new ConfigFolder(DejaDup.GCS_FOLDER_KEY, DejaDup.GCS_ROOT, settings));
  }
}

}
