/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

internal class ResticInstance : ToolInstance
{
  public signal void message(Json.Reader reader);
  public signal void no_repository();
  public signal void bad_password();
  public signal void fatal_error(string msg);

  protected override void _send_error(Error e)
  {
    fatal_error(e.message);
  }

  protected override bool _process_line(string stanza, string line) throws Error
  {
    // FIXME: need to fix these upstream to emit a json message for this
    if (line.has_prefix("Fatal: unable to open config file: ")) {
      no_repository();
      return true;
    }
    if (line == "Fatal: wrong password or no key found" ||
        line == "Fatal: an empty password is not a password")
    {
      bad_password();
      return true;
    }
    if (line.has_prefix("Fatal: ")) {
      fatal_error(line.substring(7));
      return true;
    }

    // Most messages are dictionaries, but the snapshots command gives an array
    var is_stanza = (line.has_prefix("{") && line.has_suffix("}")) ||
                    (line.has_prefix("[") && line.has_suffix("]"));
    if (!is_stanza)
      return true;

    var parser = new Json.Parser.immutable_new();
    parser.load_from_data(stanza);

    var root = parser.get_root();
    message(new Json.Reader(root));

    return true;
  }
}
