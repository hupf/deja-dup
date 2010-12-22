/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*- */
/*
    This file is part of Déjà Dup.
    © 2008–2010 Michael Terry <mike@mterry.name>

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

public class ConfigBool : ConfigWidget, Togglable
{
  public string label {get; construct;}
  
  public ConfigBool(string key, string label, string ns="")
  {
    Object(key: key, label: label, ns: ns);
  }
  
  public bool get_active() {return button.get_active();}
  
  protected Gtk.CheckButton button;
  protected ulong toggle_id;
  construct {
    button = new Gtk.CheckButton.with_mnemonic(label);
    add(button);
    
    set_from_config();
    toggle_id = button.toggled.connect(handle_toggled);
  }
  
  protected override async void set_from_config()
  {
    var val = settings.get_boolean(key);
    button.disconnect(toggle_id);
    button.set_active(val);
    toggled(this, false);
    toggle_id = button.toggled.connect(handle_toggled);
  }
  
  protected virtual void handle_toggled()
  {
    settings.set_boolean(key, button.get_active());
    toggled(this, true);
  }
}

}

