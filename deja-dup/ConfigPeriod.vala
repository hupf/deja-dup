/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class ConfigPeriod : ConfigChoice
{
  public ConfigPeriod(Gtk.Builder builder) {
    Object(builder: builder);
  }

  construct {
    var row = builder.get_object(combo_name()) as Hdy.ComboRow;
    var settings = DejaDup.get_settings();
    settings.bind(DejaDup.PERIODIC_KEY,
                  row, "sensitive",
                  SettingsBindFlags.DEFAULT);
  }

  protected override void fill_store() {
    add_item(1, _("Daily"));
    add_item(7, _("Weekly"));
  }

  protected override string combo_name() {return "frequency";}

  protected override string setting_name() {return DejaDup.PERIODIC_PERIOD_KEY;}

  protected override string label_for_value(int val) {
    return dngettext(Config.GETTEXT_PACKAGE,
                     "Every %d day",
                     "Every %d days",
                     val).printf(val);
  }

  protected override int clamp_value(int val) {return int.max(1, val);}
}
