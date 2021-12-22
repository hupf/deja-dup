/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/TimeCombo.ui")]
public class TimeCombo : Gtk.Box
{
  public string when { get; private set; default = null; }

  public void register_operation(DejaDup.OperationStatus op)
  {
    clear();
    op.collection_dates.connect(fill_combo_with_dates);
  }

  public string get_active_text()
  {
    var item = (Item)combo.selected_item;
    return item == null ? null : item.label;
  }

  public void clear()
  {
    store.remove_all();
    when = null;
    visible = false;
  }

  [GtkChild]
  unowned Gtk.DropDown combo;

  ListStore store;
  construct
  {
    store = new ListStore(typeof(Item));
    combo.model = store;
    combo.notify["selected-item"].connect(update_when);
  }

  public class Item : Object {
    public string label {get; internal set;}
    public string tag {get; construct;}

    public Item(string label, string tag) {
      Object(label: label, tag: tag);
    }
  }

  void update_when() {
    var item = (Item)combo.selected_item;
    when = item == null ? null : item.tag;
  }

  static bool is_same_day(DateTime one, DateTime two)
  {
    return one.get_year() == two.get_year() &&
           one.get_day_of_year() == two.get_day_of_year();
  }

  void fill_combo_with_dates(DejaDup.OperationStatus op, Tree<DateTime, string> dates)
  {
    clear();
    if (dates.nnodes() == 0)
      return;

    DateTime prev_datetime = null;
    dates.foreach((datetime_utc, tag) => {
      var datetime = datetime_utc.to_local();

      var format = "%x";
      if (prev_datetime != null && is_same_day(prev_datetime, datetime)) {
        // Translators: %x is the current date, %X is the current time.
        // This will be in a list with other strings that just have %x (the
        // current date).  So make sure if you change this, it still makes
        // sense in that context.
        format = _("%x %X");

        // Replace previous item's label too (in case it was the first on this day)
        ((Item)store.get_item(0)).label = prev_datetime.format(format);
      }

      prev_datetime = datetime;
      var user_str = datetime.format(format);
      store.insert(0, new Item(user_str, tag));
      return false;
    });

    combo.selected = 0;
    visible = true;
  }
}
