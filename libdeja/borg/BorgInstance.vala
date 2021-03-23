/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

internal class BorgInstance : ToolInstance
{
  public signal void message(Json.Reader reader);

  protected override void _send_error(Error e)
  {
    // FIXME message({"ERROR", "1"}, null, e.message);
  }

  protected override bool _process_line(string stanza, string line) throws Error
  {
    var stanza_done = line == "}" || (line.has_prefix("{") && line.length > 1);
    if (!stanza_done)
      return false;

    var parser = new Json.Parser.immutable_new();
    parser.load_from_data(stanza);

    var root = parser.get_root();
    message(new Json.Reader(root));

    return true;
  }
}
