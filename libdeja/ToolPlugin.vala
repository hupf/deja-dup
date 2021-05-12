/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public abstract class DejaDup.ToolPlugin : Object
{
  public string name {get; protected set;}
  public bool requires_encryption {get; protected set; default = false;}
  public abstract string get_version() throws Error;
  public virtual string[] get_dependencies() {return {};} // list of what-provides hints
  public abstract DejaDup.ToolJob create_job() throws Error;
  public abstract bool supports_backend(Backend.Kind kind, out string explanation);
}
