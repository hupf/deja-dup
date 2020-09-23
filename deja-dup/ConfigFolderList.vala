/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class ConfigFolderList : BuilderWidget
{
  public string builder_id {get; construct;}
  public string settings_key {get; construct;}
  public bool check_availability {get; construct;}
  public string[] folders {get; protected set;}

  public ConfigFolderList(Gtk.Builder builder, string builder_id,
                          string settings_key, bool check_availability)
  {
    Object(builder: builder, builder_id: builder_id, settings_key: settings_key,
           check_availability: check_availability);
  }

  DejaDup.FilteredSettings settings;
  List<Gtk.Widget> rows;
  Gtk.Widget add_row;
  construct {
    adopt_name(builder_id);
    unowned var group = get_object(builder_id) as Hdy.PreferencesGroup;

    rows = new List<Gtk.Widget>();

    settings = DejaDup.get_settings();
    settings.changed[settings_key].connect(() => {update_list_items.begin();});
    settings.bind_writable(settings_key, group, "sensitive", false);

    // Make add row separately, and make sure it never gets deleted, since
    // I've hit a bug with depleting a HdyPreferenceGroup completely, then
    // adding a new item, which results in a crash.
    add_row = make_add_row();

    update_list_items.begin();
  }

  async void update_list_items()
  {
    unowned var group = get_object(builder_id) as Hdy.PreferencesGroup;
    rows.foreach((item) => {group.remove(item);});
    rows = new List<Gtk.Widget>();

    var folder_value = settings.get_value(settings_key);
    var folder_list = folder_value.get_strv();
    foreach (var folder in folder_list) {
      var file = DejaDup.parse_dir(folder);
      if (file == null)
        continue;

      var row = new Hdy.ActionRow();
      row.activatable = false;
      row.title = yield DejaDup.get_nickname(file);
      group.add(row);
      rows.append(row);

      var install_env = DejaDup.InstallEnv.instance();
      if (check_availability && !install_env.is_file_available(file)) {
        var icon = new Gtk.Image.from_icon_name("dialog-warning");
        icon.tooltip_text = _("This folder cannot be backed up because Backups does not have access to it.");
        row.add_suffix(icon);
      }

      var button = new Gtk.Button.from_icon_name("list-remove-symbolic");
      button.update_property(Gtk.AccessibleProperty.LABEL, _("Remove"), -1);
      button.valign = Gtk.Align.CENTER;
      button.set_data("folder", folder);
      button.clicked.connect(() => {
        handle_remove(button.get_data("folder"));
      });
      row.add_suffix(button);
    }

    // Now the "add item" row, which moves it to the end if it already exists
    group.add(add_row);
  }

  Gtk.Widget make_add_row()
  {
    var row = new Hdy.PreferencesRow();
    row.height_request = 50; // same as Hdy.ActionRow

    var button = new Gtk.Button.from_icon_name("list-add-symbolic");
    button.update_property(Gtk.AccessibleProperty.LABEL, _("Add"), -1);
    button.has_frame = false;
    button.clicked.connect(handle_add);
    row.child = button;

    return row;
  }

  void handle_add()
  {
    unowned var window = get_object("preferences") as Gtk.Window;
    var dlg = new Gtk.FileChooserNative(_("Choose folders"), window,
                                        Gtk.FileChooserAction.SELECT_FOLDER,
                                        null, null);
    dlg.modal = true;
    dlg.select_multiple = true;

    dlg.response.connect((response) => {
      if (response == Gtk.ResponseType.ACCEPT) {
        add_files(dlg.get_files());
      }
    });

    dlg.show();
  }

  bool add_files(ListModel files)
  {
    // Explicitly do not call get_file_list here, because we want to avoid
    // modifying existing entries at all when we write the string list back.
    var slist_val = settings.get_value(settings_key);
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
      settings.set_value(settings_key, new Variant.strv(slist));
    }
    return changed;
  }

  void handle_remove(string folder)
  {
    var old_value = settings.get_value(settings_key);
    var old_list = old_value.get_strv();
    var new_list = new string[0];

    foreach (string old in old_list) {
      if (old != folder)
        new_list += old;
    }

    settings.set_value(settings_key, new Variant.strv(new_list));
  }
}
