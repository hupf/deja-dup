/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

class DejaDup.InstallEnvSnap : DejaDup.InstallEnv
{
  public override string? get_name() { return "snap"; }
  public override string get_debug_info() {
   return "Snap Revision: %s\n".printf(Environment.get_variable("SNAP_REVISION"));
  }
}
