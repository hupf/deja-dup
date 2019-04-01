/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public class BackendUnsupported : Backend
{
  public string key {get; construct;}
  public BackendUnsupported(string key) {
    Object(key: key);
  }

  public override bool is_native() {
    return true;
  }

  public override string get_location_pretty()
  {
    return key; // it's not much, but it's something
  }
}

} // end namespace
