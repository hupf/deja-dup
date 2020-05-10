/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public abstract class ConfigChoice : BuilderWidget
{
  protected virtual void fill_store() {}
  protected abstract string combo_name();
  protected abstract string setting_name();
  protected abstract string label_for_value(int val);
  protected virtual int clamp_value(int val) {return val;}
  protected virtual int compare_value(int val) {return val;}

  protected uint add_item(int val, string label)
  {
    return store.insert_sorted(new Item(val, label), (a, b) => {
      return Item.cmp(compare_value(((Item)a).val), compare_value(((Item)b).val));
    });
  }

  ListStore store;

  construct {
    store = new ListStore(typeof(Item));
    fill_store();

    adopt_name(combo_name());
    var row = builder.get_object(combo_name()) as Hdy.ComboRow;
    row.bind_name_model(store, (item) => {return ((Item)item).label;});

    var settings = DejaDup.get_settings();
    settings.bind_with_mapping(setting_name(),
                               row, "selected-index",
                               SettingsBindFlags.DEFAULT,
                               get_mapping, set_mapping,
                               this.ref(), Object.unref);
  }

  class Item : Object
  {
    public int val {get; set;}
    public string label {get; set;}

    public Item(int val, string label) {
      Object(val: val, label: label);
    }

    public static bool equal(Object a, Object b) {
      return ((Item)a).val == ((Item)b).val;
    }

    public static int cmp(int a, int b)
    {
      if (a > b)
        return 1;
      if (a < b)
        return -1;
      return 0;
    }
  }

  static bool get_mapping(Value val, Variant variant, void *data)
  {
    var choice = (ConfigChoice)data;
    var store = choice.store;
    var clamped = choice.clamp_value(variant.get_int32());
    var needle = new Item(clamped, "");
    uint position;
    var found = store.find_with_equal_func(needle, (EqualFunc)Item.equal, out position);

    if (!found) {
      // User set a custom value in gsettings -- let's insert it into our model
      position = choice.add_item(clamped, choice.label_for_value(clamped));
    }

    val.set_int((int)position);
    return true;
  }

  static Variant set_mapping(Value val, VariantType expected_type, void *data)
  {
    var store = ((ConfigChoice)data).store;
    var item = store.get_item(val.get_int()) as Item;
    return new Variant.int32(item.val);
  }
}
