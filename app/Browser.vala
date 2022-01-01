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
  unowned Gtk.SearchBar search_bar;
  [GtkChild]
  unowned Gtk.SearchEntry search_entry;
  [GtkChild]
  unowned Gtk.Stack view_stack;
  [GtkChild]
  unowned Gtk.Stack overlay_stack;
  [GtkChild]
  unowned Gtk.Label auth_label;
  [GtkChild]
  unowned Gtk.Label error_label;
  [GtkChild]
  unowned Gtk.Label pause_label;
  [GtkChild]
  unowned Gtk.GridView icon_view;
  [GtkChild]
  unowned Gtk.ColumnView list_view;
  [GtkChild]
  unowned Gtk.Button restore_button;
  [GtkChild]
  unowned TimeCombo timecombo;
  [GtkChild]
  unowned Gtk.Spinner spinner;

  DejaDupApp application;
  FileStore store;
  Gtk.MultiSelection selection;
  DejaDup.BackendWatcher watcher;
  string auth_url; // if null, auth button should start mount op vs oauth
  MountOperation mount_op; // normally null
  MainLoop passphrase_loop;
  string saved_passphrase; // most recent successful password
  unowned MainWindow app_window;
  unowned MainHeaderBar header;
  SimpleActionGroup action_group;

  construct
  {
    application = DejaDupApp.get_instance();

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

    // Set up store
    store = new FileStore();
    selection = new Gtk.MultiSelection(store);
    selection.selection_changed.connect(selection_changed);
    selection.items_changed.connect(items_changed);

    // Connect file store and views
    bind_property("files-filled", list_view, "sensitive", BindingFlags.SYNC_CREATE);
    bind_property("files-filled", icon_view, "sensitive", BindingFlags.SYNC_CREATE);
    icon_view.model = selection;
    icon_view.factory = new Gtk.BuilderListItemFactory.from_resource(
      null, "/org/gnome/DejaDup/BrowserGridItem.ui"
    );

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
    app_window.notify["visible"].connect(maybe_start_operation);

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
    var bitset = selection.get_selection();
    restore_button.sensitive = !bitset.is_empty();
  }

  void items_changed() {
    if (files_filled)
      update_content_view();
  }

  void select_all() {
    selection.select_all();
  }

  void folder_changed() {
    search_bar.search_mode_enabled = false;
    // selection-changed doesn't emit automatically on clear for some reason
    restore_button.sensitive = false;
  }

  void go_up() {
    if (store.go_up())
      folder_changed();
  }

  [GtkCallback]
  void go_down(uint position) {
    if (store.go_down(position))
      folder_changed();
  }

  void activate_search() {
    search_bar.search_mode_enabled = true;
    search_entry.grab_focus();
  }

  // Shows the right pane - search view, normal view, empty versions of either
  void update_content_view()
  {
    if (search_entry.text != "") {
      view_stack.visible_child_name = "list";
      icon_view.model = null;
      list_view.model = selection;

      if (selection.get_n_items() == 0) {
        switch_overlay_to_empty_search();
      } else {
        switch_overlay_off();
      }
    } else {
      view_stack.visible_child_name = "icons";
      list_view.model = null;
      icon_view.model = selection;

      if (selection.get_n_items() == 0) {
        switch_overlay_to_empty_folder();
      } else {
        switch_overlay_off();
      }
    }
  }

  void update_search_filter()
  {
    update_content_view();
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
    switch_overlay_to("spinner");
    spinner.spinning = true;
  }

  void switch_overlay_to_error(string msg) {
    error_label.label = msg;

    switch_overlay_to("error");
  }

  void switch_overlay_to_pause(string msg) {
    pause_label.label = msg;

    switch_overlay_to("pause");
  }

  void switch_overlay_to_mount_needed() {
    switch_overlay_to("auth");

    auth_label.label = _("Authentication needed");
    auth_url = null;

    // disconnect error handler, or else we'll switch to that instead when
    // the operation inevitably fails
    operation.raise_error.disconnect(handle_operation_error);
  }

  void switch_overlay_to_oauth_needed(string msg, string url) {
    switch_overlay_to("auth");

    auth_label.label = msg;
    auth_url = url;
  }

  void switch_overlay_to_passphrase() {
    switch_overlay_to("passphrase");

    // Now this signal (passphrase_required) has unfortunate semantics. We need
    // to keep a main loop open until we get the operation its passphrase.
    passphrase_loop.run();
  }

  void switch_overlay_to_empty_folder() {
    switch_overlay_to("empty-folder");
  }

  void switch_overlay_to_empty_search() {
    view_stack.visible_child_name = "icons";
    switch_overlay_to("empty-search");
  }

  void switch_overlay_to(string name) {
    overlay_stack.visible_child_name = name;
    overlay_stack.visible = true;
    spinner.spinning = false;
  }

  void switch_overlay_off() {
    overlay_stack.visible = false;
    spinner.spinning = false;
  }

  [GtkCallback]
  void start_auth() {
    if (auth_url == null) {
      retry_operation();
    } else {
      Gtk.show_uri(app_window, auth_url, Gdk.CURRENT_TIME);
    }
  }

  [GtkCallback]
  void start_restore()
  {
    var bitset = selection.get_selection();
    var iter = Gtk.BitsetIter();
    uint position;
    if (!iter.init_first(bitset, out position))
      return;

    List<File> files = null;
    files.append(store.get_file(position));
    while (iter.next(out position)) {
      files.append(store.get_file(position));
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

    operation.set_passphrase(saved_passphrase); // start with remembered password
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
        saved_passphrase = op.get_state().passphrase;
        if (timecombo.when == null) {
          switch_overlay_to_error(_("No backup files found"));
        } else {
          time_filled = true;
          start_files_operation();
        }
      }
    });
    timecombo.register_operation(operation as DejaDup.OperationStatus);
    connect_and_begin_operation();
  }

  void start_files_operation()
  {
    stop_operation();
    files_filled = false;
    folder_changed();

    var backend = application.get_restore_backend();
    operation = new DejaDup.OperationFiles(backend, timecombo.when);
    operation.done.connect((op, success, cancelled, detail) => {
      if (op != operation)
        return;
      operation = null;
      if (success) {
        saved_passphrase = op.get_state().passphrase;
        files_filled = true;
        update_content_view();
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
    if (!app_window.is_active || !app_window.visible)
      return false;

    if (app_window.get_modals() != null)
      return false;

    return true;
  }

  [GtkCallback]
  void retry_operation()
  {
    mount_op = new Gtk.MountOperation(app_window);
    maybe_start_operation();
  }

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
