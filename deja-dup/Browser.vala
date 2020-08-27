/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

class Browser : BuilderWidget
{
  public DejaDupApp application {get; construct;}
  public bool time_filled {get; private set;}
  public bool files_filled {get; private set;}
  public DejaDup.Operation operation {get; private set;}

  public Browser(Gtk.Builder builder, DejaDupApp application)
  {
    Object(builder: builder, application: application);
  }

  const ActionEntry[] ACTIONS = {
    {"select-all", select_all},
    {"select-none", select_none},
    {"go-up", go_up},
    {"search", activate_search},
  };

  FileStore store;
  TimeCombo timecombo;
  DejaDup.BackendWatcher watcher;
  string auth_url; // if null, auth button should start mount op vs oauth
  MountOperation mount_op; // normally null
  MainLoop passphrase_loop;

  construct
  {
    var header_stack = builder.get_object("header-stack") as Gtk.Stack;

    store = new FileStore();

    // Set up actions
    var main_window = builder.get_object("main-window") as Gtk.ApplicationWindow;
    var action_group = new SimpleActionGroup();
    action_group.add_action_entries(ACTIONS, this);
    application.set_accels_for_action("restore.go-up", {"<Mod1>Left", "<Mod1>Up"});
    application.set_accels_for_action("restore.search", {"<Primary>F"});

    timecombo = new TimeCombo(builder);
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

    // Notice when we are switched to and away from and notice when we need to
    // reset operation.
    var stack = builder.get_object("stack") as Gtk.Stack;
    stack.notify["visible-child-name"].connect(() => {
      if (stack.visible_child_name == "restore") {
        main_window.insert_action_group("restore", action_group);
        start_operation();
      } else {
        main_window.insert_action_group("restore", null);
      }
    });
    application.notify["operation"].connect(() => {
      if (application.operation != null)
        stop_operation(); // get out of way of a real backup/restore op
    });
    application.window_removed.connect((win) => {
      unowned var windows = application.get_windows();
      var only_main_window = windows.length() == 1;
      if (only_main_window && stack.visible_child_name == "restore")
        start_operation();
    });

    // Connect file store and icon view
    var icon_view = builder.get_object("restore-icon-view") as Gtk.IconView;
    bind_property("files-filled", icon_view, "sensitive", BindingFlags.SYNC_CREATE);
    icon_view.model = store;
    icon_view.pixbuf_column = FileStore.Column.ICON;
    icon_view.text_column = FileStore.Column.FILENAME;
    icon_view.item_activated.connect((v, p) => {go_down(p);});
    icon_view.button_press_event.connect(handle_icon_button_press);
    icon_view.selection_changed.connect(selection_changed);

    // Manually tweak some aspects of the icon view (we should maybe switch to
    // a different widget like Gtk.FlowBox?)
    var cells = icon_view.get_cells();
    var pixbuf_renderer = cells.data as Gtk.CellRendererPixbuf;
    icon_view.set_attributes(pixbuf_renderer, "gicon", FileStore.Column.GICON);
    pixbuf_renderer.set("stock-size", Gtk.IconSize.DIALOG);

    // Set up list view as well
    var list_view = builder.get_object("restore-list-view") as Gtk.TreeView;
    bind_property("files-filled", list_view, "sensitive", BindingFlags.SYNC_CREATE);
    list_view.row_activated.connect((v, p, c) => {go_down(p);});
    list_view.button_press_event.connect(handle_list_button_press);
    list_view.get_selection().changed.connect(selection_changed);

    // Set selection menu
    var selection_menu = builder.get_object("selection-menu-button") as Gtk.MenuButton;
    selection_menu.set_menu_model(application.get_menu_by_id("selection-menu"));

    // Connect various buttons

    var go_up_action = action_group.lookup_action("go-up");
    store.bind_property("can-go-up", go_up_action, "enabled", BindingFlags.SYNC_CREATE);

    var search_button = builder.get_object("search-button") as Gtk.Button;
    var selection_search_button = builder.get_object("selection-search-button") as Gtk.Button;
    var search_bar = builder.get_object("search-bar") as Gtk.SearchBar;
    var search_entry = builder.get_object("search-entry") as Gtk.SearchEntry;
    bind_property("files-filled", search_button, "sensitive", BindingFlags.SYNC_CREATE);
    bind_property("files-filled", selection_search_button, "sensitive", BindingFlags.SYNC_CREATE);
    search_bar.bind_property("search-mode-enabled", search_button, "active",
                                BindingFlags.BIDIRECTIONAL);
    search_bar.bind_property("search-mode-enabled", selection_search_button, "active",
                                BindingFlags.BIDIRECTIONAL);
    search_entry.search_changed.connect(update_search_filter);

    var selection_button = builder.get_object("selection-button") as Gtk.Button;
    bind_property("files-filled", selection_button, "sensitive", BindingFlags.SYNC_CREATE);
    selection_button.clicked.connect(() => {
      header_stack.visible_child_name = "selection";
    });

    var selection_cancel = builder.get_object("selection-cancel-button") as Gtk.Button;
    selection_cancel.clicked.connect(() => {
      header_stack.visible_child_name = "main";
    });
    main_window.key_press_event.connect((e) => {
      uint modifiers = Gtk.accelerator_get_default_mod_mask();
      if (e.keyval == Gdk.Key.Escape && (e.state & modifiers) == 0 &&
          header_stack.visible_child_name == "selection") {
        header_stack.visible_child_name = "main";
        return true;
      }
      else
        return false;
    });

    var retry_button = builder.get_object("restore-error-retry-button") as Gtk.Button;
    retry_button.clicked.connect(start_operation);

    var auth_button = builder.get_object("restore-auth-button") as Gtk.Button;
    auth_button.clicked.connect(start_auth);

    var passphrase_button = builder.get_object("restore-passphrase-button") as Gtk.Button;
    passphrase_button.clicked.connect(grab_passphrase);

    var restore_button = builder.get_object("restore-context-button") as Gtk.Button;
    restore_button.clicked.connect(() => {
      List<File> files;
      var treepaths = get_selected_items();
      foreach (var treepath in treepaths) {
        var file = store.get_file(treepath);
        if (file != null)
          files.append(file);
      }
      application.restore_files(files, timecombo.when, store.tree);
    });

    // Watch for backend changes that need to reset us
    watcher = new DejaDup.BackendWatcher();
    watcher.changed.connect(clear_operation);
    watcher.new_backup.connect(clear_operation);
    application.notify["custom-backend"].connect(() => {
      clear_operation();
      if (application.custom_backend != null)
        start_operation();
    });

    // Set up passphrase dialog
    passphrase_loop = new MainLoop(null); // not started yet, but will be
    var dialog = new PassphraseDialog(builder);
    dialog.got_passphrase.connect((passphrase) => {
      if (operation != null) {
        operation.set_passphrase(passphrase);
        switch_overlay_to_spinner(); // quits main loop too
      }
    });
    var overlay_stack = builder.get_object("restore-overlay-stack") as Gtk.Stack;
    overlay_stack.notify["visible-child-name"].connect(() => {
      if (overlay_stack.visible_child_name != "passphrase")
        passphrase_loop.quit();
    });

    // Initial setup call
    selection_changed();
  }

