/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
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

  public override string get_location() {
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

