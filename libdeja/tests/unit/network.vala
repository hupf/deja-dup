/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

async void check_status(MainLoop loop)
{
  var nw = DejaDup.Network.get();
  var can_reach = yield nw.can_reach("https://example.com/");
  var can_reach2 = yield nw.can_reach("http://nowhere.local/");
  print("Connected: %d\n", (int)nw.connected);
  print("Metered: %d\n", (int)nw.metered);
  print("Can reach example.com: %d\n", (int)can_reach);
  print("Can reach local server: %d\n", (int)can_reach2);
  loop.quit();
}

int main(string[] args)
{
  var loop = new MainLoop(null);
  check_status.begin(loop);
  loop.run();
  return 0;
}