  void selection_changed() {
    var restore_button = builder.get_object("restore-context-button") as Gtk.Button;
    var selection_label = builder.get_object("selection-label") as Gtk.Label;

    var count = get_selected_items().length();
    restore_button.sensitive = count > 0;
    if (count == 0) {
      selection_label.label = _("Click on items to select them");
    } else {
      selection_label.label = ngettext("%u selected", "%u selected",
                                       count).printf(count);
    }
  }

  List<Gtk.TreePath> get_selected_items()
  {
    var stack = builder.get_object("restore-view-stack") as Gtk.Stack;

    if (stack.visible_child_name == "icons") {
      var icon_view = builder.get_object("restore-icon-view") as Gtk.IconView;
      return icon_view.get_selected_items();
    } else {
      var list_view = builder.get_object("restore-list-view") as Gtk.TreeView;
      return list_view.get_selection().get_selected_rows(null);
    }
  }

  void select_all() {
    var stack = builder.get_object("restore-view-stack") as Gtk.Stack;

    if (stack.visible_child_name == "icons") {
      var icon_view = builder.get_object("restore-icon-view") as Gtk.IconView;
      icon_view.select_all();
    } else {
      var list_view = builder.get_object("restore-list-view") as Gtk.TreeView;
      list_view.get_selection().select_all();
    }
  }

  void select_none() {
    var stack = builder.get_object("restore-view-stack") as Gtk.Stack;

    if (stack.visible_child_name == "icons") {
      var icon_view = builder.get_object("restore-icon-view") as Gtk.IconView;
      icon_view.unselect_all();
    } else {
      var list_view = builder.get_object("restore-list-view") as Gtk.TreeView;
      list_view.get_selection().unselect_all();
    }
  }

  void go_up() {
    store.go_up();

    var search_bar = builder.get_object("search-bar") as Gtk.SearchBar;
    search_bar.search_mode_enabled = false;
  }

  void go_down(Gtk.TreePath path) {
    store.go_down(path);

    var search_bar = builder.get_object("search-bar") as Gtk.SearchBar;
    search_bar.search_mode_enabled = false;
  }

  void activate_search() {
    var search_bar = builder.get_object("search-bar") as Gtk.SearchBar;
    var search_entry = builder.get_object("search-entry") as Gtk.SearchEntry;

    search_bar.search_mode_enabled = true;
    search_entry.grab_focus();
  }

  void update_search_filter() {
    var search_entry = builder.get_object("search-entry") as Gtk.SearchEntry;
    var icons = builder.get_object("restore-icon-view") as Gtk.IconView;
    var list = builder.get_object("restore-list-view") as Gtk.TreeView;
    var stack = builder.get_object("restore-view-stack") as Gtk.Stack;

    if (search_entry.text != "") {
      stack.visible_child_name = "list";
      icons.model = null;
      list.model = store;
    } else {
      stack.visible_child_name = "icons";
      list.model = null;
      icons.model = store;
    }

    store.search_filter = search_entry.text;
  }

