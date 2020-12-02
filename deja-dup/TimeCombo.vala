/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class TimeCombo : BuilderWidget
{
  public string when { get; set; default = null; }

  public TimeCombo(Gtk.Builder builder)
  {
    Object(builder: builder);
  }

  public void register_operation(DejaDup.OperationStatus op)
  {
    clear();
    op.collection_dates.connect(handle_collection_dates);
  }

  public void clear()
  {
    date_store.clear();
    when = null;
  }

  Gtk.ListStore date_store;
  construct
  {
    adopt_name("restore-date-combo");

    date_store = new Gtk.ListStore(2, typeof(string), typeof(string));

    unowned var combo = get_object("restore-date-combo") as Gtk.ComboBox;
    combo.model = date_store;
    combo.id_column = 1;
    combo.bind_property("active-id", this, "when");
  }

  void handle_collection_dates(DejaDup.OperationStatus op, List<string>? dates)
  {
    unowned var combo = get_object("restore-date-combo") as Gtk.ComboBox;
    fill_combo_with_dates(combo, dates);
  }

  static bool is_same_day(DateTime one, DateTime two)
  {
    return one.get_year() == two.get_year() &&
           one.get_day_of_year() == two.get_day_of_year();
  }

  // Combo needs to have a Gtk.ListStore as the attached model.
  // That model will have two columns: a visible label (0) and an iso8601 string (1)
  // Designed to be used after handling a "collection_dates" signal.
  public static void fill_combo_with_dates(Gtk.ComboBox combo, List<string>? dates)
  {
    var store = combo.model as Gtk.ListStore;
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
