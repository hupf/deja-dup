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
  static string get_window_handle(Gtk.Window window)
  {
#if HAS_X11
    // TODO: gtk4 https://gitlab.gnome.org/GNOME/vala/-/issues/1112
/*
    var surface = window.get_surface();
    var x11_surface = surface as Gdk.X11.Surface;
    if (x11_surface != null)
      return "x11:%x".printf((uint)x11_surface.get_xid());
*/
#endif
    // TODO: support wayland windows too
    return "";
  }

  public static async bool request_autostart(Gtk.Widget widget)
  {
    var window = widget.get_root() as Gtk.Window;

    string? mitigation;
    var install_env = DejaDup.InstallEnv.instance();
    var allowed = yield install_env.request_autostart(get_window_handle(window),
                                                      out mitigation);

    if (!allowed && mitigation != null)
      DejaDup.run_error_dialog(window, _("Cannot back up automatically"),
                               mitigation);

    return allowed;
  }
}
