/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class Builder : Gtk.Builder
{
  public string name {get; construct;}

  public Builder(string name) {
    Object(name: name);
  }

  construct {
    try {
      add_from_resource("/org/gnome/DejaDup%s/%s.ui".printf(Config.PROFILE, name));
    }
    catch (Error e) {
      warning("%s\n", e.message);
    }

    connect_signals(null);
  }
}
