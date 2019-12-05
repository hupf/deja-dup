/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public abstract class ConfigWidget : Gtk.EventBox
{
  public signal void changed();

  public Gtk.Widget mnemonic_widget {get; protected set;}
  public string key {get; construct;}
  public string ns {get; construct; default = "";}
  public FilteredSettings settings {get; construct;}

  protected bool syncing;
  List<FilteredSettings> all_settings;
  construct {
    visible_window = false;

    if (settings == null)
      settings = DejaDup.get_settings(ns);

    if (key != null)
      watch_key(key);

    mnemonic_activate.connect(on_mnemonic_activate);
  }

  ~ConfigWidget() {
    SignalHandler.disconnect_by_func(settings, (void*)key_changed_wrapper, this);
    foreach (weak FilteredSettings s in all_settings) {
      SignalHandler.disconnect_by_func(s, (void*)key_changed_wrapper, this);
      s.unref();
    }
  }

  protected void watch_key(string? key, FilteredSettings? s = null)
  {
    if (s == null) {
      s = settings;
    }
    else {
      s.ref();
      all_settings.prepend(s);
    }
    var signal_name = (key == null) ? "change-event" : "changed::%s".printf(key);
    Signal.connect_swapped(s, signal_name, (Callback)key_changed_wrapper, this);
  }

  static bool key_changed_wrapper(ConfigWidget w)
  {
    w.key_changed.begin();
    return false;
  }

  protected async void key_changed()
  {
    // Not great to just drop new notification on the floor when already
    // syncing, but we don't have a good cancellation method.
    if (syncing)
      return;

    syncing = true;
    yield set_from_config();
    changed();
    syncing = false;
  }

  protected abstract async void set_from_config();

  bool on_mnemonic_activate(Gtk.Widget w, bool g)
  {
    if (mnemonic_widget != null)
      return mnemonic_widget.mnemonic_activate(g);
    else
      return false;
  }
}

}
