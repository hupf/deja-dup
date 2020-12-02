/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/ConfigFolderRow.ui")]
public class ConfigFolderRow : Hdy.ActionRow
{
  public File file {get; set;}
  public bool check_access {get; set;}

  public signal void remove_clicked();

  [GtkChild]
  Gtk.Image access_icon;

  construct {
    notify["file"].connect(() => {update_row.begin();});
    notify["check-access"].connect(() => {update_row.begin();});
    update_row.begin();
  }

  async void update_row()
  {
    title = file == null ? "" : yield DejaDup.get_nickname(file);

    if (check_access && file != null) {
      var install_env = DejaDup.InstallEnv.instance();
      access_icon.visible = !install_env.is_file_available(file);
    } else {
      access_icon.visible = false;
    }
  }

  [GtkCallback]
  void on_remove_clicked()
  {
    remove_clicked();
  }
}
