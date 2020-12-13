/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Canonical Ltd
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

/**
 * This class can be used by backends in one of two ways:
 * 1) Traditional way, by having this ask the user for info and then sending
 *    a reply signal.
 * 2) Or by driving the authentication themselves in some secret way.  If so,
 *    they will ask for a button to be shown to start the authentication.
 *    When they are done, they will set the 'go_forward' property to true.
 *    This was used by the U1 backend.
 */

public class MountOperationAssistant : MountOperation
{
  public string label_help {get; set;}
  public string label_username {get; set; default = _("_Username");}
  public string label_password {get; set; default = _("_Password");}
  public string label_remember_password {get; set; default = _("_Remember password");}
  public bool go_forward {get; set; default = false;} // set by backends if they want to move on
  public bool retry_mode {get; set; default = false;} // skip any questions, send existing data back

  unowned AssistantOperation assist;
  Gtk.Box password_page;
  Gtk.Box layout;
  Gtk.Grid table;
  Gtk.CheckButton anonymous_w;
  Gtk.CheckButton remember_w;
  Gtk.Entry username_w;
  Gtk.Entry domain_w;
  Gtk.PasswordEntry password_w;
  MainLoop loop;

  public MountOperationAssistant(AssistantOperation assist)
  {
    this.assist = assist;
    assist.prepare.connect(do_prepare);
    assist.backward.connect(do_backward);
    assist.forward.connect(do_forward);
    assist.closing.connect(do_close);
    add_password_page();
  }

  construct {
    notify["go-forward"].connect(go_forward_changed);
  }

  void go_forward_changed()
  {
    if (go_forward)
      assist.go_forward();
  }

  public override void aborted()
  {
    assist.show_error(_("Location not available"), null);
  }

  public override void ask_password(string message, string default_user,
                                    string default_domain, AskPasswordFlags flags)
  {
    if (retry_mode) {
      reply(MountOperationResult.HANDLED);
      return;
    }

    flesh_out_password_page(message, default_user, default_domain, flags);
    assist.interrupt(password_page);
    loop = new MainLoop(null);
    check_valid_inputs();
    Notifications.attention_needed(assist, _("Backups needs your password to continue"));
    loop.run(); // enter new loop so that we don't return until user hits next
  }

  public override void ask_question(string message,
                                    [CCode (array_length = false)] string[] choices)
  {
    // Rather than implement this code right now (not sure if/when it's ever
    // called to mount something), we just outsource to normal GtkMountOp.
    var t = new Gtk.MountOperation(assist);
    t.reply.connect((t, r) => {
      choice = t.choice;
      send_reply(r);
    });
    loop = new MainLoop(null);
    t.ask_question(message, choices);
    loop.run(); // enter new loop so that we don't return until user hits next
  }

  void add_password_page()
  {
    var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
    assist.append_page(page, Assistant.Type.INTERRUPT);
    password_page = page;
  }

  void flesh_out_password_page(string message, string default_user,
                               string default_domain, AskPasswordFlags flags)
  {
    if (layout != null)
      password_page.remove(layout);

    layout = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);

    table = new Gtk.Grid();
    table.hexpand = true;
    table.vexpand = true;
    table.row_spacing = 6;
    table.column_spacing = 6;
    DejaDup.set_margins(table, 12);

    password_page.append(layout);

    int rows = 0;
    int ucol = 0;
    Gtk.Label label;

    assist.set_page_title(password_page, "");

    label = new Gtk.Label(message);
    label.xalign = 0.0f;
    label.wrap = true;
    label.max_width_chars = 25;
    layout.append(label);

    if (label_help != null) {
      label = new Gtk.Label(label_help);
      label.use_markup = true;
      label.xalign = 0;
      layout.append(label);
    }

    // Buffer
    label = new Gtk.Label("");
    layout.append(label);

