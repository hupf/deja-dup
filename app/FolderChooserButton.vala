/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

class FolderChooserButton : Gtk.Button
{
  // Can be relative to home folder
  public string path {get; private set;}
  public File file {get; private set;}

  public signal void file_selected();

  construct {
    icon_name = "document-open";
    receives_default = true;
    use_underline = true;
    update_property(Gtk.AccessibleProperty.LABEL, _("Choose Folder"));
    clicked.connect(on_clicked);
  }

  void on_clicked()
  {
    on_clicked_async.begin();
  }

  async void on_clicked_async()
  {
    var dlg = new Gtk.FileDialog();
    dlg.modal = true;

    try {
      var folder = yield dlg.select_folder(this.root as Gtk.Window, null);
      on_dialog_response(folder);
    } catch (Error e) {
      // Ignore, as it is probably just a user-cancellation
    }
  }

  void on_dialog_response(File folder)
  {
    var dlg_path = DejaDup.BackendLocal.get_path_from_file(folder);
    if (dlg_path != null) {
      path = dlg_path;
      file = folder;
      file_selected();
    }
  }
}
