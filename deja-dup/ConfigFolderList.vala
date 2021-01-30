/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/ConfigFolderList.ui")]
public class ConfigFolderList : Adw.PreferencesGroup
{
  public string key {get; construct;}
  public bool check_access {get; construct;}

  [GtkChild]
  unowned Gtk.Widget add_row;

  DejaDup.FilteredSettings settings;
  List<unowned Gtk.Widget> rows;
  construct {
    settings = DejaDup.get_settings();
    settings.bind_writable(key, this, "sensitive", false);

    settings.changed[key].connect(() => {update_list_items.begin();});
    update_list_items.begin();
  }

  async void update_list_items()
  {
    rows.foreach((item) => {remove(item);});
    rows = null;

    add_row.ref();
    remove(add_row);

    var folder_value = settings.get_value(key);
    var folder_list = folder_value.get_strv();
    foreach (var folder in folder_list) {
      var file = DejaDup.parse_dir(folder);
      if (file == null)
        continue;

      var row = new ConfigFolderRow();
      row.file = file;
      row.check_access = check_access;
      row.set_data("folder", folder);
      row.remove_clicked.connect((r) => {
        handle_remove(r.get_data("folder"));
      });

      rows.append(row);
      add(row);
    }

    // Now add back the "add item" row
    add(add_row);
    add_row.unref();
  }

  [GtkCallback]
  void on_add_clicked()
  {
    var dlg = new Gtk.FileChooserNative(_("Choose Folders"),
                                        this.root as Gtk.Window,
                                        Gtk.FileChooserAction.SELECT_FOLDER,
                                        _("Add"), null);
    dlg.modal = true;
    dlg.select_multiple = true;

    dlg.response.connect((response) => {
      if (response == Gtk.ResponseType.ACCEPT) {
        add_files(dlg.get_files());
      }
      dlg.destroy();
    });

    dlg.show();
  }

  bool add_files(ListModel files)
  {
    // Explicitly do not call get_file_list here, because we want to avoid
    // modifying existing entries at all when we write the string list back.
    var slist_val = settings.get_value(key);
    string*[] slist = slist_val.get_strv();
    bool changed = false;

    for (int i = 0; i < files.get_n_items(); i++) {
      var folder = files.get_item(i) as File;
      if (folder.get_path() == null)
        continue;

      // Strip any leading root path in case the user somehow navigated to the
      // read root. We'll prefix it again when backing up.
      folder = DejaDup.remove_read_root(folder);

      bool found = false;
      foreach (string s in slist) {
        var sfile = DejaDup.parse_dir(s);
        if (sfile != null && sfile.equal(folder)) {
          found = true;
          break;
        }
      }

      if (!found) {
        slist += folder.get_parse_name();
        changed = true;
      }
    }

    if (changed) {
      settings.set_value(key, new Variant.strv(slist));
    }
    return changed;
  }

  void handle_remove(string folder)
  {
    var old_value = settings.get_value(key);
    var old_list = old_value.get_strv();
    var new_list = new string[0];

    foreach (string old in old_list) {
      if (old != folder)
        new_list += old;
    }

    settings.set_value(key, new Variant.strv(new_list));
  }
}
