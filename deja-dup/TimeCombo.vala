/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/TimeCombo.ui")]
public class TimeCombo : Gtk.Box
{
  public string when { get; set; default = null; }

  public void register_operation(DejaDup.OperationStatus op)
  {
    clear();
    op.collection_dates.connect(fill_combo_with_dates);
  }

  public string get_active_text()
  {
    return combo.get_active_text();
  }

  public void clear()
  {
    store.clear();
    when = null;
  }

  [GtkChild]
  Gtk.ComboBoxText combo;
  Gtk.ListStore store;
  construct
  {
    store = new Gtk.ListStore(2, typeof(string), typeof(string));
    combo.model = store;
    combo.id_column = 1;
    combo.bind_property("active-id", this, "when");
  }

  static bool is_same_day(DateTime one, DateTime two)
  {
    return one.get_year() == two.get_year() &&
           one.get_day_of_year() == two.get_day_of_year();
  }

  void fill_combo_with_dates(DejaDup.OperationStatus op, List<string>? dates)
  {
    store.clear();
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
      Gtk.TreeIter iter;
      store.prepend(out iter);
      store.@set(iter, 0, user_str, 1, datetime.format_iso8601());
      if (i.next == null)
        combo.set_active_iter(iter);
    }
  }
}
