/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/RecentBackupRow.ui")]
public class RecentBackupRow : Adw.ActionRow
{
  [GtkChild]
  unowned Gtk.Label when;

  Settings settings;
  construct {
    settings = DejaDup.get_settings();
    settings.changed[DejaDup.LAST_BACKUP_KEY].connect(update_label);

    update_label();
  }

  bool is_same_day(DateTime one, DateTime two)
  {
    int ny, nm, nd, dy, dm, dd;
    one.get_ymd(out ny, out nm, out nd);
    two.get_ymd(out dy, out dm, out dd);
    return (ny == dy && nm == dm && nd == dd);
  }

  string pretty_last_name(DateTime date)
  {
    var now = new DateTime.now_utc();

    // A last date in the future doesn't make any sense.
    // Pretending it happened today doesn't make any more sense, but at
    // least is intelligible.
    if (now.compare(date) < 0)
      date = now;

    // Check for some really simple/common friendly names
    if (is_same_day(date, now))
      return _("Today");
    else if (is_same_day(date, now.add_days(-1)))
      return _("Yesterday");
    else {
      now = new DateTime.utc(now.get_year(),
                             now.get_month(),
                             now.get_day_of_month(),
                             0, 0, 0.0);
      var diff = (int)(now.difference(date) / TimeSpan.DAY + 1);
      // Translators: sentence case
      return dngettext(Config.GETTEXT_PACKAGE,
                       "%d day ago",
                       "%d days ago", diff).printf(diff);
    }
  }

  void update_label()
  {
    var last = settings.get_string(DejaDup.LAST_BACKUP_KEY);
    var last_time = new DateTime.from_iso8601(last, new TimeZone.utc());
    if (last_time == null)
      when.label = _("None");
    else
      when.label = pretty_last_name(last_time);
  }
}
