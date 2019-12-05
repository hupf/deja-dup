/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public class ConfigLocationRackspace : ConfigLocationTable
{
  public ConfigLocationRackspace(Gtk.SizeGroup sg, FilteredSettings settings) {
    Object(label_sizes: sg, settings: settings);
  }

  construct {
    add_widget(_("_Username"),
               new ConfigEntry(DejaDup.RACKSPACE_USERNAME_KEY, DejaDup.RACKSPACE_ROOT, settings));
    add_widget(_("_Container"),
               new ConfigFolder(DejaDup.RACKSPACE_CONTAINER_KEY, DejaDup.RACKSPACE_ROOT, settings));
  }
}

}
