/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/Browser.ui")]
class Browser : Gtk.Grid
{
  public bool time_filled {get; private set;}
  public bool files_filled {get; private set;}
  public DejaDup.Operation operation {get; private set;}

  const ActionEntry[] ACTIONS = {
    {"select-all", select_all},
    {"go-up", go_up},
    {"search", activate_search},
  };

  [GtkChild]
  Gtk.SearchBar search_bar;
  [GtkChild]
  Gtk.SearchEntry search_entry;
  [GtkChild]
  Gtk.Stack view_stack;
  [GtkChild]
  Gtk.Stack overlay_stack;
  [GtkChild]
  Gtk.Label auth_label;
  [GtkChild]
  Gtk.Label error_label;
  [GtkChild]
  Gtk.Label pause_label;
  [GtkChild]
  Gtk.IconView icon_view;
  [GtkChild]
  Gtk.TreeView list_view;
  [GtkChild]
  Gtk.Button restore_button;
  [GtkChild]
  TimeCombo timecombo;

  DejaDupApp application;
  FileStore store;
  DejaDup.BackendWatcher watcher;
  string auth_url; // if null, auth button should start mount op vs oauth
  MountOperation mount_op; // normally null
  MainLoop passphrase_loop;
  unowned Gtk.ApplicationWindow app_window;
  unowned MainHeaderBar header;
  SimpleActionGroup action_group;

  construct
  {
    application = DejaDupApp.get_instance();
    store = new FileStore();

    // Set up actions
    action_group = new SimpleActionGroup();
    action_group.add_action_entries(ACTIONS, this);
    application.set_accels_for_action("restore.select-all", {"<Control>A"});
    application.set_accels_for_action("restore.go-up", {"<Alt>Left", "<Alt>Up"});
    application.set_accels_for_action("restore.search", {"<Control>F"});

    timecombo.notify["when"].connect(() => {
      if (time_filled)
        start_files_operation();
    });

    notify["operation"].connect(() => {
      if (operation != null) {
        switch_overlay_to_spinner();
      }
      passphrase_loop.quit();
    });

    application.operation_started.connect(() => {
      stop_operation(); // get out of way of a real backup/restore op
    });

    // Connect file store and icon view
    bind_property("files-filled", icon_view, "sensitive", BindingFlags.SYNC_CREATE);
    icon_view.model = store;
    icon_view.pixbuf_column = FileStore.Column.ICON;
    icon_view.text_column = FileStore.Column.FILENAME;
    icon_view.item_activated.connect((v, p) => {go_down(p);});

    // Manually tweak some aspects of the icon view (we should maybe switch to
    // a different widget like Gtk.FlowBox?)
    var cells = icon_view.get_cells();
    var pixbuf_renderer = cells.data as Gtk.CellRendererPixbuf;
    icon_view.set_attributes(pixbuf_renderer, "gicon", FileStore.Column.GICON);
    pixbuf_renderer.icon_size = Gtk.IconSize.LARGE;

    // Set up list view as well
    bind_property("files-filled", list_view, "sensitive", BindingFlags.SYNC_CREATE);
    list_view.row_activated.connect((v, p, c) => {go_down(p);});
    list_view.get_selection().changed.connect(selection_changed);

    // Connect various buttons

    var go_up_action = action_group.lookup_action("go-up");
    store.bind_property("can-go-up", go_up_action, "enabled", BindingFlags.SYNC_CREATE);

    var select_all_action = action_group.lookup_action("select-all");
    bind_property("files-filled", select_all_action, "enabled", BindingFlags.SYNC_CREATE);

    search_entry.search_changed.connect(update_search_filter);

    // Watch for backend changes that need to reset us
    watcher = new DejaDup.BackendWatcher();
    watcher.changed.connect(clear_operation);
    watcher.new_backup.connect(clear_operation);
    application.notify["custom-backend"].connect(clear_operation);

    // Set up passphrase loop
    passphrase_loop = new MainLoop(null); // not started yet, but will be
    overlay_stack.notify["visible-child-name"].connect(() => {
      if (overlay_stack.visible_child_name != "passphrase")
        passphrase_loop.quit();
    });
  }

  public void bind_to_window(MainWindow win)
  {
    app_window = win;
    app_window.notify["is-active"].connect(maybe_start_operation);

    header = win.get_header();
    header.bind_search_bar(search_bar);
    bind_property("files-filled", header, "actions-sensitive",
                  BindingFlags.SYNC_CREATE);

    // Notice when we are switched to and away from and notice when we need to
    // reset operation.
    header.stack.notify["visible-child"].connect(() => {
      if (header.stack.visible_child == this) {
        app_window.insert_action_group("restore", action_group);
        maybe_start_operation();
      } else {
        app_window.insert_action_group("restore", null);
      }
    });

    // Initial setup call
    selection_changed();
  }

  void selection_changed() {
    var count = get_selected_items().length();
    restore_button.sensitive = count > 0;
  }

  List<Gtk.TreePath> get_selected_items()
  {
    if (view_stack.visible_child_name == "icons") {
      return icon_view.get_selected_items();
    } else {
      return list_view.get_selection().get_selected_rows(null);
    }
  }

  void select_all() {
    if (view_stack.visible_child_name == "icons") {
      icon_view.select_all();
    } else {
      list_view.get_selection().select_all();
    }
  }

  void go_up() {
    store.go_up();
    search_bar.search_mode_enabled = false;
  }

  void go_down(Gtk.TreePath path) {
    store.go_down(path);
    search_bar.search_mode_enabled = false;
  }

  void activate_search() {
    search_bar.search_mode_enabled = true;
    search_entry.grab_focus();
  }

