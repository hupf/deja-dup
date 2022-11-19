/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Canonical Ltd
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class AssistantRestore : AssistantOperation
{
  public string restore_location {get; protected set; default = "/";}
  public string when {get; protected set; default = null;}
  public DejaDup.FileTree tree {get; protected set; default = null;}

  protected List<File> _restore_files;
  public List<File> restore_files {
    get {
      return this._restore_files;
    }
    set {
      this._restore_files = value.copy_deep ((CopyFunc) Object.ref);
    }
  }

  public AssistantRestore.with_files(List<File> files, string? when = null,
                                     DejaDup.FileTree? tree = null)
  {
    // This puts the restore dialog into 'known file mode', where it only
    // restores the listed files, not the whole backup
    Object(restore_files: files, when: when, tree: tree);
  }

  protected DejaDup.Operation.State op_state;
  Gtk.ProgressBar files_progress_bar;
  uint files_timeout_id;
  Gtk.ProgressBar status_progress_bar;
  uint status_timeout_id;
  TimeCombo date_combo;
  Adw.EntryRow cust_entry_row;
  Gtk.Grid confirm_table;
  Gtk.Image confirm_storage_image;
  Gtk.Label confirm_storage_label;
  Gtk.Label confirm_location_label;
  Gtk.Label confirm_location;
  Gtk.Label confirm_date_label;
  Gtk.Label confirm_date;
  Gtk.Label confirm_files_label;
  Gtk.Box confirm_files;
  Gtk.Widget status_progress_page;
  Gtk.Widget date_page;
  Gtk.Widget restore_dest_page;
  Gtk.Grid bad_files_grid;
  Gtk.Label bad_files_label;
  Gtk.Widget files_progress_page;
  bool show_confirm_page = true;
  construct
  {
    default_title = _("Restore");
  }

  protected override string get_apply_text() {
    return _("_Restore");
  }

  DejaDup.Backend get_backend()
  {
    return DejaDupApp.get_instance().get_restore_backend();
  }

  protected override void add_setup_pages()
  {
    if (when == null) {
      add_status_query_page();
      add_date_page();
    } else {
      // if we have a date, we only show one page before the confirm, so there
      // is very little to confirm, not worth it.
      show_confirm_page = false;
    }
    if (tree == null)
      add_files_query_page();
    add_restore_dest_page();
  }

  Gtk.Widget make_status_query_page()
  {
    status_progress_bar = new Gtk.ProgressBar();

    var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
    DejaDup.set_margins(page, 12);
    page.append(status_progress_bar);

    return page;
  }

  Gtk.Widget make_date_page()
  {
    date_combo = new TimeCombo();

    var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
    DejaDup.set_margins(page, 12);
    page.append(date_combo);
    return page;
  }

  void allow_restore_location_forward(bool allowed)
  {
    allow_forward(allowed);
    if (allowed)
      cust_entry_row.remove_css_class("error");
    else
      cust_entry_row.add_css_class("error");
  }

  void restore_location_updated()
  {
    allow_restore_location_forward(restore_location != null);

    bad_files_grid.visible = false;
    if (restore_location == null || tree == null)
      return;

    bool all_bad;
    var bad_files = RestoreFileTester.get_bad_paths(restore_location, tree, out all_bad, restore_files);
    if (bad_files.length() > 0) {
      string label = null;
      bad_files.sort(strcmp);
      bad_files.@foreach((file) => {
        if (label == null)
          label = file;
        else
          label += "\n" + file;
      });
      bad_files_label.label = label;
      bad_files_grid.visible = true;

      if (restore_files != null || all_bad)
        allow_restore_location_forward(false); // on basis that they really want these specific files
    }
  }

  string? get_abs_path(string user_path)
  {
    if (user_path == "")
      return null;
    else if (!Path.is_absolute(user_path))
      return Path.build_filename(Environment.get_home_dir(), user_path);
    else
      return user_path;
  }

  Gtk.Widget make_restore_dest_page()
  {
    var orig_row = new Adw.ActionRow();
    var orig_radio = new Gtk.CheckButton();
    var cust_row = new Adw.ActionRow();
    var cust_radio = new Gtk.CheckButton();
    cust_entry_row = new Adw.EntryRow();
    var open_button = new FolderChooserButton();

    orig_row.title = _("Restore files to _original locations");
    orig_row.use_underline = true;
    orig_row.activatable_widget = orig_radio;
    orig_row.add_prefix(orig_radio);

    orig_radio.active = true;
    orig_radio.can_focus = false;
    orig_radio.toggled.connect((r) => {
      if (r.active) {
        restore_location = "/";
        restore_location_updated();
      }
    });

    cust_row.title = _("Restore to _specific folder");
    cust_row.use_underline = true;
    cust_row.activatable_widget = cust_radio;
    cust_row.add_prefix(cust_radio);

    cust_radio.group = orig_radio;
    cust_radio.can_focus = false;
    cust_radio.toggled.connect((r) => {
      if (r.active) {
        restore_location = get_abs_path(cust_entry_row.text);
        restore_location_updated();
      }
      cust_entry_row.sensitive = r.active;
    });

    cust_entry_row.title = _("_Folder");
    cust_entry_row.input_hints = Gtk.InputHints.NO_SPELLCHECK;
    cust_entry_row.sensitive = false;
    cust_entry_row.use_underline = true;
    cust_entry_row.activates_default = true;
    cust_entry_row.add_suffix(open_button);
    cust_entry_row.changed.connect(() => {
      restore_location = get_abs_path(cust_entry_row.text);
      restore_location_updated();
    });

    open_button.valign = Gtk.Align.CENTER;
    open_button.add_css_class("flat");
    open_button.file_selected.connect(() => {
      cust_entry_row.text = open_button.path;
    });

    var bad_icon = new Gtk.Image.from_icon_name("dialog-warning");
    bad_icon.valign = Gtk.Align.START;

    var bad_header = new Gtk.Label(_("Backups does not have permission to restore the following files:"));
    bad_header.xalign = 0;
    bad_header.yalign = 0;
    bad_header.valign = Gtk.Align.START;
    bad_header.hexpand = true;
    bad_header.wrap = true;
    bad_header.wrap_mode = Pango.WrapMode.WORD;

    bad_files_label = new Gtk.Label("");
    bad_files_label.xalign = 0;
    bad_files_label.yalign = 0;
    bad_files_label.valign = Gtk.Align.START;
    bad_files_label.ellipsize = Pango.EllipsizeMode.MIDDLE;

    bad_files_grid = new Gtk.Grid();
    bad_files_grid.margin_top = 12;
    bad_files_grid.margin_start = 6;
    bad_files_grid.column_spacing = 6;
    bad_files_grid.row_spacing = 6;
    bad_files_grid.hexpand = true;
    bad_files_grid.attach(bad_icon, 0, 0);
    bad_files_grid.attach(bad_header, 1, 0);
    bad_files_grid.attach(bad_files_label, 0, 1, 2, 1);

    var group = new Adw.PreferencesGroup();
    DejaDup.set_margins(group, 12);
    group.add(orig_row);
    group.add(cust_row);
    group.add(cust_entry_row);
    group.add(bad_files_grid);

    var scroll = new Gtk.ScrolledWindow();
    scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
    scroll.child = group;

    return scroll;
  }

  Gtk.Widget make_files_query_page()
  {
    files_progress_bar = new Gtk.ProgressBar();

    var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
    DejaDup.set_margins(page, 12);
    page.append(files_progress_bar);

    return page;
  }

  protected override Gtk.Widget? make_confirm_page()
  {
    if (!show_confirm_page)
      return null;

    int rows = 0;
    Gtk.Widget label;

    confirm_table = new Gtk.Grid();
    var page = confirm_table;
    page.row_spacing = 6;
    page.column_spacing = 6;
    DejaDup.set_margins(page, 12);

    label = new Gtk.Label(_("Backup location"));
    label.set("xalign", 1.0f, "yalign", 0.0f);
    confirm_storage_image = new Gtk.Image.from_icon_name("folder");
    confirm_storage_label = new Gtk.Label("");
    confirm_storage_label.xalign = 0;
    confirm_storage_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
    var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
    box.hexpand = true;
    box.append(confirm_storage_image);
    box.append(confirm_storage_label);
    page.attach(label, 0, rows, 1, 1);
    page.attach(box, 1, rows, 1, 1);
    ++rows;

    // Translators: label for the date from which we are restoring
    confirm_date_label = new Gtk.Label(_("Restore date"));
    confirm_date_label.set("xalign", 1.0f);
    confirm_date = new Gtk.Label("");
    confirm_date.set("xalign", 0.0f);
    page.attach(confirm_date_label, 0, rows, 1, 1);
    page.attach(confirm_date, 1, rows, 1, 1);
    ++rows;

    // Translators: label for the folder into which we putting restored files
    confirm_location_label = new Gtk.Label(_("Restore folder"));
    confirm_location_label.set("xalign", 1.0f);
    confirm_location = new Gtk.Label("");
    confirm_location.set("xalign", 0.0f);
    page.attach(confirm_location_label, 0, rows, 1, 1);
    page.attach(confirm_location, 1, rows, 1, 1);
    ++rows;

    confirm_files_label = new Gtk.Label("");
    confirm_files_label.set("xalign", 1.0f, "yalign", 0.0f);
    page.attach(confirm_files_label, 0, rows, 1, 1);
    ++rows;

    var scroll = new Gtk.ScrolledWindow();
    scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
    scroll.child = page;

    return scroll;
  }

  void add_status_query_page()
  {
    var page = make_status_query_page();
    append_page(page, Type.PROGRESS);
    set_page_title(page, _("Checking for Backups…"));
    status_progress_page = page;
  }

  void add_date_page()
  {
    var page = make_date_page();
    append_page(page);
    set_page_title(page, _("Restore From When?"));
    date_page = page;
  }

  void add_restore_dest_page()
  {
    var page = make_restore_dest_page();
    if (show_confirm_page)
      append_page(page);
    else
      append_page(page, Type.NORMAL, get_apply_text());
    set_page_title(page, _("Restore to Where?"));
    restore_dest_page = page;
  }

  void add_files_query_page()
  {
    files_progress_page = make_files_query_page();
    append_page(files_progress_page, Type.PROGRESS);
  }

  string get_tag()
  {
    if (when != null)
      return when;
    return date_combo.when;
  }

  protected override async DejaDup.Operation? create_op()
  {
    var backend = DejaDupApp.get_instance().get_restore_backend();
    var rest_op = new DejaDup.OperationRestore(backend, restore_location,
                                               tree, get_tag(),
                                               restore_files);
    if (this.op_state != null)
      rest_op.set_state(this.op_state);

    return rest_op;
  }

  protected override string get_progress_file_prefix()
  {
    // Translators:  This is the word 'Restoring' in the phrase
    // "Restoring '%s'".  %s is a filename.
    return _("Restoring:");
  }

  protected virtual void status_op_finished(DejaDup.Operation op, bool success, bool cancelled, string? detail)
  {
    this.op_state = op.get_state();
    this.op = null;

    if (cancelled)
      do_close();
    else if (success) {
      if (date_combo.when == null)
        show_error(_("No backups to restore"), null);
      else
        go_forward();
    }
  }

  bool status_pulse()
  {
    status_progress_bar.pulse();
    return true;
  }

  protected async void do_status_query()
  {
    var status_op = new DejaDup.OperationStatus(get_backend());
    op = status_op;

    connect_operation(status_op);
    status_op.done.connect(status_op_finished);
    date_combo.register_operation(status_op);

    yield op.start();
  }

  void handle_listed_current_files(DejaDup.OperationFiles op, DejaDup.FileTree tree)
  {
    this.tree = tree;
  }

  protected virtual void files_op_finished(DejaDup.Operation op, bool success, bool cancelled, string? detail)
  {
    this.op_state = op.get_state();
    this.op = null;

    if (cancelled)
      do_close();
    else if (success)
      go_forward();
  }

  bool files_pulse()
  {
    files_progress_bar.pulse();
    return true;
  }

  protected async void do_files_query()
  {
    var files_op = new DejaDup.OperationFiles(get_backend(), get_tag());
    if (this.op_state != null)
      files_op.set_state(this.op_state);
    op = files_op;

    connect_operation(files_op);
    files_op.done.connect(files_op_finished);
    files_op.listed_current_files.connect(handle_listed_current_files);

    yield op.start();
  }

  protected override void do_prepare(Assistant assist, Gtk.Widget page)
  {
    base.do_prepare(assist, page);
    stop_timers();

    if (page == confirm_page) {
      // When we restore from
      var backend = get_backend();
      string desc = backend.get_location_pretty();
      Icon icon = backend.get_icon();
      confirm_storage_label.label = desc == null ? "" : desc;
      if (icon == null)
        confirm_storage_image.set_from_icon_name("folder");
      else
        confirm_storage_image.set_from_gicon(icon);

      confirm_date.label = date_combo.get_active_text();
      confirm_date_label.show();
      confirm_date.show();

      // Where we restore to
      if (restore_files == null) {
        if (restore_location == "/")
          confirm_location.label = _("Original location");
        else
          confirm_location.label = DejaDup.get_file_desc(File.new_for_path(restore_location));

        confirm_location_label.visible = true;
        confirm_location.visible = true;
        confirm_files_label.visible = false;
        if (confirm_files != null) {
          confirm_table.remove(confirm_files);
          confirm_files = null;
        }
      }
      else {
        confirm_files_label.label = dngettext(Config.GETTEXT_PACKAGE,
                                              "File to restore",
                                              "Files to restore",
                                              restore_files.length());

        if (confirm_files != null)
          confirm_table.remove(confirm_files);
        confirm_files = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
        confirm_files.homogeneous = true;
        confirm_table.attach_next_to(confirm_files, confirm_files_label,
                                     Gtk.PositionType.RIGHT, 1, 1);
        foreach (File f in restore_files) {
          var parse_name = f.get_parse_name();
          var file_label = new Gtk.Label(Path.get_basename(parse_name));
          file_label.set_tooltip_text(parse_name);
          file_label.set("xalign", 0.0f);
          confirm_files.append(file_label);
        }

        confirm_location_label.visible = false;
        confirm_location.visible = false;
        confirm_files_label.visible = true;
      }
    }
    else if (page == summary_page) {
      if (error_occurred)
        set_page_title(page, _("Restore Failed"));
      else {
        set_page_title(page, _("Restore Finished"));
        if (!detail_widget.get_visible()) { // if it *is* visible, a header will be set already
          if (restore_files == null)
            summary_label.label = _("Your files were successfully restored.");
          else
            summary_label.label = dngettext(Config.GETTEXT_PACKAGE,
                                            "Your file was successfully restored.",
                                            "Your files were successfully restored.",
                                            restore_files.length());
        }
      }
    }
    else if (page == progress_page) {
      set_page_title(page, _("Restoring…"));
    }
    else if (page == status_progress_page) {
      if (last_op_was_back)
        skip();
      else {
        status_progress_bar.fraction = 0;
        status_timeout_id = Timeout.add(250, status_pulse);
        if (op != null && op.needs_password) {
          // Operation is waiting for password
          provide_password.begin();
        }
        else if (op == null)
          do_status_query.begin();
      }
    }
    else if (page == files_progress_page) {
      if (last_op_was_back)
        skip();
      else {
        files_progress_bar.fraction = 0;
        files_timeout_id = Timeout.add(250, files_pulse);
        if (op != null && op.needs_password) {
          // Operation is waiting for password
          provide_password.begin();
        }
        else if (op == null)
          do_files_query.begin();
      }
    }
  }

  protected override void set_buttons()
  {
    base.set_buttons();

    if (current.data.page == restore_dest_page) {
      restore_location_updated();
    }
  }

  protected override void do_close()
  {
    stop_timers();
    base.do_close();
  }

  void stop_timers()
  {
    if (status_timeout_id > 0) {
      Source.remove(status_timeout_id);
      status_timeout_id = 0;
    }
    if (files_timeout_id > 0) {
      Source.remove(files_timeout_id);
      files_timeout_id = 0;
    }
  }

  protected override void apply_finished(DejaDup.Operation op, bool success, bool cancelled, string? detail)
  {
    Notifications.restore_finished(this, success, cancelled, detail);
    base.apply_finished(op, success, cancelled, detail);
  }

  protected override uint inhibit(Gtk.Application app)
  {
    return app.inhibit(this,
                       Gtk.ApplicationInhibitFlags.LOGOUT |
                       Gtk.ApplicationInhibitFlags.SUSPEND,
                       _("Restore in progress"));
  }
}
