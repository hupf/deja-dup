/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public class ConfigChoice : ConfigWidget
{
  public signal void choice_changed(string val);

  protected Gtk.ComboBox combo;
  protected string default_val = null;
  construct {
    combo = new Gtk.ComboBoxText();
    add(combo);
  }

  // Subclasses use this to setup the choice list
  protected int settings_col;
  public void init(Gtk.TreeModel model, int settings_col)
  {
    combo.model = model;
    this.settings_col = settings_col;

    set_from_config.begin();
    combo.changed.connect(handle_changed);
  }

  public Value? get_current_value()
  {
    Gtk.TreeIter iter;
    if (combo.get_active_iter(out iter)) {
      Value val;
      combo.model.get_value(iter, settings_col, out val);
      return val;
    }
    return null;
  }

  protected virtual void handle_changed()
  {
    Value? val = get_current_value();
    string strval = val == null ? "" : val.get_string();

    settings.set_string(key, strval);

    choice_changed(strval);
  }

  protected override async void set_from_config()
  {
    string confval = settings.get_string(key);
    if (confval == null || confval == "")
      confval = default_val;
    if (confval == null)
      return;

    bool valid;
    Gtk.TreeIter iter;
    valid = combo.model.get_iter_first(out iter);

    while (valid) {
      Value val;
      combo.model.get_value(iter, settings_col, out val);
      string strval = val.get_string();

      if (strval == confval) {
        combo.set_active_iter(iter);
        break;
      }
      valid = combo.model.iter_next(ref iter);
    }
  }
}

}
