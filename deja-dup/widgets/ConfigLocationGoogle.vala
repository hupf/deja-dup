/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public class ConfigLocationGoogle : ConfigLocationTable
{
  public ConfigLocationGoogle(Gtk.SizeGroup sg, FilteredSettings settings) {
    Object(label_sizes: sg, settings: settings);
  }

  construct {
    add_widget(_("_Folder"),
               new ConfigFolder(DejaDup.GOOGLE_FOLDER_KEY, DejaDup.GOOGLE_ROOT, settings));
  }
}

}