  void update_search_filter() {
    if (search_entry.text != "") {
      view_stack.visible_child_name = "list";
      icon_view.model = null;
      list_view.model = store;
    } else {
      view_stack.visible_child_name = "icons";
      list_view.model = null;
      icon_view.model = store;
    }

    store.search_filter = search_entry.text;
  }

  [GtkCallback]
  void grab_passphrase()
  {
    var dialog = new PassphraseDialog();
    dialog.transient_for = app_window;
    dialog.got_passphrase.connect((passphrase) => {
      if (operation != null) {
        operation.set_passphrase(passphrase);
        switch_overlay_to_spinner(); // quits loop too
      }
    });
    dialog.present();
  }

  void switch_overlay_to_spinner() {
    overlay_stack.visible_child_name = "spinner";
    overlay_stack.visible = true;
  }

  void switch_overlay_to_error(string msg) {
    error_label.label = msg;

    overlay_stack.visible_child_name = "error";
    overlay_stack.visible = true;
  }

  void switch_overlay_to_pause(string msg) {
    pause_label.label = msg;

    overlay_stack.visible_child_name = "pause";
    overlay_stack.visible = true;
  }

  void switch_overlay_to_mount_needed() {
    overlay_stack.visible_child_name = "auth";
    overlay_stack.visible = true;

    auth_label.label = _("Authentication needed");
    auth_url = null;

    // disconnect error handler, or else we'll switch to that instead when
    // the operation inevitably fails
    operation.raise_error.disconnect(handle_operation_error);
  }

  void switch_overlay_to_oauth_needed(string msg, string url) {
    overlay_stack.visible_child_name = "auth";
    overlay_stack.visible = true;

    auth_label.label = msg;
    auth_url = url;
  }

  void switch_overlay_to_passphrase() {
    overlay_stack.visible_child_name = "passphrase";
    overlay_stack.visible = true;

    // Now this signal (passphrase_required) has unfortunate semantics. We need
    // to keep a main loop open until we get the operation its passphrase.
    passphrase_loop.run();
  }

  void switch_overlay_off() {
    overlay_stack.visible = false;
  }

  [GtkCallback]
  void start_auth() {
    if (auth_url == null) {
      mount_op = new Gtk.MountOperation(app_window);
      maybe_start_operation();
    } else {
      Gtk.show_uri(app_window, auth_url, Gdk.CURRENT_TIME);
    }
  }

  [GtkCallback]
  void start_restore()
  {
    List<File> files = null;
    var treepaths = get_selected_items();
    foreach (var treepath in treepaths) {
      var file = store.get_file(treepath);
      if (file != null)
        files.append(file);
    }
    application.restore_files(files, timecombo.when, store.tree);
  }

  void handle_operation_error(DejaDup.Operation op, string error, string? detail)
  {
    // don't show detail -- it's usually a large stacktrace or something
    switch_overlay_to_error(error);
  }

  void connect_and_begin_operation()
  {
    operation.backend.pause_op.connect((header, msg) => {
      // header && msg being null means unpause
      if (msg == null) {
        switch_overlay_to_spinner();
      } else {
        switch_overlay_to_pause(msg); // header isn't necessary
      }
    });

    operation.backend.show_oauth_consent_page.connect((msg, url) => {
      // msg && url being null means unpause
      if (url == null) {
        switch_overlay_to_spinner();
      } else {
        switch_overlay_to_oauth_needed(msg, url);
      }
    });

    operation.passphrase_required.connect(switch_overlay_to_passphrase);

    operation.backend.needed_mount_op.connect(switch_overlay_to_mount_needed);
    operation.backend.mount_op = mount_op;
    mount_op = null;

    operation.raise_error.connect(handle_operation_error);
    operation.start.begin();
  }

  void start_time_operation()
  {
    stop_operation();
    time_filled = false;

    var backend = application.get_restore_backend();
    operation = new DejaDup.OperationStatus(backend);
    operation.done.connect((op, success, cancelled, detail) => {
      if (op != operation)
        return;
      operation = null;
      if (success) {
        time_filled = true;
        start_files_operation();
      }
    });
    timecombo.register_operation(operation as DejaDup.OperationStatus);
    connect_and_begin_operation();
  }

  void start_files_operation()
  {
    stop_operation();
    files_filled = false;

    var backend = application.get_restore_backend();
    var datetime = new DateTime.from_iso8601(timecombo.when, new TimeZone.utc());
    operation = new DejaDup.OperationFiles(backend, datetime);
    operation.done.connect((op, success, cancelled, detail) => {
      if (op != operation)
        return;
      operation = null;
      if (success) {
        files_filled = true;
        switch_overlay_off();
      }
    });
    store.register_operation(operation as DejaDup.OperationFiles);
    connect_and_begin_operation();
  }

  void clear_operation()
  {
    stop_operation();
    time_filled = false;
    files_filled = false;
    store.clear();
    timecombo.clear();

    maybe_start_operation();
  }

  bool app_window_is_active()
  {
    if (!app_window.is_active)
      return false;

    var windows = Gtk.Window.list_toplevels();
    foreach (var window in windows) {
      if (window.visible && window != app_window)
        return false;
    }

    return true;
  }

  [GtkCallback]
  void maybe_start_operation()
  {
    if (operation != null)
      return;

    if (!app_window_is_active() || header.stack.visible_child != this)
      return;

    if (!time_filled)
      start_time_operation();
    else if (!files_filled)
      start_files_operation();
  }

  void stop_operation()
  {
    if (operation == null)
      return;

    operation.cancel();
    operation = null;
  }
}
