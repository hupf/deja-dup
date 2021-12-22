/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

// Gtk.Switch is a final class that can't be subclassed. So this is just
// a little convenience class that lets you subclass a config-appropriate
// switch toggle.

public class ConfigSwitch: Gtk.Box
{
  public signal void activate_signal();

  protected unowned Gtk.Switch toggle;
  construct {
    var owned_toggle = new Gtk.Switch();
    append(owned_toggle);
    toggle = owned_toggle;

    set_activate_signal_from_name("activate-signal");
    activate_signal.connect(do_activate);
  }

  void do_activate()
  {
    toggle.activate();
  }
}
