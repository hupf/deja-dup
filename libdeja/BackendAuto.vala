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

public class BackendAuto : Backend
{
  public override bool is_native() {
    return false;
  }

  public override Icon? get_icon() {
    return null;
  }

  public override async bool is_ready(out string when) {
    when = null;
    return false;
  }

  public override string get_location(ref bool as_root) {
    return "invalid://";
  }

  public override string get_location_pretty() {
    return "";
  }

  construct {
    // The intent here is that changing gsettings defaults won't
    // change the user's backup (i.e. ensuring that the storage location
    // gsettings would be actively set, not relying on the gschema default).
    //
    // Here is a brief history of defaults:
    // 1) Amazon S3
    // 2) We checked various dependencies to see which backend to use
    // 3) Google Drive via GNOME Online Accounts
    // 4) Google Drive (relying on packagekit support to install dependencies)
    var settings = get_settings();
    settings.set_string(BACKEND_KEY, "google");
  }
}

} // end namespace

