/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*- */
/*
    This file is part of Déjà Dup.
    For copyright information, see AUTHORS.

    Déjà Dup is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Déjà Dup is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Déjà Dup.  If not, see <http://www.gnu.org/licenses/>.
*/

using GLib;


/**
 * There are several supported installations, which affect autostarting:
 *
 * Traditional distro package.
 * - We ship an /etc/xdg/autostart file.
 * - After 30 days, we use that autostart to prompt the user to consider backing up.
 * - May or may not support the Background portal, but we don't need or use it.
 *
 * Snap package.
 * - On first start, we make an autostart file in the expected snap user data folder.
 * - No prompt support as a result.
 * - Does not support the Background portal, but we don't need or use it.
 *
 * Flatpak package.
 * - Uses the Background portal when the user enables automatic backups.
 * - Since we can't query permission status, we just ask the portal each time and don't notice revocations.
 */


[DBus (name = "org.freedesktop.portal.Background")]
interface BackgroundInterface : Object {
  public abstract async ObjectPath request_background(
    string parent_window, HashTable<string, Variant> options
  ) throws Error;
}

public class Background : Object
{
  public bool autostart_allowed {get; private set; default = false;}
  public bool permission_refused {get; private set; default = false;}

  const string PORTAL_NAME = "org.freedesktop.portal.Desktop";
  const string PORTAL_PATH = "/org/freedesktop/portal/desktop";
  const string REQUEST_IFACE = "org.freedesktop.portal.Request";

  MainLoop loop = null;
  DBusConnection connection = null;
  bool started = false;
  int response = -1;
  uint signal_id = 0;

  construct {
    this.loop = new MainLoop(null, false);
  }

  ~Background() {
    if (signal_id > 0)
      connection.signal_unsubscribe(signal_id);
  }

  string get_window_handle(Gtk.Window window)
  {
    var gdk_window = window.get_window();
#if HAS_X11
    var x11_window = gdk_window as Gdk.X11.Window;
    if (x11_window != null)
      return "x11:%x".printf((uint)x11_window.get_xid());
#endif
    // TODO: support wayland windows too, once we have easy vala bindings
    return "";
  }

  string get_request_path(DBusConnection connection, string token)
  {
    var sender = connection.get_unique_name().substring(1).replace(".", "_");
    return "/org/freedesktop/portal/desktop/request/%s/%s".printf(sender, token);
  }

  void got_response(DBusConnection connection, string sender_name, string object_path,
                    string interface_name, string signal_name, Variant parameters)
  {
    Variant values;
    parameters.get("(u@a{sv})", out this.response, out values);

    if (this.response == 0) {
      bool autostart;
      values.lookup("autostart", "b", out autostart);
      this.autostart_allowed = autostart;
    }
    if (this.response == 1)
      this.permission_refused = true;

    this.loop.quit();
  }

  async void request_background_helper(Gtk.Window window)
  {
    // When we can rely on xdg-desktop-portal >=1.5.0, we can specify our own handle_token.
    // (Before then, there is a bug that prevents it noticing our handle_token.)
    // For now, just re-specify the default token.
    var token = "t"; // "deja_dup_%u".printf(Random.next_int());

    var handle = get_window_handle(window);
    var options = new HashTable<string, Variant>(str_hash, str_equal);
    options.insert("autostart", new Variant.boolean(true));
    options.insert("commandline", new Variant.strv({DejaDup.get_monitor_exec()}));
    options.insert("handle_token", new Variant.string(token));

    try {
      connection = yield Bus.get(BusType.SESSION);

      // Listen to the expected request object path for its response
      var expected_path = get_request_path(connection, token);
      signal_id = connection.signal_subscribe(PORTAL_NAME, REQUEST_IFACE, "Response",
                                              expected_path, null,
                                              DBusSignalFlags.NO_MATCH_RULE, got_response);

      // Actually start the background request
      BackgroundInterface iface = yield connection.get_proxy(PORTAL_NAME, PORTAL_PATH);
      yield iface.request_background(handle, options);
    }
    catch (Error e) { // no portal support :(
      this.loop.quit();
    }
  }

  public bool request_autostart(Gtk.Widget widget)
  {
    // We currently only actually bother checking with the Background portal in flatpak land.
    var flatpak_id = Environment.get_variable("FLATPAK_ID");
    if (flatpak_id == null) {
      this.autostart_allowed = true;
      return this.autostart_allowed;
    }

    // Check to make sure that we haven't been called before
    if (!this.started) {
      this.started = true;

      this.request_background_helper.begin(widget.get_toplevel() as Gtk.Window);

      // And wait for response (loop is quit in got_response)
      this.loop.run();
    }

    return this.autostart_allowed;
  }
}
