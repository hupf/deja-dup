/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

// Not really a widget, because:
// (A) GtkSwitch is "final" and can't be subclassed and
// (B) Vala doesn't seem to have a way to mark a custom widget as activatable
//     (https://discourse.gnome.org/t/how-to-mark-a-custom-widget-as-activatable-in-vala/4924)
// So instead, this is just a shell of a class that provides one utility method
// to bind a switch like we need.
public class ConfigAutoBackup
{
  public static void bind(Gtk.Switch auto_switch) {
    var settings = DejaDup.get_settings();
    settings.bind(DejaDup.PERIODIC_KEY, auto_switch, "active", SettingsBindFlags.GET);

    auto_switch.state_set.connect(on_state_set);
  }

  static bool on_state_set(Gtk.Switch auto_switch, bool state)
  {
    if (state) {
      Background.request_autostart.begin(auto_switch, (obj, res) => {
        if (Background.request_autostart.end(res)) {
          auto_switch.state = true; // finish state set
          set_periodic(true);
        } else {
          auto_switch.active = false; // flip switch back to unset mode
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
