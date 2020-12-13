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
  Gtk.DropDown combo;

  ListStore store;
  construct
  {
    store = new ListStore(typeof(Item));
    combo.model = store;
    combo.notify["selected-item"].connect(update_when);
  }

  public class Item : Object {
    public string label {get; construct;}
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

  void fill_combo_with_dates(DejaDup.OperationStatus op, List<string>? dates)
  {
    clear();
    if (dates.length() == 0)
      return;

    var datetimes = new List<DateTime?>();
    foreach (var date in dates) {
      var datetime = new DateTime.from_iso8601(date, new TimeZone.utc());
      if (datetime != null) {
        datetimes.append(datetime);
      }
    }
    if (datetimes.length() == 0)
      return;

    for (unowned List<DateTime?>? i = datetimes; i != null; i = i.next) {
      var datetime = i.data;

      var format = "%x";
      if ((i.prev != null && is_same_day(i.prev.data, datetime)) ||
          (i.next != null && is_same_day(i.next.data, datetime))) {
        // Translators: %x is the current date, %X is the current time.
        // This will be in a list with other strings that just have %x (the
        // current date).  So make sure if you change this, it still makes
        // sense in that context.
        format = _("%x %X");
      }

      var user_str = datetime.to_local().format(format);
      store.insert(0, new Item(user_str, datetime.format_iso8601()));
    }

    combo.selected = 0;
    visible = true;
  }
}
