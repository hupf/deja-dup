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
  static async string export_handle(Gtk.Window window)
  {
    var surface = window.get_surface();
#if HAS_WAYLAND
    var wayland_surface = surface as Gdk.Wayland.Toplevel;
    if (wayland_surface != null) {
      var handle = "";
      var success = wayland_surface.export_handle((t, h) => {
        handle = h;
        export_handle.callback();
      });
      if (success) {
        yield;
        return "wayland:%s".printf(handle);
      }
    }
#endif
#if HAS_X11
    var x11_surface = surface as Gdk.X11.Surface;
    if (x11_surface != null)
      return "x11:%x".printf((uint)x11_surface.get_xid());
#endif
    return "";
  }

  static void unexport_handle(Gtk.Window window, string handle)
  {
    var surface = window.get_surface();
#if HAS_WAYLAND
    var wayland_surface = surface as Gdk.Wayland.Toplevel;
    if (wayland_surface != null)
      wayland_surface.drop_exported_handle(handle);
#endif
  }

  public static async bool request_autostart(Gtk.Window window)
  {
    string? mitigation;
    var install_env = DejaDup.InstallEnv.instance();
    var handle = yield export_handle(window);
    var allowed = yield install_env.request_autostart(handle, out mitigation);
    unexport_handle(window, handle);

    if (!allowed && mitigation != null)
      yield DejaDup.run_error_dialog(window, _("Cannot back up automatically"),
                                     mitigation);

    return allowed;
  }
}
