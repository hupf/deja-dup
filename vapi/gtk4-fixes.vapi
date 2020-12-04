/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

// This temporary vapi is to work around some bad vala bindings:
// https://gitlab.gnome.org/GNOME/vala/-/issues/1112

[CCode (cprefix = "Gdk", gir_namespace = "Gdk", gir_version = "4.0", lower_case_cprefix = "gdk_")]
namespace GdkFixes {
	namespace Wayland {
		[CCode (cheader_filename = "gdk/wayland/gdkwayland.h", type_id = "gdk_wayland_toplevel_get_type ()")]
		[GIR (name = "WaylandToplevel")]
		public class Toplevel : Gdk.Wayland.Surface, Gdk.Toplevel {
			public bool export_handle (owned Gdk.Wayland.ToplevelExported callback);
			public void unexport_handle ();
		}
	}
	namespace X11 {
		[CCode (cheader_filename = "gdk/x11/gdkx.h", type_id = "gdk_x11_surface_get_type ()")]
		[GIR (name = "X11Surface")]
		public class Surface : Gdk.Surface {
			public X.Window get_xid ();
		}
  }
}
