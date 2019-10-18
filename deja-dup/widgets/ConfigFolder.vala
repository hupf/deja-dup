/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*- */
/*
    This file is part of Déjà Dup.
    For copyright information, see AUTHORS.

    Déjà Dup is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Déjà Dup is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Déjà Dup.  If not, see <http://www.gnu.org/licenses/>.
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
