/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public class ConfigBool : ConfigWidget
{
  public string label {get; construct;}

  public ConfigBool(string key, string label, string ns="")
  {
    Object(key: key, label: label, ns: ns);
  }

  public signal void toggled(ConfigBool check, bool user);
  public bool get_active() {return button.get_active();}

  protected Gtk.CheckButton button;
  protected bool user_driven = true;
  construct {
    button = new Gtk.CheckButton.with_mnemonic(label);
    add(button);

    set_from_config.begin();
    button.toggled.connect(handle_toggled);
  }

  protected override async void set_from_config()
  {
    var val = settings.get_boolean(key);
    var prev = user_driven;
    user_driven = false;
    button.set_active(val);
    user_driven = prev;
  }

  protected virtual void handle_toggled()
  {
    settings.set_boolean(key, button.get_active());
    toggled(this, user_driven);
  }
}

}
