/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/PassphraseDialog.ui")]
class PassphraseDialog : Adw.MessageDialog
{
  public signal void got_passphrase(string passphrase);

  [GtkChild]
  unowned Adw.PasswordEntryRow entry;
  [GtkChild]
  unowned SwitchRow remember;

  ~PassphraseDialog()
  {
    debug("Finalizing PassphraseDialog\n");
  }

  [GtkCallback]
  void response_cb(string response_id)
  {
    if (response_id == "continue" && entry.text != "")
      handle_ok.begin();
  }

  [GtkCallback]
  void entry_changed_cb()
  {
    set_response_enabled("continue", entry.text != "");
  }

  async void handle_ok()
  {
    var passphrase = DejaDup.process_passphrase(entry.text);
    yield DejaDup.store_passphrase(passphrase, remember.active);
    got_passphrase(passphrase);
  }
}
