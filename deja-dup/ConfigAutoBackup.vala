/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class ConfigAutoBackup: Gtk.Box
{
  public signal void activate_signal();

  unowned Gtk.Switch toggle;
  construct {
    var owned_toggle = new Gtk.Switch();
    append(owned_toggle);
    toggle = owned_toggle;

    set_activate_signal_from_name("activate-signal");
    activate_signal.connect(do_activate);

    var settings = DejaDup.get_settings();
    settings.bind(DejaDup.PERIODIC_KEY, toggle, "active", SettingsBindFlags.GET);
    toggle.state_set.connect(on_state_set);
  }

  void do_activate()
  {
    toggle.activate();
  }

  bool on_state_set(bool state)
  {
    if (state) {
      Background.request_autostart.begin(toggle, (obj, res) => {
        if (Background.request_autostart.end(res)) {
          toggle.state = true; // finish state set
          set_periodic(true);
        } else {
          toggle.active = false; // flip switch back to unset mode
        }
      });
      return true; // delay setting of state
    }

    set_periodic(false);
    return false;
  }

  static void set_periodic(bool state)
  {
    var settings = DejaDup.get_settings();
    settings.set_boolean(DejaDup.PERIODIC_KEY, state);
  }
}
