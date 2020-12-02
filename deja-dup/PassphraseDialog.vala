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

    unowned var cancel = get_object("passphrase-cancel") as Gtk.Button;
    cancel.clicked.connect(handle_cancel);

    unowned var forward = get_object("passphrase-forward") as Gtk.Button;
    forward.clicked.connect(() => {handle_forward.begin();});

    unowned var entry = get_object("passphrase-entry") as Gtk.PasswordEntry;
    entry.notify["text"].connect(() => {
      forward.sensitive = (entry.text != "");
    });
  }

  void handle_cancel() {
    unowned var dialog = get_object("passphrase-dialog") as Gtk.Dialog;
    dialog.hide();
  }

  async void handle_forward() {
    unowned var dialog = get_object("passphrase-dialog") as Gtk.Dialog;
    unowned var entry = get_object("passphrase-entry") as Gtk.PasswordEntry;
    unowned var remember = get_object("passphrase-remember") as Gtk.CheckButton;

    var passphrase = DejaDup.process_passphrase(entry.text);
    yield DejaDup.store_passphrase(passphrase, remember.active);

    got_passphrase(passphrase);

    dialog.hide();
  }
}
