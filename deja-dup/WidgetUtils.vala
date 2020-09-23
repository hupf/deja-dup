/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Canonical Ltd
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public void run_error_dialog(Gtk.Window? parent, string header, string message)
{
  Gtk.MessageDialog dlg = new Gtk.MessageDialog(
    parent,
    Gtk.DialogFlags.DESTROY_WITH_PARENT | Gtk.DialogFlags.MODAL,
    Gtk.MessageType.ERROR,
    Gtk.ButtonsType.OK,
    "%s", header
  );
  dlg.format_secondary_text("%s", message);
  dlg.response.connect(dlg.destroy);
  dlg.present();
}

public Gtk.Builder make_builder(string name)
{
  var path = "/org/gnome/DejaDup%s/%s.ui".printf(Config.PROFILE, name);
  return new Gtk.Builder.from_resource(path);
}

// Convenience call that sets each side margin to the same value.
// Used as a porting aid from gtk3, to replace border-width.
public void set_margins(Gtk.Widget w, int margin)
{
  w.margin_start = margin;
  w.margin_end = margin;
  w.margin_top = margin;
  w.margin_bottom = margin;
}

bool start_monitor_if_needed(FilteredSettings settings)
{
  if (settings.get_boolean(PERIODIC_KEY)) {
    // Will quickly and harmlessly bail if it can't claim the bus name
    run_deja_dup({}, DejaDup.get_monitor_exec());
  }
  // Don't need to worry about else condition: the monitor will shut itself off
  // when periodic is disabled.
  return Source.CONTINUE;
}

public void gui_initialize()
{
  DejaDup.initialize();

  var settings = get_settings();
  Signal.connect(settings, "changed::" + PERIODIC_KEY, (Callback)start_monitor_if_needed, null);
  start_monitor_if_needed(settings);
  // FIXME: ideally we'd do something more elegant than adding a ref and
  // leaking this settings, but we want it to stay around for the lifetime
  // of the app.
  settings.ref();
}

} // end namespace
