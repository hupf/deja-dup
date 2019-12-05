/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Canonical Ltd
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public void prompt(Gtk.Application app)
{
  DejaDup.update_prompt_time();
  show_prompt_notification(app);
}

string get_header()
{
  return _("Keep your files safe by backing up regularly");
}

string get_body()
{
  return _("Important documents, data, and settings can be protected by storing " +
           "them in a backup. In the case of a disaster, you would be able to recover " +
           "them from that backup.");
}

string get_cancel_button(bool mnemonics)
{
  var rv = _("_Don't Show Again");
  if (!mnemonics)
    rv = rv.replace("_", "");
  return rv;
}

string get_ok_button(bool mnemonics)
{
  var rv = _("_Open Backup Settings");
  if (!mnemonics)
    rv = rv.replace("_", "");
  return rv;
}

void show_prompt_notification(Gtk.Application app)
{
  var note = new Notification(get_header());
  note.set_body(get_body());
  note.set_icon(new ThemedIcon(Config.ICON_NAME));
  note.set_default_action("app.prompt-ok");
  note.add_button(get_cancel_button(false), "app.prompt-cancel");
  note.add_button(get_ok_button(false), "app.prompt-ok");
  app.send_notification("prompt", note);
}
