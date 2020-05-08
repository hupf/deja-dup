/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public class ConfigLocationUnsupported : ConfigLocationTable
{
  public ConfigLocationUnsupported(Gtk.SizeGroup sg) {
    Object(label_sizes: sg);
  }

  construct {
    add_wide_widget(new Gtk.Label(_("This storage location is no longer supported.")));
  }
}

}
