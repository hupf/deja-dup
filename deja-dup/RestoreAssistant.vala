/* -*- Mode: C; indent-tabs-mode: nil; tab-width: 2 -*- */
/*
    Déjà Dup
    © 2008 Michael Terry <mike@mterry.name>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

using GLib;

public class RestoreAssistant : Gtk.Assistant
{
  construct
  {
    add_restore_type_page();
  }
  
  void add_restore_type_page()
  {
    Gtk.Widget w = new Gtk.Label("Hi");
    
    append_page(w);
    set_page_title(w, _("Where to restore?"));
    set_page_type(w, Gtk.AssistantPageType.CONTENT);
  }
}

