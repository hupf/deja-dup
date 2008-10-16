/* -*- Mode: C; indent-tabs-mode: nil; c-basic-offset: 2; tab-width: 2 -*- */
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

public const string FILE_PATH_KEY = "/apps/deja-dup/file/path";

public class BackendFile : Backend
{
  public override string? get_location() throws Error
  {
    var client = GConf.Client.get_default();
    var path = client.get_string(FILE_PATH_KEY);
    if (path == null) {
      var dlg = new Gtk.FileChooserDialog(_("Choose backup destination"),
                                          toplevel,
                                          Gtk.FileChooserAction.CREATE_FOLDER,
                                          Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
                            				      Gtk.STOCK_OPEN, Gtk.ResponseType.ACCEPT);
      
      if (dlg.run() != Gtk.ResponseType.ACCEPT) {
        dlg.hide();
        return null;
      }
      
      path = dlg.get_filename();
      dlg.hide();
    }
    return "file://%s".printf(path);
  }
}

