/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/ConfigAutoBackupRow.ui")]
public class ConfigAutoBackupRow : Adw.ActionRow
{
  Settings settings;
  construct {
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

  string today_message(bool periodic)
  {
    return periodic ?
      // Translators: this is used when automatic updates are enabled
      _("Next backup is today.") :
      // Translators: this is used when automatic updates are disabled
      _("Next backup would be today.");
  }

  string tomorrow_message(bool periodic)
  {
    return periodic ?
      // Translators: this is used when automatic updates are enabled
      _("Next backup is tomorrow.") :
      // Translators: this is used when automatic updates are disabled
      _("Next backup would be tomorrow.");
  }

  string future_message(int days, bool periodic)
  {
    if (periodic)
      // Translators: this is used when automatic updates are enabled
      return dngettext(Config.GETTEXT_PACKAGE,
                       "Next backup is %d day from now.",
                       "Next backup is %d days from now.", days).printf(days);
    else
      // Translators: this is used when automatic updates are disabled
      return dngettext(Config.GETTEXT_PACKAGE,
                       "Next backup would be %d day from now.",
                       "Next backup would be %d days from now.", days).printf(days);
  }

  string pretty_next_name(DateTime date, bool periodic)
  {
    var now = new DateTime.now_local();

    // If we're past due, just say today.
    if (now.compare(date) > 0)
      date = now;

    // Check for some really simple/common friendly names
    if (is_same_day(date, now))
      return today_message(periodic);
    else if (is_same_day(date, now.add_days(1)))
      return tomorrow_message(periodic);
    else {
      now = new DateTime.local(now.get_year(),
                               now.get_month(),
                               now.get_day_of_month(),
                               0, 0, 0.0);
      var diff = (int)(date.difference(now) / TimeSpan.DAY);
      return future_message(diff, periodic);
    }
  }

  void update_label()
  {
    var settings = DejaDup.get_settings();
    var periodic = settings.get_boolean(DejaDup.PERIODIC_KEY);
    var next = DejaDup.next_possible_run_date();
    subtitle = pretty_next_name(next, periodic);
  }
}
