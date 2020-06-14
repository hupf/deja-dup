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

  protected List<File> _restore_files;
  public List<File> restore_files {
    get {
      return this._restore_files;
    }
    set {
      this._restore_files = value.copy_deep ((CopyFunc) Object.ref);
    }
  }

  public AssistantRestore.with_files(List<File> files, string? when = null)
  {
    // This puts the restore dialog into 'known file mode', where it only
    // restores the listed files, not the whole backup
    Object(restore_files: files, when: when);
  }

  protected DejaDup.OperationStatus query_op;
  protected DejaDup.Operation.State op_state;
  Gtk.ProgressBar query_progress_bar;
  uint query_timeout_id;
  Gtk.ComboBoxText date_combo;
  Gtk.ListStore date_store;
  Gtk.Box cust_box;
  Gtk.FileChooserButton cust_button;
  Gtk.Grid confirm_table;
  ConfigLocationGrid location_grid;
  Gtk.Widget config_location;
  Gtk.Image confirm_storage_image;
  Gtk.Label confirm_storage_label;
  Gtk.Label confirm_location_label;
  Gtk.Label confirm_location;
  Gtk.Label confirm_date_label;
  Gtk.Label confirm_date;
  Gtk.Label confirm_files_label;
  Gtk.Grid confirm_files;
  Gtk.Widget query_progress_page;
  Gtk.Widget date_page;
  Gtk.Widget restore_dest_page;
  bool got_dates;
  bool show_confirm_page = true;
  construct
  {
    default_title = _("Restore");
  }

  protected override string get_apply_text() {
    return _("_Restore");
  }

  protected override void add_setup_pages()
  {
    if (when == null) {
      add_query_backend_page();
      add_date_page();
    } else {
      // if we have a date, we only show one page before the confirm, so there
      // is very little to confirm, not worth it.
      show_confirm_page = false;
    }
    add_restore_dest_page();
  }

  void ensure_config_location()
  {
    if (config_location == null) {
      var builder = new Builder("preferences");
      location_grid = new ConfigLocationGrid(builder, true);

      var location_label = builder.get_object("location_label") as Gtk.Label;
      location_label.label = _("_Backup location");

      config_location = builder.get_object("location_grid") as Gtk.Widget;
      config_location.ref();
      config_location.parent.remove(config_location);
    }
  }

  Gtk.Widget make_backup_location_page()
  {
    ensure_config_location();
    config_location.show_all();
    return config_location;
  }

  protected override void add_custom_config_pages()
  {
    // always show for a full restore or if user hasn't ever used us
    if (restore_files == null || !DejaDup.has_seen_settings()) {
      var page = make_backup_location_page();
      append_page(page);
      set_page_title(page, _("Restore From Where?"));
    }
  }

  Gtk.Widget make_query_backend_page()
  {
    query_progress_bar = new Gtk.ProgressBar();

    var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
    page.border_width = 12;
    page.add(query_progress_bar);

    return page;
  }

  Gtk.Widget make_date_page()
  {
    date_store = new Gtk.ListStore(2, typeof(string), typeof(string));
    date_combo = new Gtk.ComboBoxText();
    date_combo.model = date_store;

    var date_label = new Gtk.Label(_("_Date"));
    date_label.set("mnemonic-widget", date_combo,
                   "use-underline", true,
                   "xalign", 1.0f);

    var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
    hbox.add(date_label);
    hbox.add(date_combo);

    var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
    page.border_width = 12;
    page.add(hbox);

    return page;
  }

  Gtk.Widget make_restore_dest_page()
  {
    var orig_radio = new Gtk.RadioButton(null);
    orig_radio.set("label", _("Restore files to _original locations"),
                   "use-underline", true);
    orig_radio.toggled.connect((r) => {
      if (r.active) {
        restore_location = "/";
        allow_forward(true);
      }
    });

    var cust_radio = new Gtk.RadioButton(null);
    cust_radio.set("label", _("Restore to _specific folder"),
                   "use-underline", true,
                   "group", orig_radio);
    cust_radio.toggled.connect((r) => {
      if (r.active) {
        restore_location = cust_button.get_filename();
        allow_forward(restore_location != null);
      }
      cust_box.sensitive = r.active;
    });

    cust_button =
      new Gtk.FileChooserButton(_("Choose destination for restored files"),
                                Gtk.FileChooserAction.SELECT_FOLDER);
    cust_button.selection_changed.connect((b) => {
      restore_location = b.get_filename();
      allow_forward(restore_location != null);
    });

    var cust_label = new Gtk.Label("    " + _("Restore _folder"));
    cust_label.set("mnemonic-widget", cust_button,
                   "use-underline", true,
                   "xalign", 1.0f);

    cust_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
    cust_box.sensitive = false;
    cust_box.add(cust_label);
    cust_box.add(cust_button);

    var page = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
    page.border_width = 12;
    page.add(orig_radio);
    page.add(cust_radio);
    page.add(cust_box);

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
    page.set("row-spacing", 6,
             "column-spacing", 12,
             "border-width", 12);

    ensure_config_location();
    label = new Gtk.Label(_("Backup location"));
    label.set("xalign", 1.0f, "yalign", 0.0f);
    confirm_storage_image = new Gtk.Image.from_icon_name("folder", Gtk.IconSize.MENU);
    confirm_storage_label = new Gtk.Label("");
    confirm_storage_label.xalign = 0;
    confirm_storage_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
    var grid = new Gtk.Grid();
    grid.column_spacing = 6;
    grid.hexpand = true;
    grid.add(confirm_storage_image);
    grid.add(confirm_storage_label);
    page.attach(label, 0, rows, 1, 1);
    page.attach(grid, 1, rows, 1, 1);
    ++rows;

    confirm_date_label = new Gtk.Label(_("Restore date"));
    confirm_date_label.set("xalign", 1.0f);
    confirm_date = new Gtk.Label("");
    confirm_date.set("xalign", 0.0f);
    page.attach(confirm_date_label, 0, rows, 1, 1);
    page.attach(confirm_date, 1, rows, 1, 1);
    ++rows;

    confirm_location_label = new Gtk.Label(_("Restore folder"));
    confirm_location_label.set("xalign", 1.0f);
    confirm_location = new Gtk.Label("");
    confirm_location.set("xalign", 0.0f);
    page.attach(confirm_location_label, 0, rows, 1, 1);
    page.attach(confirm_location, 1, rows, 1, 1);
    ++rows;

    confirm_files_label = new Gtk.Label("");
    confirm_files_label.set("xalign", 1.0f, "yalign", 0.0f);
    confirm_files = new Gtk.Grid();
    confirm_files.orientation = Gtk.Orientation.VERTICAL;
    confirm_files.row_spacing = 6;
    confirm_files.column_spacing = 6;
    confirm_files.row_homogeneous = true;
    page.attach(confirm_files_label, 0, rows, 1, 1);
    page.attach(confirm_files, 1, rows, 1, 1);
    ++rows;

    return page;
  }

  void add_query_backend_page()
  {
    var page = make_query_backend_page();
    append_page(page, Type.PROGRESS);
    set_page_title(page, _("Checking for Backups…"));
    query_progress_page = page;
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

  protected override DejaDup.Operation? create_op()
  {
    string date = null;
    if (when != null) {
      date = when;
    } else if (got_dates) {
      Gtk.TreeIter iter;
      if (date_combo.get_active_iter(out iter))
        date_store.get(iter, 1, out date);
    }

    realize();

    // Convert any specified files to a de-symlink-ified version, in case the
    // user is sitting inside a symlinked folder.
    var resolved_files = new GLib.List<File>();
    foreach (File f in restore_files) {
      resolved_files.append(DejaDup.try_realfile(f));
    }

    ensure_config_location();
    var rest_op = new DejaDup.OperationRestore(location_grid.get_backend(),
                                               restore_location, date,
                                               resolved_files);
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

  protected virtual void handle_collection_dates(DejaDup.OperationStatus op, List<string>? dates)
  {
    got_dates = true;
    TimeCombo.fill_combo_with_dates(date_combo, dates);

    // If we didn't see any dates...  Must not be any backups on the backend
    if (date_store.iter_n_children(null) == 0)
      show_error(_("No backups to restore"), null);
  }

  protected virtual void query_finished(DejaDup.Operation op, bool success, bool cancelled, string? detail)
  {
    this.op_state = op.get_state();
    this.query_op = null;
    this.op = null;

    if (cancelled)
      do_close();
    else if (success)
      go_forward();
  }

  bool query_pulse()
  {
    query_progress_bar.pulse();
    return true;
  }

  protected async void do_query()
  {
    realize();

    ensure_config_location();
    query_op = new DejaDup.OperationStatus(location_grid.get_backend());
    op = query_op;

    connect_operation(query_op);
    query_op.done.connect(query_finished);
    query_op.collection_dates.connect(handle_collection_dates);

    yield op.start();
  }

  protected override void do_prepare(Assistant assist, Gtk.Widget page)
  {
    base.do_prepare(assist, page);

    if (query_timeout_id > 0) {
      Source.remove(query_timeout_id);
      query_timeout_id = 0;
    }

    if (page == date_page) {
      // Hmm, we never got a date from querying the backend, but we also
      // didn't hit an error (since we're about to show this page, and not
      // the summary/error page).  Skip the date portion, since the backend
      // must not be capable of giving us dates (duplicity < 0.5.04 couldn't).
      if (!got_dates)
        skip();
    }
    else if (page == confirm_page) {
      // When we restore from
      var backend = location_grid.get_backend();
      string desc = backend.get_location_pretty();
      Icon icon = backend.get_icon();
      confirm_storage_label.label = desc == null ? "" : desc;
      if (icon == null)
        confirm_storage_image.set_from_icon_name("folder", Gtk.IconSize.MENU);
      else
        confirm_storage_image.set_from_gicon(icon, Gtk.IconSize.MENU);

      if (got_dates) {
        confirm_date.label = date_combo.get_active_text();
        confirm_date_label.show();
        confirm_date.show();
      }
      else {
        confirm_date_label.hide();
        confirm_date.hide();
      }

      // Where we restore to
      if (restore_files == null) {
        if (restore_location == "/")
          confirm_location.label = _("Original location");
        else
          confirm_location.label = DejaDup.get_file_desc(File.new_for_path(restore_location));

        confirm_location_label.show();
        confirm_location.show();
        confirm_files_label.hide();
        confirm_files.hide();
      }
      else {
        confirm_files_label.label = dngettext(Config.GETTEXT_PACKAGE,
                                              "File to restore",
                                              "Files to restore",
                                              restore_files.length());

        confirm_files.foreach((w) => {DejaDup.destroy_widget(w);});
        foreach (File f in restore_files) {
          var parse_name = f.get_parse_name();
          var file_label = new Gtk.Label(Path.get_basename(parse_name));
          file_label.set_tooltip_text(parse_name);
          file_label.set("xalign", 0.0f);
          confirm_files.add(file_label);
        }

        confirm_location_label.hide();
        confirm_location.hide();
        confirm_files_label.show();
        confirm_files.show_all();
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
    else if (page == query_progress_page) {
      if (last_op_was_back)
        skip();
      else {
        query_progress_bar.fraction = 0;
        query_timeout_id = Timeout.add(250, query_pulse);
        if (query_op != null && query_op.needs_password) {
          // Operation is waiting for password
          provide_password.begin();
        }
        else if (query_op == null)
          do_query.begin();
      }
    }
  }

  protected override void do_close()
  {
    if (query_timeout_id > 0) {
      Source.remove(query_timeout_id);
      query_timeout_id = 0;
    }

    base.do_close();
  }
}
