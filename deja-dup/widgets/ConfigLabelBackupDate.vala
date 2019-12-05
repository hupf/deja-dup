/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Canonical Ltd
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public class ConfigLabelBackupDate : ConfigLabel
{
  public enum Kind {LAST, NEXT}
  public Kind kind {get; construct;}

  public ConfigLabelBackupDate(Kind kind)
  {
    Object(kind: kind);
  }

  construct {
    watch_key(DejaDup.LAST_BACKUP_KEY);
    if (kind == Kind.NEXT) {
      watch_key(DejaDup.PERIODIC_KEY);
      watch_key(DejaDup.PERIODIC_PERIOD_KEY);
    }
  }

  protected override void fill_box()
  {
    base.fill_box();
    label.use_markup = true;
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
      if (kind == Kind.NEXT && now.compare(date) > 0)
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
      if (kind == Kind.LAST && now.compare(date) < 0)
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

  protected void set_from_config_last()
  {
    var val = DejaDup.last_run_date(DejaDup.TimestampType.BACKUP);
    var time = new DateTime.from_iso8601(val, new TimeZone.utc());
    if (time == null)
      label.label = "<b>%s</b>".printf(_("No recent backups."));
    else
      label.label = "<b>%s</b>".printf(pretty_last_name(time));
  }

  protected void set_from_config_next()
  {
    var next = DejaDup.next_run_date();
    if (next == null)
      label.label = "<b>%s</b>".printf(_("No backup scheduled."));
    else
      label.label = "<b>%s</b>".printf(pretty_next_name(next));
  }

  protected override async void set_from_config()
  {
    if (kind == Kind.LAST)
      set_from_config_last();
    else
      set_from_config_next();
  }
}

}
