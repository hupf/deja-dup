/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/PassphraseDialog.ui")]
class PassphraseDialog : Gtk.Dialog
{
  public signal void got_passphrase(string passphrase);

  [GtkChild]
  Gtk.PasswordEntry entry;
  [GtkChild]
  Gtk.CheckButton remember;

  construct {
    use_header_bar = 1; // setting this in the ui file doesn't seem to work

    entry.changed.connect(() => {
      set_response_sensitive(Gtk.ResponseType.OK, entry.text != "");
    });
  }

  public override void response(int response_id)
  {
    if (response_id == Gtk.ResponseType.OK && entry.text != "")
      handle_ok.begin();
    destroy();
  }

  async void handle_ok()
  {
    var passphrase = DejaDup.process_passphrase(entry.text);
    yield DejaDup.store_passphrase(passphrase, remember.active);
    got_passphrase(passphrase);
  }
}