    if ((flags & AskPasswordFlags.ANONYMOUS_SUPPORTED) != 0) {
      anonymous_w = new Gtk.CheckButton.with_mnemonic(_("Connect _anonymously"));
      anonymous_w.toggled.connect((b) => {check_valid_inputs();});
      layout.append(anonymous_w);

      var w = new Gtk.CheckButton.with_mnemonic(_("Connect as u_ser"));
      w.group = anonymous_w;
      anonymous_w.toggled.connect((b) => {
        table.sensitive = !b.active;
      });
      table.sensitive = false; // starts inactive
      layout.append(w);

      var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
      hbox.append(new Gtk.Label("    "));
      hbox.append(table);
      layout.append(hbox);

      ucol = 1;
    }
    else {
      anonymous_w = null;
      layout.append(table);
    }

    if ((flags & AskPasswordFlags.NEED_USERNAME) != 0) {
      username_w = new Gtk.Entry();
      username_w.set("activates-default", true,
                     "text", default_user);
      username_w.hexpand = true;
      username_w.changed.connect((e) => {check_valid_inputs();});
      label = new Gtk.Label(label_username);
      label.set("mnemonic-widget", username_w,
                "use-underline", true,
                "xalign", 1.0f);
      table.attach(label, ucol, rows, 1, 1);
      table.attach(username_w, ucol + 1, rows, 2 - ucol, 1);
      ++rows;
    }
    else
      username_w = null;

    if ((flags & AskPasswordFlags.NEED_DOMAIN) != 0) {
      domain_w = new Gtk.Entry();
      domain_w.set("activates-default", true,
                   "text", default_domain);
      domain_w.hexpand = true;
      domain_w.changed.connect((e) => {check_valid_inputs();});
      // Translators: this is a Windows networking domain
      label = new Gtk.Label(_("_Domain"));
      label.set("mnemonic-widget", domain_w,
                "use-underline", true,
                "xalign", 1.0f);
      table.attach(label, ucol, rows, 1, 1);
      table.attach(domain_w, ucol + 1, rows, 2 - ucol, 1);
      ++rows;
    }
    else
      domain_w = null;

    if ((flags & AskPasswordFlags.NEED_PASSWORD) != 0) {
      password_w = new Gtk.PasswordEntry();
      password_w.activates_default = true;
      password_w.show_peek_icon = true;
      password_w.hexpand = true;
      label = new Gtk.Label(label_password);
      label.set("mnemonic-widget", password_w,
                "use-underline", true,
                "xalign", 1.0f);
      table.attach(label, ucol, rows, 1, 1);
      table.attach(password_w, ucol + 1, rows, 2 - ucol, 1);
      ++rows;
    }
    else
      password_w = null;

    if ((flags & AskPasswordFlags.SAVING_SUPPORTED) != 0) {
      remember_w = new Gtk.CheckButton.with_mnemonic(label_remember_password);
      table.attach(remember_w, ucol + 1, rows, 2 - ucol, 1);
      ++rows;
    }
    else
      remember_w = null;
  }

  bool is_valid_entry(Gtk.Entry? e)
  {
    return e == null || (e.text != null && e.text != "");
  }

  bool is_anonymous()
  {
    return anonymous_w != null && anonymous_w.active;
  }

  void check_valid_inputs()
  {
    var valid = is_anonymous() ||
                (is_valid_entry(username_w) &&
                 is_valid_entry(domain_w));
    assist.allow_forward(valid);
  }

  void send_reply(MountOperationResult result)
  {
    if (loop != null) {
      loop.quit();
      loop = null;
      reply(result);
    }
  }

  void do_close(AssistantOperation op)
  {
    send_reply(MountOperationResult.ABORTED);
  }

  void do_backward(Assistant assist)
  {
    send_reply(MountOperationResult.ABORTED);
  }

  void do_forward(Assistant assist)
  {
  }

  void do_prepare(Assistant assist, Gtk.Widget page)
  {
    if (loop != null) {
      // This signal happens before a prepare, when going forward
      if (username_w != null) {
        var txt = username_w.get_text();
        username = txt.strip();
      }
      if (domain_w != null) {
        var txt = domain_w.get_text();
        domain = txt.strip();
      }
      if (password_w != null) {
        var txt = password_w.get_text();
        password = txt.strip();
      }
      if (anonymous_w != null)
        anonymous = anonymous_w.get_active();
      if (remember_w != null)
        password_save = remember_w.get_active() ? PasswordSave.PERMANENTLY : PasswordSave.NEVER;
      send_reply(MountOperationResult.HANDLED);
    }
  }
}
