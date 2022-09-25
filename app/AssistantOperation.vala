/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Canonical Ltd
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public abstract class AssistantOperation : Assistant
{
  /*
   * Abstract class for implementation of various common pages in assistant
   *
   * Abstract class that provides various methods that serve as pages in
   * assistant. Required methods that all classes that inherit from this
   * class must implement are create_op, get_apply_text and
   * get_progress_file_prefix.
   *
   * Pages are shown in the following order:
   * 1. (Optional) Custom configuration pages
   * 2. Setup pages
   * 3. Confirmation page
   * 4. Password page
   * 5. Question page
   * 6. (Required) Progress page
   * 7. Summary
   */
  protected Gtk.Widget confirm_page {get; private set;}
  public signal void closing();

  protected Gtk.Widget backend_install_page {get; private set;}
  Gtk.Label backend_install_desc;
  Gtk.Label backend_install_packages;
  Gtk.ProgressBar backend_install_progress;

  Adw.PasswordEntryRow nag_entry;
  Adw.PasswordEntryRow encrypt_entry;
  Adw.PasswordEntryRow confirm_entry;
  SwitchRow encrypt_enabled;
  SwitchRow encrypt_remember;
  protected Gtk.Widget password_page {get; private set;}
  protected Gtk.Widget nag_page {get; private set;}
  protected bool nagged;
  List<Gtk.Widget> encryption_choice_widgets;
  List<Gtk.Widget> first_password_widgets;
  MainLoop password_ask_loop;

  Gtk.Label consent_label;
  string consent_url;
  protected Gtk.Grid consent_page {get; private set;}

  Gtk.Label question_label;
  protected Gtk.Widget question_page {get; private set;}

  Gtk.Label progress_label;
  Gtk.Label progress_file_label;
  Gtk.Label secondary_label;
  Gtk.ProgressBar progress_bar;
  Gtk.TextView progress_text;
  Gtk.ScrolledWindow progress_scroll;
  Gtk.Expander progress_expander;
  protected Gtk.Widget progress_page {get; private set;}

  protected Gtk.Label summary_label;
  protected Gtk.Widget detail_widget;
  Gtk.TextView detail_text_view;
  protected Gtk.Widget summary_page {get; private set;}

  protected DejaDup.Operation op;
  uint timeout_id;
  protected bool error_occurred {get; private set;}
  bool gives_progress;

  const int LOGS_LINES_TO_KEEP = 10000;
  bool adjustment_at_end = true;
  bool adjusting_text = false;

  construct
  {
    // This is a bit of a hack -- ideally we wouldn't rely on idle loop for this
    // sort of setup, but subclasses aren't ready to be called when we are
    // constructing ourselves. I need to properly refactor these classes.
    // But for now, just add everything next idle check.
    Idle.add(() => {
      add_custom_config_pages();
      add_backend_install_page();
      add_setup_pages();
      add_confirm_page();
      add_password_page();
      add_nag_page();
      add_consent_page();
      add_question_page();
      add_progress_page();
      add_summary_page();
      return false;
    });

    canceled.connect(do_cancel);
    closed.connect(do_delete);
    resumed.connect(do_delete);
    close_request.connect(() => {do_delete(); return true;});
    prepare.connect(do_prepare);
  }

  /*
   * Creates confirmation page for particular assistant
   *
   * Creates confirmation page that should create confirm_page widget that
   * is presented for final confirmation.
   */
  protected virtual Gtk.Widget? make_confirm_page() {return null;}
  protected virtual void add_setup_pages() {}
  protected virtual void add_custom_config_pages(){}
  /*
   * Creates and calls appropriate operation
   *
   * Creates and calls appropriate operation (Backup, Restore, Status, Files)
   * that is then used to perform various defined tasks on backend. It is
   * also later connected to various signals.
   */
  protected abstract async DejaDup.Operation? create_op();
  protected abstract string get_progress_file_prefix();

  protected abstract string get_apply_text();

  bool pulse()
  {
    if (!gives_progress)
      progress_bar.pulse();
    return true;
  }

  void show_progress(DejaDup.Operation op, double percent)
  {
    /*
     * Updates progress bar
     *
     * Updates progress bar with percent provided.
     */
    progress_bar.fraction = percent;
    gives_progress = true;
  }

  void set_progress_label(DejaDup.Operation op, string label)
  {
    progress_label.label = label;
    progress_file_label.label = "";
  }

  void set_progress_label_file(DejaDup.Operation op, File file, bool actual)
  {
    string prefix;
    if (actual) {
      prefix = get_progress_file_prefix();
      progress_label.label = prefix + " ";
      progress_file_label.label = DejaDup.get_display_name(file);
    }
    else {
      prefix = _("Scanning:");
      progress_label.label = _("Scanning…");
      progress_file_label.label = "";
    }

    adjusting_text = true;

    string log_line = prefix + " " + file.get_parse_name();

    var buffer = progress_text.buffer;
    if (buffer.get_char_count() > 0)
      log_line = "\n" + log_line;

    Gtk.TextIter iter;
    buffer.get_end_iter(out iter);
    buffer.insert_text(ref iter, log_line, (int)log_line.length);

    if (buffer.get_line_count() >= LOGS_LINES_TO_KEEP && adjustment_at_end) {
      // If we're watching text scroll by, don't keep everything in memory
      Gtk.TextIter start, cutoff;
      buffer.get_start_iter(out start);
      buffer.get_iter_at_line(out cutoff, buffer.get_line_count() - LOGS_LINES_TO_KEEP);
      buffer.delete(ref start, ref cutoff);
    }

    maybe_autoscroll();
    adjusting_text = false;

    progress_expander.visible = true;
    progress_scroll.visible = true;
    progress_text.visible = true;
  }

  protected void set_secondary_label(string text)
  {
    if (text != null && text != "") {
      secondary_label.label = text;
      secondary_label.show();
    }
    else
      secondary_label.hide();
  }

  void maybe_autoscroll()
  {
    if (adjustment_at_end)
    {
      var adjust = progress_scroll.vadjustment;
      adjust.value = adjust.upper - adjust.page_size;
    }
  }

  void update_autoscroll()
  {
    if (adjusting_text)
      return;

    var adjust = progress_scroll.vadjustment;
    adjustment_at_end = adjust.value >= adjust.upper - adjust.page_size * 2 ||
                        adjust.page_size == 0 || // unset, i.e. not realized
                        !progress_expander.expanded;
  }

  protected virtual Gtk.Widget make_progress_page()
  {
    var page = new Gtk.Grid();
    page.orientation = Gtk.Orientation.VERTICAL;
    page.row_spacing = 6;

    int row = 0;

    progress_label = new Gtk.Label("");
    progress_label.xalign = 0.0f;

    progress_file_label = new Gtk.Label("");
    progress_file_label.xalign = 0.0f;
    progress_file_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
    progress_file_label.hexpand = true;

    page.attach(progress_label, 0, row, 1, 1);
    page.attach(progress_file_label, 1, row, 1, 1);
    ++row;

    secondary_label = new Gtk.Label("");
    secondary_label.xalign = 0.0f;
    secondary_label.wrap = true;
    secondary_label.max_width_chars = 30;
    secondary_label.visible = false;
    page.attach(secondary_label, 0, row, 2, 1);
    ++row;

    progress_bar = new Gtk.ProgressBar();
    page.attach(progress_bar, 0, row, 2, 1);
    ++row;

    progress_text = new Gtk.TextView();
    progress_text.editable = false;
    progress_scroll = new Gtk.ScrolledWindow();
    progress_scroll.vadjustment.value_changed.connect(update_autoscroll);
    progress_scroll.hexpand = true;
    progress_scroll.vexpand = true;
    progress_scroll.hscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
    progress_scroll.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
    progress_scroll.min_content_height = 200;
    progress_scroll.child = progress_text;
    progress_expander = new Gtk.Expander.with_mnemonic(_("_Details"));
    progress_expander.hexpand = true;
    progress_expander.vexpand = true;
    progress_expander.visible = false;
    progress_expander.child = progress_scroll;
    progress_scroll.notify["expanded"].connect(update_autoscroll);
    page.attach(progress_expander, 0, row, 2, 1);
    ++row;

    DejaDup.set_margins(page, 12);

    // Reserve space for details + labels
    page.set_size_request(-1, 200);

    return page;
  }

  void show_detail(string detail)
  {
    page_box.set_size_request(300, 200);
    detail_widget.visible = true;
    detail_text_view.buffer.set_text(detail, -1);
  }

  public virtual void show_error(string error, string? detail)
  {
    error_occurred = true;

    summary_label.label = error;
    summary_label.selectable = true;

    if (detail != null)
      show_detail(detail);

    go_to_page(summary_page);
    page_box.queue_resize();
  }

  protected Gtk.Widget make_backend_install_page()
  {
    int rows = 0;
    Gtk.Label l;

    var page = new Gtk.Grid();
    page.row_spacing = 6;
    DejaDup.set_margins(page, 12);

    l = new Gtk.Label(_("In order to continue, the following packages need to be installed:"));
    l.xalign = 0.0f;
    l.max_width_chars = 35;
    l.wrap = true;
    page.attach(l, 0, rows++, 1, 1);
    backend_install_desc = l;

    l = new Gtk.Label("");
    l.halign = Gtk.Align.START;
    l.max_width_chars = 35;
    l.wrap = true;
    l.margin_start = 12;
    l.use_markup = true;
    page.attach(l, 0, rows++, 1, 1);
    backend_install_packages = l;

    backend_install_progress = new Gtk.ProgressBar();
    backend_install_progress.visible = false;
    backend_install_progress.hexpand = true;
    page.attach(backend_install_progress, 0, rows++, 1, 1);

    return page;
  }

  protected Gtk.Widget make_password_page()
  {
    var page = new Adw.Clamp();
    DejaDup.set_margins(page, 12);

    var group = new Adw.PreferencesGroup();
    page.child = group;

    encrypt_enabled = new SwitchRow();
    encrypt_enabled.active = true; // always default to encrypted
    encrypt_enabled.subtitle = _("You will need your password to restore your files. You might want to write it down.");
    encrypt_enabled.title = _("_Password-protect your backup");
    encrypt_enabled.notify["active"].connect(check_password_validity);
    group.add(encrypt_enabled);
    encryption_choice_widgets.append(encrypt_enabled);

    encrypt_entry = new Adw.PasswordEntryRow();
    DejaDup.configure_entry_row(encrypt_entry, true);
    encrypt_entry.title = _("E_ncryption password");
    encrypt_entry.changed.connect(check_password_validity);
    encrypt_enabled.bind_property("active", encrypt_entry, "sensitive", BindingFlags.SYNC_CREATE);
    group.add(encrypt_entry);

    // Add a confirmation entry if this is user's first time
    confirm_entry = new Adw.PasswordEntryRow();
    DejaDup.configure_entry_row(confirm_entry, true);
    confirm_entry.title = _("Confir_m password");
    confirm_entry.changed.connect(check_password_validity);
    encrypt_enabled.bind_property("active", confirm_entry, "sensitive", BindingFlags.SYNC_CREATE);
    group.add(confirm_entry);
    first_password_widgets.append(confirm_entry);

    encrypt_remember = new SwitchRow();
    encrypt_remember.title = _("_Remember password");
    encrypt_enabled.bind_property("active", encrypt_remember, "sensitive", BindingFlags.SYNC_CREATE);
    group.add(encrypt_remember);

    return page;
  }

  protected Gtk.Widget make_nag_page()
  {
    var page = new Adw.Clamp();
    DejaDup.set_margins(page, 12);

    var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
    page.child = box;

    var label = new Gtk.Label(_("In order to check that you will be able to retrieve your files in the case " +
                                "of an emergency, please enter your encryption password again to perform a " +
                                "brief restore test."));
    label.wrap = true;
    label.xalign = 0;
    box.append(label);

    var group = new Adw.PreferencesGroup();
    box.append(group);

    nag_entry = new Adw.PasswordEntryRow();
    DejaDup.configure_entry_row(nag_entry, true);
    nag_entry.title =_("E_ncryption password");
    nag_entry.changed.connect(check_nag_validity);
    group.add(nag_entry);

    var nag_row = new SwitchRow();
    nag_row.active = true;
    nag_row.title = _("Test every two _months");
    nag_row.notify["active"].connect((row, spec) => {
      DejaDup.update_nag_time(!((SwitchRow)row).active);
    });
    group.add(nag_row);

    return page;
  }

  protected Gtk.Grid make_consent_page()
  {
    int rows = 0;

    var page = new Gtk.Grid();
    page.row_spacing = 36;
    page.column_spacing = 6;
    page.halign = Gtk.Align.CENTER;
    DejaDup.set_margins(page, 12);

    var l = new Gtk.Label("");
    l.xalign = 0.0f;
    l.max_width_chars = 35;
    l.wrap = true;
    page.attach(l, 0, rows, 3, 1);
    ++rows;
    consent_label = l;

    var b = new Gtk.Button.with_mnemonic(_("_Grant Access"));
    b.clicked.connect((button) => {
      Gtk.show_uri(button.root as Gtk.Window, consent_url, Gdk.CURRENT_TIME);
    });
    page.attach(b, 1, rows, 1, 1);
    ++rows;

    return page;
  }

  protected Gtk.Widget make_question_page()
  {
    int rows = 0;

    var page = new Gtk.Grid();
    page.row_spacing = 6;
    page.column_spacing = 6;
    DejaDup.set_margins(page, 12);

    var label = new Gtk.Label("");
    label.set("use-underline", true,
              "wrap", true,
              "max-width-chars", 25,
              "hexpand", true,
              "xalign", 0.0f);
    page.attach(label, 0, rows, 1, 1);
    ++rows;
    question_label = label;

    return page;
  }

  protected virtual Gtk.Widget make_summary_page()
  {
    summary_label = new Gtk.Label("");
    summary_label.xalign = 0.0f;
    summary_label.wrap = true;
    summary_label.max_width_chars = 25;

    detail_text_view = new Gtk.TextView();
    detail_text_view.editable = false;
    detail_text_view.wrap_mode = Gtk.WrapMode.WORD;
    detail_text_view.height_request = 150;

    var scroll = new Gtk.ScrolledWindow();
    scroll.child = detail_text_view;
    scroll.vexpand = true;
    scroll.visible = false; // only will be shown if an error occurs
    detail_widget = scroll;

    var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
    DejaDup.set_margins(page, 12);
    page.append(summary_label);
    page.append(detail_widget);

    return page;
  }

  void add_backend_install_page()
  {
    var page = make_backend_install_page();
    append_page(page, Type.INTERRUPT);
    set_page_title(page, _("Install Packages"));
    backend_install_page = page;
  }

  void add_confirm_page()
  {
    /*
     * Adds confirm page to the sequence of pages
     *
     * Adds confirm_page widget to the sequence of pages in assistant.
     */
    var page = make_confirm_page();
    if (page == null)
      return;
    append_page(page, Type.NORMAL, get_apply_text());
    set_page_title(page, _("Summary"));
    confirm_page = page;
  }

  void add_progress_page()
  {
    var page = make_progress_page();
    append_page(page, Type.PROGRESS);
    progress_page = page;
  }

  void add_password_page()
  {
    var page = make_password_page();
    append_page(page, Type.INTERRUPT);
    password_page = page;
  }

  void add_nag_page()
  {
    var page = make_nag_page();
    append_page(page, Type.CHECK);
    set_page_title(page, _("Restore Test"));
    nag_page = page;
  }

  void add_consent_page()
  {
    consent_page = make_consent_page();
    append_page(consent_page, Type.INTERRUPT);
    set_page_title(consent_page, _("Grant Access"));
  }

  void add_question_page()
  {
    var page = make_question_page();
    append_page(page, Type.INTERRUPT);
    question_page = page;
  }

  void add_summary_page()
  {
    var page = make_summary_page();
    append_page(page, Type.FINISH);
    summary_page = page;
  }

  protected virtual void apply_finished(DejaDup.Operation op, bool success, bool cancelled, string? detail)
  {
    this.op = null;

    if (cancelled) {
      do_close();
    }
    else if (success) {
      if (detail != null) {
        // Expect one paragraph followed by a blank line.  The first paragraph
        // is an explanation before the full detail content.  So split it out
        // into a proper label to look nice.
        var halves = detail.split("\n\n", 2);
        if (halves.length == 1) // no full detail content
          summary_label.label = detail;
        else if (halves.length == 2) {
          summary_label.label = halves[0];
          show_detail(halves[1]);
        }
      }

      go_to_page(summary_page);
    }
  }

  protected void show_oauth_consent_page(string? message, string? url)
  {
    consent_label.label = message;
    consent_url = url;
    if (url == null) {
      go_forward();
    } else {
      interrupt(consent_page, false);
    }
  }

  protected async void do_apply()
  {
    /*
     * Applies/starts operation that was configured during assistant process and
     * connect appropriate signals
     *
     * Mounts appropriate backend, creates child operation, connects signals to
     * handler functions and starts operation.
     */
    op = yield create_op();
    if (op == null)
      return;

    connect_operation(op);
    op.done.connect(apply_finished);
    op.action_desc_changed.connect(set_progress_label);
    op.action_file_changed.connect(set_progress_label_file);
    op.progress.connect(show_progress);

    op.start.begin();
  }

  protected void connect_operation(DejaDup.Operation operation)
  {
    operation.raise_error.connect((o, e, d) => {show_error(e, d);});
    operation.passphrase_required.connect(get_passphrase);
    operation.question.connect(show_question);
#if HAS_PACKAGEKIT
    operation.install.connect(show_install);
#endif
    operation.backend.mount_op = new MountOperationAssistant(this);
    operation.backend.pause_op.connect(pause_op);
    operation.backend.show_oauth_consent_page.connect(show_oauth_consent_page);
  }

  protected virtual void do_prepare(Assistant assist, Gtk.Widget page)
  {
    /*
     * Prepare page in assistant
     *
     * Prepares every page in assistant for various operations. For example, if
     * user returns to confirmation page from progress page, it is necessary
     * to kill running operation. If user advances to progress page, it runs
     * do_apply and runs the needed operation.
     *
     * do_prepare is run when user switches pages and not when pages are built.
     */

    if (timeout_id > 0) {
      Source.remove(timeout_id);
      timeout_id = 0;
    }

    if (page == confirm_page) {
      if (op != null) {
        op.done.disconnect(apply_finished);
        op.cancel(); // in case we just went back from progress page
        op = null;
      }
    }
    else if (page == progress_page) {
      progress_bar.fraction = 0;
      timeout_id = Timeout.add(250, pulse);
      if (op != null && op.needs_password) {
        // Operation is waiting for password
        provide_password.begin();
      }
      else if (op == null)
        do_apply.begin();
    }
  }

  // Make Deja Dup invisible, used when we are shutting down or some such.
  public void hide_everything()
  {
    hide();
    Notifications.close_all();
  }

  // Stop operation, does not need to be graceful - used to quickly stop as
  // we shut down.
  public void stop()
  {
    hide_everything();
    if (op != null)
      op.stop();
  }

  // Returns true if there's an operation running that shouldn't be cancelled at will
  // (used for example, if another backup wants to start and is checking if an
  // existing backup is running)
  public bool has_active_op()
  {
    return op != null && current != null && !is_interrupt_type(current.data.type);
  }

  protected virtual void do_cancel()
  {
    hide_everything();
    if (op != null) {
      op.cancel(); // do_close will happen in done() callback
    }
    else
      do_close();
  }

  protected void do_delete()
  {
    hide_everything();
    if (op != null)
      op.stop();
    else
      do_close();
  }

  protected virtual void do_close()
  {
    if (timeout_id > 0) {
      Source.remove(timeout_id);
      timeout_id = 0;
    }

    closing();
    destroy();
  }

  protected void get_passphrase()
  {
    ask_passphrase();
  }

  void check_password_validity()
  {
    if (!encrypt_enabled.active) {
      allow_forward(true);
      return;
    }

    var passphrase = encrypt_entry.get_text();
    var passphrase_entered = passphrase != "";

    if (confirm_entry.visible) {
      var passphrase2 = confirm_entry.text;
      var valid = (passphrase == passphrase2) && passphrase_entered;
      if (valid) {
        // The HIG recommends positive rather than negative feedback
        encrypt_entry.add_css_class("success");
        confirm_entry.add_css_class("success");
      } else {
        encrypt_entry.remove_css_class("success");
        confirm_entry.remove_css_class("success");
      }
      allow_forward(valid);
    }
    else
      allow_forward(passphrase_entered);
  }

  void configure_password_page(bool first)
  {
    if (first && DejaDup.get_tool().requires_encryption)
      set_page_title(password_page, _("Set Encryption Password"));
    else if (first)
      set_page_title(password_page, _("Require Password?"));
    else
      set_page_title(password_page, _("Encryption Password Needed"));

    foreach (Gtk.Widget w in encryption_choice_widgets)
      w.visible = first && !DejaDup.get_tool().requires_encryption;
    foreach (Gtk.Widget w in first_password_widgets)
      w.visible = first;

    check_password_validity();
    encrypt_entry.select_region(0, -1);
    encrypt_entry.grab_focus();
  }

  void check_nag_validity()
  {
    if (nag_entry.text == "")
      allow_forward(false);
    else
      allow_forward(true);
  }

  void configure_nag_page()
  {
    check_nag_validity();
    nag_entry.text = "";
    nag_entry.grab_focus();
  }

  void stop_password_loop()
  {
    password_ask_loop.quit();
    password_ask_loop = null;
    closing.disconnect(stop_password_loop);
  }

  protected void ask_passphrase(bool first = false)
  {
    op.needs_password = true;
    if (op.use_cached_password) {
      interrupt(password_page);
      configure_password_page(first);
    }
    else {
      // interrupt, but stay visible so user can see reassuring message at end
      interrupt(nag_page, true /* can_continue */, true /* stay_visible */);
      configure_nag_page();
      nagged = true;
    }
    Notifications.attention_needed(this, _("Backups needs your encryption password to continue"));
    // pause until we can provide password by entering new main loop
    password_ask_loop = new MainLoop(null);
    closing.connect(stop_password_loop);
    password_ask_loop.run();
  }

  protected async void provide_password()
  {
    var passphrase = "";

    if (op.use_cached_password) {
      if (encrypt_enabled.active) {
        passphrase = DejaDup.process_passphrase(encrypt_entry.get_text());
      }

      var remember = passphrase != "" && encrypt_remember.active;
      yield DejaDup.store_passphrase(passphrase, remember);
    }
    else {
      passphrase = DejaDup.process_passphrase(nag_entry.text);
    }

    op.set_passphrase(passphrase);
    stop_password_loop();
  }

  void show_question(DejaDup.Operation op, string title, string message)
  {
    set_page_title(question_page, title);
    question_label.label = message;
    interrupt(question_page);
    Notifications.attention_needed(this, _("Backups needs your input to continue"), title);
    var loop = new MainLoop(null);
    var closing_id = closing.connect(loop.quit);
    var forward_id = forward.connect(loop.quit);
    loop.run();
    disconnect(closing_id);
    disconnect(forward_id);
  }

#if HAS_PACKAGEKIT
  async void start_install(string[] package_ids, MainLoop loop)
  {
    backend_install_desc.hide();
    backend_install_packages.hide();
    backend_install_progress.show();

    try {
      var client = new Pk.Client();
      yield client.install_packages_async(0, package_ids, null, (p, t) => {
        backend_install_progress.fraction = (p.percentage / 100.0).clamp(0, 100);
      });
    }
    catch (Error e) {
      show_error("%s".printf(e.message), null);
      return;
    }

    go_forward();
    loop.quit();
  }

  protected void show_install(DejaDup.Operation op, string[] names, string[] ids)
  {
    var text = "";
    foreach (string s in names) {
      if (text != "")
        text += ", ";
      text += "<b>%s</b>".printf(s);
    }
    backend_install_packages.label = text;

    interrupt(backend_install_page, false);
    var install_button = add_button(C_("verb", "_Install"), CUSTOM_RESPONSE);
    make_button_default(install_button);
    var loop = new MainLoop(null);
    install_button.clicked.connect(() => {start_install.begin(ids, loop);});
    forward_button = install_button;
    Notifications.attention_needed(this, _("Backups needs to install packages to continue"));

    loop.run();
  }
#endif

  protected void pause_op(DejaDup.Backend back, string? header, string? msg)
  {
    // Basically a question without a response expected
    if (header == null) { // unpause
      Notifications.operation_unblocked();
      go_forward();
    }
    else {
      set_page_title(question_page, header);
      question_label.label = msg;
      interrupt(question_page, false);
      Notifications.operation_blocked(this, header, msg);
    }
  }
}
