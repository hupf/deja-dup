/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Canonical Ltd
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public void show_uri(Gtk.Window? parent, string link)
{
  try {
    Gtk.show_uri_on_window(parent, link, Gtk.get_current_event_time());
  } catch (Error e) {
    Gtk.MessageDialog dlg = new Gtk.MessageDialog(
      parent,
      Gtk.DialogFlags.DESTROY_WITH_PARENT | Gtk.DialogFlags.MODAL,
      Gtk.MessageType.ERROR,
      Gtk.ButtonsType.OK,
      _("Could not display %s"),
      link
    );
    dlg.format_secondary_text("%s", e.message);
    dlg.run();
    destroy_widget(dlg);
  }
}

bool user_focused(Gtk.Widget win, Gdk.EventFocus e)
{
  ((Gtk.Window)win).urgency_hint = false;
  win.focus_in_event.disconnect(user_focused);
  return false;
}

public void show_background_window_for_shell(Gtk.Window win)
{
  win.focus_on_map = false;
  win.urgency_hint = true;
  win.focus_in_event.connect(user_focused);
  win.show();
}

public void hide_background_window_for_shell(Gtk.Window win)
{
  win.hide();
}

public void destroy_widget(Gtk.Widget w)
{
  // We destroy in the idle loop for two reasons:
  // 1) Vala likes to unref local dialogs (like file choosers) after we call
  //    destroy, which is odd.  This avoids issues that arise from that.
  // 2) When running in accessiblity mode (as we do during test suites),
  //    GailButtons tend to do odd things with queued events during idle calls.
  //    This avoids destroying objects before gail is done with them, which led
  //    to crashes.
  w.hide();
  w.ref();
  Idle.add(() => {w.destroy(); return false;});
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

public bool gui_initialize(Gtk.Window? parent, bool show_error = true)
{
  string header;
  string msg;
  var rv = DejaDup.initialize(out header, out msg);

  if (rv) {
    var settings = get_settings();
    Signal.connect(settings, "changed::" + PERIODIC_KEY, (Callback)start_monitor_if_needed, null);
    start_monitor_if_needed(settings);
    // FIXME: ideally we'd do something more elegant than adding a ref and
    // leaking this settings, but we want it to stay around for the lifetime
    // of the app.
    settings.ref();
  }
  else if (show_error) {
    Gtk.MessageDialog dlg = new Gtk.MessageDialog (parent,
        Gtk.DialogFlags.DESTROY_WITH_PARENT | Gtk.DialogFlags.MODAL,
        Gtk.MessageType.ERROR,
        Gtk.ButtonsType.OK,
        "%s", header);
    dlg.format_secondary_text("%s", msg);
    dlg.run();
    destroy_widget(dlg);
  }

  return rv;
}

} // end namespace
