/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*- */
/*
    This file is part of Déjà Dup.
    © 2011 Michael Terry <mike@mterry.name>

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

/* This is a very simple class that just proxies calls to a Settings object.
   Its one difference is that it won't set a value that is already set to the
   requested value.  This prevents us from causing unnecessary 'changed'
   signals and generally from doing lots writes every time something in the UI
   is adjusted.

   Additionally, doing lots of simultaneous reads & writes sometimes confuses
   dconf, so it's nice to be able to avoid those.
 */

public class SimpleSettings : Settings
{
  public SimpleSettings(string schema)
  {
    Object(schema: schema);
  }

  public new void set_string(string k, string v) {if (get_string(k) != v) base.set_string(k, v);}
  public new void set_boolean(string k, bool v) {if (get_boolean(k) != v) base.set_boolean(k, v);}
  public new void set_int(string k, int v) {if (get_int(k) != v) base.set_int(k, v);}

  // TODO: value, bytestring, strv
}

}
