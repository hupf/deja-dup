/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Canonical Ltd
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class ConfigStatusLabel : Gtk.Box
{
  Gtk.Label status_label;
  Settings settings;
  construct {
    status_label = new Gtk.Label(null);
    status_label.halign = Gtk.Align.START;
    status_label.valign = Gtk.Align.CENTER;
    status_label.wrap = true;
    status_label.max_width_chars = 30;
    append(status_label);

    settings = DejaDup.get_settings();
    settings.changed[DejaDup.PERIODIC_KEY].connect(update_label);
    settings.changed[DejaDup.PERIODIC_PERIOD_KEY].connect(update_label);
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

  string pretty_next_name(DateTime date)
  {
    var now = new DateTime.now_local();

    // If we're past due, just say today.
    if (now.compare(date) > 0)
      date = now;

    // Check for some really simple/common friendly names
    if (is_same_day(date, now))
      return _("Next backup is today.");
    else if (is_same_day(date, now.add_days(1)))
      return _("Next backup is tomorrow.");
    else {
      now = new DateTime.local(now.get_year(),
                               now.get_month(),
                               now.get_day_of_month(),
                               0, 0, 0.0);
      var diff = (int)(date.difference(now) / TimeSpan.DAY);
      return dngettext(Config.GETTEXT_PACKAGE,
                       "Next backup is %d day from now.",
                       "Next backup is %d days from now.", diff).printf(diff);
    }
  }

  string pretty_last_name(DateTime date)
  {
    var now = new DateTime.now_local();

    // A last date in the future doesn't make any sense.
    // Pretending it happened today doesn't make any more sense, but at
    // least is intelligible.
    if (now.compare(date) < 0)
      date = now;

    // Check for some really simple/common friendly names
    if (is_same_day(date, now))
      return _("Last backup was today.");
    else if (is_same_day(date, now.add_days(-1)))
      return _("Last backup was yesterday.");
    else {
      now = new DateTime.local(now.get_year(),
                               now.get_month(),
                               now.get_day_of_month(),
                               0, 0, 0.0);
      var diff = (int)(now.difference(date) / TimeSpan.DAY + 1);
      return dngettext(Config.GETTEXT_PACKAGE,
                       "Last backup was %d day ago.",
                       "Last backup was %d days ago.", diff).printf(diff);
    }
  }

  void update_label()
  {
    string last_label;
    string next_label;

    var last = settings.get_string(DejaDup.LAST_BACKUP_KEY);
    var last_time = new DateTime.from_iso8601(last, new TimeZone.utc());
    if (last_time == null)
      last_label = _("No recent backups.");
    else
      last_label = pretty_last_name(last_time);

    var next = DejaDup.next_run_date();
    if (next == null)
      next_label = _("No backup scheduled.");
    else
      next_label = pretty_next_name(next);

    status_label.label = "%s\n%s".printf(last_label, next_label);
  }
}
