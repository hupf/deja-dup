/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

/**
 * There are two ways to detect an active GameMode state:
 * - org.freedesktop.portal.GameMode.Active (since xdg-desktop-portal 1.16)
 * - com.feralinteractive.GameMode.ClientCount
 *
 * We'll check both for now, since the portal is too new to fully rely on.
 */

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
  DBusProxy portal = null;
  DBusProxy service = null;

  construct {
    load_proxy.begin();
  }

  async void load_proxy()
  {
    try {
      portal = yield new DBusProxy.for_bus(
        BusType.SESSION,
        DBusProxyFlags.DO_NOT_AUTO_START |
        DBusProxyFlags.GET_INVALIDATED_PROPERTIES,
        null,
        "org.freedesktop.portal.Desktop",
        "/org/freedesktop/portal/desktop",
        "org.freedesktop.portal.GameMode"
      );
      service = yield new DBusProxy.for_bus(
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

    portal.g_properties_changed.connect(update_from_portal);
    service.g_properties_changed.connect(update_from_service);
    update_from_portal();
    update_from_service();
  }

  void update_from_portal()
  {
    var active = portal.get_cached_property("Active");
    if (active != null)
      enabled = active.get_boolean();
  }

  void update_from_service()
  {
    var count = service.get_cached_property("ClientCount");
    if (count != null)
      enabled = count.get_int32() > 0;
  }
}
