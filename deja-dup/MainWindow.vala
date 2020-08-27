/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class MainWindow : BuilderWidget
{
  public DejaDupApp application {get; construct;}
  public Gtk.ApplicationWindow app_window {get; construct;}
  public Gtk.MenuButton menu_button {get; construct;}

  public MainWindow(DejaDupApp app)
  {
    Object(application: app, builder: new Builder("main"));
  }

  construct {
    adopt_name("main-window");

    app_window = builder.get_object("main-window") as Gtk.ApplicationWindow;
    app_window.application = application;
    app_window.title = _("Backups");

    menu_button = builder.get_object("primary-menu-button") as Gtk.MenuButton;
    menu_button.set_menu_model(application.get_menu_by_id("primary-menu"));

    var app_logo = builder.get_object("app-logo") as Gtk.Image;
    app_logo.icon_name = Config.ICON_NAME;

    var backup_button = builder.get_object("backup-button") as Gtk.Button;
    backup_button.clicked.connect(application.backup);

    var initial_backup_button = builder.get_object("initial-backup-button") as Gtk.Button;
    initial_backup_button.clicked.connect(application.backup);

    var initial_restore_button = builder.get_object("initial-restore-button") as Gtk.Button;
    initial_restore_button.clicked.connect(application.start_custom_restore);

    var overview_stack = builder.get_object("overview-stack") as Gtk.Stack;
    var settings = DejaDup.get_settings();
    settings.bind_with_mapping(DejaDup.LAST_BACKUP_KEY, overview_stack, "visible-child-name",
                               SettingsBindFlags.GET, get_visible_child, set_visible_child,
                               null, null);

    // If a custom restore backend is set, we switch to restore.
    // If we switch away, we undo the custom restore backend.
    var stack = builder.get_object("stack") as Gtk.Stack;
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

    DejaDupApp.get_instance().add_window(app_window);
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
