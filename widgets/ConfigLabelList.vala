/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*- */
/*
    This file is part of Déjà Dup.
    © 2009–2010 Michael Terry <mike@mterry.name>

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

public class ConfigLabelList : ConfigLabel
{
  public ConfigLabelList(string key, string ns="")
  {
    Object(key: key, ns: ns);
  }
  
  construct {
    label.set("wrap", true, "wrap-mode", Pango.WrapMode.WORD);
    size_allocate.connect(() => {
      label.set("width-request", this.get_allocated_width());
    });
  }
  
  protected override async void set_from_config()
  {
    string val = "";
    var slist_val = settings.get_value(key);
    string*[] slist = slist_val.get_strv();
    
    var list = DejaDup.parse_dir_list(slist);
    
    int i = 0;
    File home = File.new_for_path(Environment.get_home_dir());
    File trash = File.new_for_path(DejaDup.get_trash_path());
    foreach (File f in list) {
      string s;
      if (f.equal(home))
        s = _("Home Folder");
      else if (f.equal(trash))
        s = _("Trash");
      else if (f.has_prefix(home))
        s = home.get_relative_path(f);
      else
        s = f.get_parse_name();
      
      if (i > 0)
        val += ", ";
      val += s;
      i++;
    }
    
    label.label = val;
  }
}

}

