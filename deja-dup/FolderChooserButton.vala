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
    label = _("_Choose Folder…");
    receives_default = true;
    use_underline = true;
    clicked.connect(on_clicked);
  }

  void on_clicked()
  {
    var dlg = new Gtk.FileChooserNative(_("Choose Folder"),
                                        this.root as Gtk.Window,
                                        Gtk.FileChooserAction.SELECT_FOLDER,
                                        null, null);
    dlg.modal = true;
    dlg.response.connect(on_dialog_response);

    dlg.show();
    dlg.ref();
  }

  void on_dialog_response(Gtk.NativeDialog dlg, int response)
  {
    if (response == Gtk.ResponseType.ACCEPT) {
      var dlg_file = ((Gtk.FileChooser)dlg).get_file();
      var dlg_path = DejaDup.BackendLocal.get_path_from_file(dlg_file);
      if (dlg_path != null) {
        path = dlg_path;
        file = dlg_file;
        file_selected();
      }
    }
    dlg.unref();
  }
}
