/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public class ConfigEntry : ConfigWidget
{
  public bool is_uri {get; set;}
  public Gtk.Entry entry {get; construct;}

  public ConfigEntry(string key, string ns="", FilteredSettings? settings=null, bool is_uri=false)
  {
    Object(key: key, ns: ns, is_uri: is_uri, settings: settings);
  }

  public string get_text()
  {
    return entry.get_text();
  }

  public void set_accessible_name (string name)
  {
    var accessible = entry.get_accessible();
    if (accessible != null)
      accessible.set_name(name);
  }

  construct {
    entry = new Gtk.Entry();
    add(entry);
    mnemonic_widget = entry;

    set_from_config.begin();
    entry.focus_out_event.connect(handle_focus_out);
  }

  protected override async void set_from_config()
  {
    var val = is_uri ? settings.get_uri(key) : settings.get_string(key);
    entry.set_text(val);
  }

  public virtual void write_to_config()
  {
    settings.set_string(key, entry.get_text());
  }

  bool handle_focus_out()
  {
    write_to_config();
    return false;
  }
}

}
