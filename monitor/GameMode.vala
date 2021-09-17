/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

/**
 * I don't know how to get convenient property-changed signals from something
 * like the following... Please let me know if you know how.

[DBus (name = "com.feralinteractive.GameMode")]
interface GameModeInterface : Object {
  [DBus (name = "ClientCount")]
  public abstract int client_count {  get; }
}
*/

class GameMode : Object
{
  public bool enabled {get; private set; default = false;}

  ///////////
  DBusProxy proxy = null;

  construct {
    load_proxy.begin();
  }

  async void load_proxy()
  {
    try {
      proxy = yield new DBusProxy.for_bus(
        BusType.SESSION,
        DBusProxyFlags.DO_NOT_AUTO_START |
        DBusProxyFlags.GET_INVALIDATED_PROPERTIES,
        null,
        "com.feralinteractive.GameMode",
        "/com/feralinteractive/GameMode",
        "com.feralinteractive.GameMode"
      );
    }
    catch (Error error) {
      warning("%s", error.message);
      return;
    }

    proxy.g_properties_changed.connect(update);
    update();
  }

  void update()
  {
    var count = proxy.get_cached_property("ClientCount");
    enabled = count != null && count.get_int32() > 0;
  }
}
