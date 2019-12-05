/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public class ConfigFolder : ConfigEntry
{
  public bool abs_allowed {get; construct;}

  public ConfigFolder(string key, string ns="", FilteredSettings? settings=null, bool abs_allowed=false)
  {
    Object(key: key, ns: ns, abs_allowed: abs_allowed, settings: settings);
  }

  protected override async void set_from_config()
  {
    var val = DejaDup.get_folder_key(settings, key, abs_allowed);
    entry.set_text(val);
  }
}

}
