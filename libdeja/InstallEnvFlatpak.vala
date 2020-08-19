/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[DBus (name = "org.freedesktop.portal.Background")]
interface BackgroundInterface : Object {
  public abstract async ObjectPath request_background(
    string parent_window, HashTable<string, Variant> options
  ) throws Error;
}

class DejaDup.InstallEnvFlatpak : DejaDup.InstallEnv
{
  public override string? get_name() { return "flatpak"; }

  public override string[] get_system_tempdirs()
  {
    // If we use /tmp or /var/tmp from inside of a container like flatpak's, gvfs
    // (which is outside the container) won't see our /var/tmp/xxx path and error
    // out.  So we do without system tempdirs (relying only on the user's home
    // cache dir).
    return {};
  }

  public override bool request_autostart(string handle, out string? mitigation)
  {
    var request = new FlatpakAutostartRequest();
    return request.request_autostart(handle, out mitigation);
  }

  FileMonitor update_monitor;
  public override void register_monitor_restart(MainLoop loop)
  {
    var file = File.new_for_path("/app/.updated");
    try {
      update_monitor = file.monitor_file(FileMonitorFlags.NONE);
      update_monitor.changed.connect(() => {
        var cmd = "flatpak-spawn --latest-version %s".printf(get_monitor_exec());
        try {
          Process.spawn_command_line_async(cmd);
          loop.quit();
        } catch (SpawnError e) {
          warning("%s", e.message);
        }
      });
    } catch (IOError e) {
      warning("%s", e.message);
    }
  }

  public override bool is_file_available(File file)
  {
    // https://docs.flatpak.org/en/latest/sandbox-permissions.html#filesystem-access
    string[] hidden = { "/lib", "/lib32", "/lib64", "/bin", "/sbin", "/usr",
                        "/boot", "/root", "/tmp", "/etc", "/app", "/run",
                        "/proc", "/sys", "/dev", "/var" };
    string[] allowed = { "/run/media", Environment.get_home_dir() };

    foreach (var f in allowed) {
      var ffile = File.new_for_path(f);
      if (file.equal(ffile) || file.has_prefix(ffile))
        return true;
    }

    foreach (var f in hidden) {
      var ffile = File.new_for_path(f);
      if (file.equal(ffile) || file.has_prefix(ffile))
        return false;
    }

    return true;
  }
}

class DejaDup.FlatpakAutostartRequest : Object
{
  const string PORTAL_NAME = "org.freedesktop.portal.Desktop";
  const string PORTAL_PATH = "/org/freedesktop/portal/desktop";
  const string REQUEST_IFACE = "org.freedesktop.portal.Request";

  bool autostart_allowed;
  MainLoop loop;
  DBusConnection connection;
  uint signal_id;

  public bool request_autostart(string handle, out string? mitigation)
  {
    mitigation = _("Make sure Backups has permission to run in " +
                   "the background in Settings → Applications → " +
                   "Backups and try again.");

    loop = new MainLoop(null, false);

    request_autostart_helper.begin(handle);

    // And wait for response (loop is quit in got_response)
    loop.run();
    loop = null;

    if (signal_id > 0) {
      connection.signal_unsubscribe(signal_id);
      signal_id = 0;
    }

    return autostart_allowed;
  }

  string get_request_path(DBusConnection connection, string token)
  {
    var sender = connection.get_unique_name().substring(1).replace(".", "_");
    return "/org/freedesktop/portal/desktop/request/%s/%s".printf(sender, token);
  }

  void got_response(DBusConnection connection, string? sender_name,
                    string object_path, string interface_name,
                    string signal_name, Variant parameters)
  {
    int response;
    Variant values;
    parameters.get("(u@a{sv})", out response, out values);

    if (response == 0) {
      bool autostart;
      values.lookup("autostart", "b", out autostart);
      autostart_allowed = autostart;
    }

    loop.quit();
  }

  async void request_autostart_helper(string handle)
  {
    // When we can rely on xdg-desktop-portal >=1.5.0, we can specify our own handle_token.
    // (Before then, there is a bug that prevents it noticing our handle_token.)
    // For now, just re-specify the default token.
    var token = "t"; // "deja_dup_%u".printf(Random.next_int());

    var options = new HashTable<string, Variant>(str_hash, str_equal);
    options.insert("autostart", new Variant.boolean(true));
    options.insert("commandline", new Variant.strv({get_monitor_exec()}));
    options.insert("handle_token", new Variant.string(token));

    try {
      connection = yield Bus.get(BusType.SESSION);

      // Listen to the expected request object path for its response
      var expected_path = get_request_path(connection, token);
      signal_id = connection.signal_subscribe(
        PORTAL_NAME, REQUEST_IFACE, "Response", expected_path, null,
        DBusSignalFlags.NO_MATCH_RULE, got_response);

      // Actually start the background request
      BackgroundInterface iface = yield connection.get_proxy(PORTAL_NAME, PORTAL_PATH);
      yield iface.request_background(handle, options);
    }
    catch (Error e) { // no portal support :(
      loop.quit();
    }
  }
}
