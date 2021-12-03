/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class ConfigAutoBackup: ConfigSwitch
{
  construct {
    var settings = DejaDup.get_settings();
    settings.bind(DejaDup.PERIODIC_KEY, this.toggle, "active", SettingsBindFlags.GET);
    this.toggle.state_set.connect(on_state_set);
  }

  bool on_state_set(bool state)
  {
    if (state) {
      var window = this.root as Gtk.Window;
      if (window == null) {
        return true; // can happen if this switch wasn't finalized
      }

      Background.request_autostart.begin(this.toggle, (obj, res) => {
        if (Background.request_autostart.end(res)) {
          this.toggle.state = true; // finish state set
          set_periodic(true);
        } else {
          this.toggle.active = false; // flip switch back to unset mode
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
