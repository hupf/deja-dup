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

    menu_button = builder.get_object("primary-menu-button") as Gtk.MenuButton;
    menu_button.set_menu_model(application.get_menu_by_id("primary-menu"));

    var app_logo = builder.get_object("app-logo") as Gtk.Image;
    app_logo.icon_name = Config.ICON_NAME;

    var backup_button = builder.get_object("backup-button") as Gtk.Button;
    backup_button.clicked.connect(application.backup);

    var restore_button = builder.get_object("restore-button") as Gtk.Button;
    restore_button.clicked.connect(application.restore);

    new ConfigAutoBackup(builder);
    new ConfigStatusLabel(builder);
  }
}
