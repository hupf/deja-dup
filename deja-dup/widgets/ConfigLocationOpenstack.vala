/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public class ConfigLocationOpenstack : ConfigLocationTable
{
  public ConfigLocationOpenstack(Gtk.SizeGroup sg, FilteredSettings settings) {
    Object(label_sizes: sg, settings: settings);
  }

  construct {
    add_widget(_("_Username"),
               new ConfigEntry(DejaDup.OPENSTACK_USERNAME_KEY, DejaDup.OPENSTACK_ROOT, settings));
    add_widget(_("_Container"),
               new ConfigFolder(DejaDup.OPENSTACK_CONTAINER_KEY, DejaDup.OPENSTACK_ROOT, settings));
    add_widget(_("_Authentication URL"),
               new ConfigFolder(DejaDup.OPENSTACK_AUTHURL_KEY, DejaDup.OPENSTACK_ROOT, settings));
    add_widget(_("_Tenant name"),
               new ConfigFolder(DejaDup.OPENSTACK_TENANT_KEY, DejaDup.OPENSTACK_ROOT, settings));
  }
}

}
