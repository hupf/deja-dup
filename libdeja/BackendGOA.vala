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

public const string GOA_ROOT = "GOA";
public const string GOA_ID_KEY = "id";
public const string GOA_FOLDER_KEY = "folder";
public const string GOA_TYPE_KEY = "type";
public const string GOA_MIGRATED_KEY = "migrated";

#if HAS_GOA
public class BackendGOA : BackendRemote
{
  static Goa.Client _client;

  public BackendGOA(Settings? settings) {
    Object(settings: (settings != null ? settings : get_settings(GOA_ROOT)));
  }

  public static Goa.Client get_client_sync()
  {
    if (_client == null) {
      try {
        _client = new Goa.Client.sync(null);
      } catch (Error e) {
        warning("Couldn't get GOA client: %s", e.message);
      }
    }
    return _client;
  }

  public async string? get_access_token()
  {
    var obj = get_object_from_settings();
    if (obj == null)
      return null;
    var oauth2 = obj.get_oauth2_based();
    if (oauth2 == null)
      return null;

    try {
      string access_token;
      // the async version didn't work when I tested it, maybe a bad binding
      oauth2.call_get_access_token_sync(out access_token, null);
      return access_token;
    }
    catch (Error e) {
      return null;
    }
  }

  public override string get_folder()
  {
    return get_folder_key(settings, GOA_FOLDER_KEY, true);
  }

  public Goa.Object? get_object_from_settings()
  {
    var id = settings.get_string(GOA_ID_KEY);
    return get_client_sync().lookup_by_id(id);
  }

  public override File? get_root_from_settings()
  {
    var obj = get_object_from_settings();
    if (obj == null)
      return null;
    var files = obj.get_files();
    if (files == null)
      return null;

    return File.new_for_uri(files.uri);
  }
}
#endif
} // end namespace
