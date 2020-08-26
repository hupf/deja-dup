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
  construct {
    adopt_name(builder_id);
    var group = builder.get_object(builder_id) as Hdy.PreferencesGroup;

    settings = DejaDup.get_settings();
    settings.changed[settings_key].connect(() => {update_list_items.begin();});
    settings.bind_writable(settings_key, group, "sensitive", false);

    update_list_items.begin();
  }

  async void update_list_items()
  {
    var group = builder.get_object(builder_id) as Hdy.PreferencesGroup;
    group.foreach((item) => {item.destroy();});

    var folder_value = settings.get_value(settings_key);
    var folder_list = folder_value.get_strv();
    foreach (var folder in folder_list) {
      var file = DejaDup.parse_dir(folder);
      if (file == null)
        continue;

      var row = new Hdy.ActionRow();
      row.activatable = false;
      row.title = yield DejaDup.get_nickname(file);
      row.visible = true;
      group.add(row);

      var button = new Gtk.Button.from_icon_name("list-remove-symbolic", Gtk.IconSize.BUTTON);
      button.get_accessible().set_name(_("Remove"));
      button.valign = Gtk.Align.CENTER;
      button.visible = true;
      button.set_data("folder", folder);
      button.clicked.connect(() => {
        handle_remove(button.get_data("folder"));
      });
      row.add_action(button);

      var install_env = DejaDup.InstallEnv.instance();
      if (check_availability && !install_env.is_file_available(file)) {
        var icon = new Gtk.Image.from_icon_name("dialog-warning", Gtk.IconSize.LARGE_TOOLBAR);
        icon.visible = true;
        icon.tooltip_text = _("This folder cannot be backed up because Backups does not have access to it.");
        row.add_action(icon);
      }
    }

    // Now the "add item" row
    var row = new Hdy.PreferencesRow();
    row.height_request = 50; // same as Hdy.ActionRow
    row.visible = true;
    group.add(row);

    var button = new Gtk.Button.from_icon_name("list-add-symbolic",
                                               Gtk.IconSize.LARGE_TOOLBAR);
    button.get_accessible().set_name(_("Add"));
    button.relief = Gtk.ReliefStyle.NONE;
    button.visible = true;
    button.clicked.connect(handle_add);
    row.add(button);
  }

  void handle_add()
  {
    var window = builder.get_object("preferences") as Gtk.Window;
    var dlg = new Gtk.FileChooserNative(_("Choose folders"), window,
                                        Gtk.FileChooserAction.SELECT_FOLDER,
                                        _("_Add"), null);
    dlg.local_only = true;
    dlg.select_multiple = true;

    if (dlg.run() != Gtk.ResponseType.ACCEPT) {
      return;
    }

    add_files(dlg.get_filenames());
  }

  bool add_files(SList<string>? files)
  {
    if (files == null)
      return false;

    // Explicitly do not call get_file_list here, because we want to avoid
    // modifying existing entries at all when we write the string list back.
    var slist_val = settings.get_value(settings_key);
    string*[] slist = slist_val.get_strv();
    bool changed = false;

    foreach (string file in files) {
      var folder = File.new_for_path(file);

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
