/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public class BackendUnsupported : Backend
{
  public override bool is_native() {
    return true;
  }

  public override string get_location(ref bool as_root)
  {
    return "invalid://";
  }

  public override string get_location_pretty()
  {
    return "";
  }

  public override async void get_envp() throws Error {
    throw new IOError.FAILED("%s", _("This storage location is no longer supported. You can still use duplicity directly to back up or restore your files."));
  }
}

} // end namespace
