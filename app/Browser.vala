/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/Browser.ui")]
class Browser : Gtk.Grid
{
  public signal void folder_changed();

  public bool time_filled {get; private set;}
  public bool files_filled {get; private set;}
  public bool has_selection {get; private set;}
  public DejaDup.Operation operation {get; private set;}
  public bool can_go_up {get; protected set;}
  public string search_filter {get; set; default = "";}
  public bool is_visible_page {get; set; default = false;}

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
  unowned Gtk.Spinner spinner;

#if HAS_PACKAGEKIT
  [GtkChild]
  unowned Gtk.Label packagekit_label;
  string[] packagekit_ids;
#endif

  DejaDupApp application;
  FileStore store;
  Gtk.MultiSelection selection;
  string auth_url; // if null, auth button should start mount op vs oauth
  MountOperation mount_op; // normally null
  MainLoop passphrase_loop;
  string saved_passphrase; // most recent successful password
  unowned MainWindow app_window;
  unowned TimeCombo timecombo;
  bool operation_blocked = false;

  construct
  {
    application = DejaDupApp.get_instance();

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
    store.bind_property("can-go-up", this, "can-go-up", BindingFlags.SYNC_CREATE);
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

    // Connections
    notify["is-visible-page"].connect(maybe_start_operation);
    notify["search-filter"].connect(update_search_filter);
    // selection-changed doesn't emit automatically on clear for some reason
    notify["folder-changed"].connect(selection_changed);

    // Watch for backend changes that need to reset us
    var watcher = DejaDup.BackendWatcher.get_instance();
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

  public void bind_to_window(MainWindow win, TimeCombo combo)
  {
    app_window = win;
    app_window.notify["is-active"].connect(maybe_start_operation);
    app_window.notify["visible"].connect(maybe_start_operation);

    timecombo = combo;
    timecombo.notify["when"].connect(() => {
      if (time_filled)
        start_files_operation();
    });

    // Initial setup call
    selection_changed();
  }

  void selection_changed() {
    var bitset = selection.get_selection();
    has_selection = !bitset.is_empty();
  }

  void items_changed() {
    if (files_filled) {
      update_content_view();
      selection_changed(); // I wish the selection model did this automatically
    }
  }

  public void select_all() {
    selection.select_all();
  }

  public void go_up() {
    if (store.go_up())
      folder_changed();
  }

  [GtkCallback]
  void go_down(uint position) {
    if (store.go_down(position))
      folder_changed();
  }

  // Shows the right pane - search view, normal view, empty versions of either
  void update_content_view()
  {
    if (search_filter != "") {
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
    store.search_filter = search_filter;
  }

  [GtkCallback]
  void grab_passphrase()
  {
    grap_passphrase_async.begin();
  }

  async void grap_passphrase_async()
  {
    var dialog = new PassphraseDialog();
    dialog.transient_for = app_window;

    var passphrase = yield dialog.prompt_user();

    if (operation != null && passphrase != null) {
      operation.set_passphrase(passphrase);
      switch_overlay_to_spinner(); // quits loop too
    }
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

  [GtkCallback]
  async void packagekit_install()
  {
#if HAS_PACKAGEKIT
    switch_overlay_to("packagekit-progress");
    operation_blocked = true;

    try {
      var client = new Pk.Client();
      yield client.install_packages_async(0, packagekit_ids, null, (p, t) => {});
      operation_blocked = false;
      maybe_start_operation();
    }
    catch (Error e) {
      operation_blocked = false;
      switch_overlay_to_error(e.message);
    }
#endif
  }

#if HAS_PACKAGEKIT
  void switch_overlay_to_packagekit(DejaDup.Operation op, string[] names, string[] ids)
  {
    stop_operation();

    var pkgs = "";
    foreach (var s in names) {
      if (pkgs != "")
        pkgs += ", ";
      pkgs += "<b>%s</b>".printf(s);
    }
    packagekit_label.label = _("In order to continue, the following packages need to be installed:") + " " + pkgs;
    packagekit_ids = ids;
    Notifications.attention_needed(app_window, _("Backups needs to install packages to continue"));

    switch_overlay_to("packagekit");
  }
#endif

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
      var launcher = new Gtk.UriLauncher(auth_url);
      launcher.launch.begin(app_window, null);
    }
  }

  public void start_restore()
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

#if HAS_PACKAGEKIT
    operation.install.connect(switch_overlay_to_packagekit);
#endif

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

    if (operation_blocked || !app_window_is_active() || !is_visible_page)
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
