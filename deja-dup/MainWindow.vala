/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class MainWindow : BuilderWidget
{
  public DejaDupApp application {get; construct;}

  public MainWindow(DejaDupApp app)
  {
    Object(application: app, builder: DejaDup.make_builder("main"));
  }

  public unowned Gtk.ApplicationWindow get_app_window()
  {
    return get_object("main-window") as Gtk.ApplicationWindow;
  }

  public unowned Gtk.MenuButton get_menu_button()
  {
    return get_object("primary-menu-button") as Gtk.MenuButton;
  }

  construct {
    adopt_name("main-window");

    unowned var app_window = get_app_window();
    app_window.application = application;
    app_window.title = _("Backups");

    unowned var menu_button = get_menu_button();
    menu_button.set_menu_model(application.get_menu_by_id("primary-menu"));

    // Set a few icons that are hardcoded in ui files
    unowned var backups_page = get_object("backups-page") as Gtk.StackPage;
    unowned var app_logo = get_object("app-logo") as Gtk.Image;
    app_logo.icon_name = Config.ICON_NAME;
    backups_page.icon_name = Config.ICON_NAME + "-symbolic";

    unowned var backup_button = get_object("backup-button") as Gtk.Button;
    backup_button.clicked.connect(application.backup);

    unowned var initial_backup_button = get_object("initial-backup-button") as Gtk.Button;
    initial_backup_button.clicked.connect(application.backup);

    unowned var initial_restore_button = get_object("initial-restore-button") as Gtk.Button;
    initial_restore_button.clicked.connect(application.start_custom_restore);

    unowned var overview_stack = get_object("overview-stack") as Gtk.Stack;
    var settings = DejaDup.get_settings();
    settings.bind_with_mapping(DejaDup.LAST_RUN_KEY, overview_stack, "visible-child-name",
                               SettingsBindFlags.GET, get_visible_child, set_visible_child,
                               null, null);

    // If a custom restore backend is set, we switch to restore.
    // If we switch away, we undo the custom restore backend.
    unowned var stack = get_object("stack") as Gtk.Stack;
    stack.notify["visible-child-name"].connect(() => {
      if (stack.visible_child_name != "restore")
        application.custom_backend = null;
    });
    application.notify["custom-backend"].connect(() => {
      if (application.custom_backend != null)
        stack.visible_child_name = "restore";
    });

    new HeaderBar(builder);
    new Browser(builder, application);
    new ConfigAutoBackup(builder);
    new ConfigStatusLabel(builder);
  }

  static bool get_visible_child(Value val, Variant variant, void *data)
  {
    if (variant.get_string() == "")
      val.set_string("initial");
    else
      val.set_string("normal");
    return true;
  }

  // Never called, just here to shut up valac
  static Variant set_visible_child(Value val, VariantType expected_type, void *data)
  {
    return new Variant.string("");
  }
}
