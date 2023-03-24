/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public class Network : Object
{
  public bool connected {get; private set; default = true;}
  public bool metered {get; private set; default = false;}

  public new static Network get() {
    if (singleton == null)
      singleton = new Network();
    return singleton;
  }

  public async bool can_reach(string url)
  {
    var mon = NetworkMonitor.get_default();
    try {
      var socket = NetworkAddress.parse_uri(url, 0);
      return yield mon.can_reach_async(socket);
    }
    catch (Error e) {
      warning("%s", e.message);
      return false;
    }
  }

  construct {
    var mon = NetworkMonitor.get_default();

    mon.notify["connectivity"].connect(update_connected);
    update_connected();

    mon.notify["network-metered"].connect(update_metered);
    update_metered();
  }

  void update_connected()
  {
    var connectivity = NetworkMonitor.get_default().connectivity;
    // Allow full or limited (but not portal) connectivity.
    // It's possible we shouldn't allow limited either, but I don't know enough
    // about the scenarios in which it applies. So we'll allow it for now.
    connected = connectivity == NetworkConnectivity.FULL ||
                connectivity == NetworkConnectivity.LIMITED;
  }

  void update_metered()
  {
    var mon = NetworkMonitor.get_default();
    var settings = DejaDup.get_settings();
    var allow_metered = settings.get_boolean(DejaDup.ALLOW_METERED_KEY);
    metered = mon.network_metered && !allow_metered;
  }

  static Network singleton;
}

} // end namespace
