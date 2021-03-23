/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/PreferencesWindow.ui")]
public class PreferencesWindow : Adw.PreferencesWindow
{
  [GtkChild]
  unowned Gtk.Label location_description;

  [GtkChild]
  unowned Adw.PreferencesPage labs_page;

#if ENABLE_RESTIC
  [GtkChild]
  unowned Adw.PreferencesGroup restic_group;
  [GtkChild]
  unowned Gtk.Label restic_description;
#endif

  DejaDup.BackendWatcher watcher;
  construct
  {
    watcher = new DejaDup.BackendWatcher();
    watcher.changed.connect(update_location_description);
    update_location_description();

#if ENABLE_RESTIC
    labs_page.visible = true;
    restic_group.visible = true;
    restic_description.set_markup(
      _("Restic is a another backup tool that can be used under the hood instead of Duplicity.") + " " +
      _("It is hoped that Restic will enable new features more easily in the future.") +
      "\n\n" +
      _("Please note that you must choose a new storage location, rather than convert an existing backup.") +
      "\n\n" +
      _("This is an experimental feature and may be removed at any time.") + " " +
      _("Use caution, but any testing you can manage is appreciated.") +
      "\n\n" +
      // Translators: the %s formatting is a link start and end.
      _("Please %sreport%s successes or failures when enabled.").printf(
        "<a href=\"https://gitlab.gnome.org/World/deja-dup/-/issues/192\">",
        "</a>"
      )
    );
#endif

    // AdwPreferencesWindow will still show a button for hidden pages,
    // so we remove the labs page entirely if it is hidden
    if (!labs_page.visible) {
      remove(labs_page);
    }
  }

  ~PreferencesWindow()
  {
    debug("Finalizing PreferencesWindow\n");
  }

  void update_location_description()
  {
    var backend = DejaDup.Backend.get_default();
    location_description.label = backend.get_location_pretty();
  }
}
