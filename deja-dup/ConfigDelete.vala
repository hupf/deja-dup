/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class ConfigDelete : ConfigChoice
{
  public ConfigDelete(Gtk.Builder builder) {
    Object(builder: builder);
  }

  protected override void fill_store() {
    add_item(90, _("At least three months"));
    add_item(182, _("At least six months"));
    add_item(365, _("At least a year"));
    add_item(0, _("Forever"));
  }

  protected override string combo_name() {return "keep";}

  protected override string setting_name() {return DejaDup.DELETE_AFTER_KEY;}

  protected override string label_for_value(int val) {
    return dngettext(Config.GETTEXT_PACKAGE,
                     "At least %d day",
                     "At least %d days",
                     val).printf(val);
  }

  protected override int clamp_value(int val) {return int.max(0, val);}

  protected override int compare_value(int val) {return val == 0 ? int.MAX : val;}
}
