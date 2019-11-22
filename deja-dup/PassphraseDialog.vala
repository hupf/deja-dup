/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

class PassphraseDialog : BuilderWidget
{
  public signal void got_passphrase(string passphrase);

  public PassphraseDialog(Gtk.Builder builder)
  {
    Object(builder: builder);
  }

  construct {
    adopt_name("passphrase-dialog");

    var cancel = builder.get_object("passphrase-cancel") as Gtk.Button;
    cancel.clicked.connect(handle_cancel);

    var forward = builder.get_object("passphrase-forward") as Gtk.Button;
    forward.clicked.connect(() => {handle_forward.begin();});

    var show = builder.get_object("passphrase-show") as Gtk.CheckButton;
    var entry = builder.get_object("passphrase-entry") as Gtk.Entry;
    show.bind_property("active", entry, "visibility", BindingFlags.DEFAULT);

    entry.notify["text"].connect(() => {
      forward.sensitive = (entry.text != "");
    });
  }

  void handle_cancel() {
    var dialog = builder.get_object("passphrase-dialog") as Gtk.Dialog;
    dialog.hide();
  }

  async void handle_forward() {
    var dialog = builder.get_object("passphrase-dialog") as Gtk.Dialog;
    var entry = builder.get_object("passphrase-entry") as Gtk.Entry;
    var remember = builder.get_object("passphrase-remember") as Gtk.CheckButton;

    var passphrase = DejaDup.process_passphrase(entry.get_text());
    yield DejaDup.store_passphrase(passphrase, remember.active);

    got_passphrase(passphrase);

    dialog.hide();
  }
}
