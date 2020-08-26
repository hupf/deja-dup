/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
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

public class Background : Object
{
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

  public bool request_autostart(Gtk.Widget widget)
  {
    var window = widget.get_toplevel() as Gtk.Window;

    string? mitigation;
    var install_env = DejaDup.InstallEnv.instance();
    var allowed = install_env.request_autostart(get_window_handle(window),
                                                out mitigation);

    if (!allowed && mitigation != null)
      DejaDup.run_error_dialog(window, _("Cannot back up automatically"),
                               mitigation);

    return allowed;
  }
}