  // Keep this in sync with handle_list_button_press below
  bool handle_icon_button_press(Gdk.EventButton event)
  {
    // If we are in selection mode, we want to override normal behavior and
    // simply toggle selected status.

    var header_stack = builder.get_object("header-stack") as Gtk.Stack;
    if (header_stack.visible_child_name != "selection")
      return false;

    if (event.button != Gdk.BUTTON_PRIMARY || event.state != 0)
      return false;

    // After this point, we are handling this event, and should return true

    var view = builder.get_object("restore-icon-view") as Gtk.IconView;
    var path = view.get_path_at_pos((int)event.x, (int)event.y);
    if (path == null)
      return true;

    if (view.path_is_selected(path))
      view.unselect_path(path);
    else
      view.select_path(path);

    return true;
  }

  // Keep this in sync with handle_icon_button_press above
  bool handle_list_button_press(Gdk.EventButton event)
  {
    // If we are in selection mode, we want to override normal behavior and
    // simply toggle selected status.

    var header_stack = builder.get_object("header-stack") as Gtk.Stack;
    if (header_stack.visible_child_name != "selection")
      return false;

    if (event.button != Gdk.BUTTON_PRIMARY || event.state != 0)
      return false;

    // After this point, we are handling this event, and should return true

    var view = builder.get_object("restore-list-view") as Gtk.TreeView;
    Gtk.TreePath path;
    if (!view.get_path_at_pos((int)event.x, (int)event.y, out path, null, null, null))
      return true;

    var selection = view.get_selection();
    if (selection.path_is_selected(path))
      selection.unselect_path(path);
    else
      selection.select_path(path);

    return true;
  }

  void grab_passphrase() {
    var passphrase_dialog = builder.get_object("passphrase-dialog") as Gtk.Dialog;
    var passphrase_entry = builder.get_object("passphrase-entry") as Gtk.Entry;
    passphrase_entry.text = "";
    passphrase_dialog.show();
  }

  void switch_overlay_to_spinner() {
    var overlay_stack = builder.get_object("restore-overlay-stack") as Gtk.Stack;
    overlay_stack.visible_child_name = "spinner";
    overlay_stack.visible = true;
  }

  void switch_overlay_to_error(string msg) {
    var error_label = builder.get_object("restore-error-label") as Gtk.Label;
    error_label.label = msg;

    var overlay_stack = builder.get_object("restore-overlay-stack") as Gtk.Stack;
    overlay_stack.visible_child_name = "error";
    overlay_stack.visible = true;
  }

  void switch_overlay_to_pause(string msg) {
    var pause_label = builder.get_object("restore-pause-label") as Gtk.Label;
    pause_label.label = msg;

    var overlay_stack = builder.get_object("restore-overlay-stack") as Gtk.Stack;
    overlay_stack.visible_child_name = "pause";
    overlay_stack.visible = true;
  }

  void switch_overlay_to_mount_needed() {
    var overlay_stack = builder.get_object("restore-overlay-stack") as Gtk.Stack;
    overlay_stack.visible_child_name = "auth";
    overlay_stack.visible = true;

    var overlay_label = builder.get_object("restore-auth-label") as Gtk.Label;
    overlay_label.label = _("Authentication needed");
    auth_url = null;

    // disconnect error handler, or else we'll switch to that instead when
    // the operation inevitably fails
    operation.raise_error.disconnect(handle_operation_error);
  }

  void switch_overlay_to_oauth_needed(string msg, string url) {
    var overlay_stack = builder.get_object("restore-overlay-stack") as Gtk.Stack;
    overlay_stack.visible_child_name = "auth";
    overlay_stack.visible = true;

    var overlay_label = builder.get_object("restore-auth-label") as Gtk.Label;
    overlay_label.label = msg;
    auth_url = url;
  }

  void switch_overlay_to_passphrase() {
    var overlay_stack = builder.get_object("restore-overlay-stack") as Gtk.Stack;
    overlay_stack.visible_child_name = "passphrase";
    overlay_stack.visible = true;

    // Now this signal (passphrase_required) has unfortunate semantics. We need
    // to keep a main loop open until we get the operation its passphrase.
    passphrase_loop.run();
  }

  void switch_overlay_off() {
    var overlay_stack = builder.get_object("restore-overlay-stack") as Gtk.Stack;
    overlay_stack.visible = false;
  }

  void start_auth() {
    if (auth_url == null) {
      var main_window = builder.get_object("main-window") as Gtk.Window;
      mount_op = new Gtk.MountOperation(main_window);
      start_operation();
    } else {
      var main_window = builder.get_object("main-window") as Gtk.Window;
      DejaDup.show_uri(main_window, auth_url);
    }
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
  }

  void start_operation()
  {
    if (operation != null)
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
