/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/ConfigLocationGrid.ui")]
public class ConfigLocationGrid : Gtk.Grid
{
  public bool read_only {get; construct;}

  public ConfigLocationGrid(bool read_only = false) {
    Object(read_only: read_only);
  }

  public void set_location_label(string label)
  {
    location_label.label = label;
  }

  public DejaDup.Backend get_backend()
  {
    string name = DejaDup.Backend.get_key_name(settings);

    Settings sub_settings = null;
    if (name == "drive")
      sub_settings = drive_settings;
    else if (name == "google")
      sub_settings = google_settings;
    else if (name == "local")
      sub_settings = local_settings;
    else if (name == "remote")
      sub_settings = remote_settings;

    return DejaDup.Backend.get_for_key(name, sub_settings);
  }

  [GtkChild]
  Gtk.Label location_label;
  [GtkChild]
  Gtk.Stack location_stack;

  [GtkChild]
  Gtk.Entry google_folder;
  [GtkChild]
  Gtk.Button google_reset;

  [GtkChild]
  ConfigServerEntry remote_address;
  [GtkChild]
  Gtk.Entry remote_folder;

  [GtkChild]
  Gtk.Entry drive_folder;

  [GtkChild]
  Gtk.Entry local_folder;
  [GtkChild]
  FolderChooserButton local_browse;

  [GtkChild]
  Gtk.Label unsupported_label;

  DejaDup.FilteredSettings settings;
  DejaDup.FilteredSettings drive_settings;
  DejaDup.FilteredSettings google_settings;
  DejaDup.FilteredSettings local_settings;
  DejaDup.FilteredSettings remote_settings;
  ConfigLocationCombo combo;
  construct {
    settings = new DejaDup.FilteredSettings(null, read_only);

    drive_settings = new DejaDup.FilteredSettings(DejaDup.DRIVE_ROOT, read_only);
    bind_folder(drive_settings, DejaDup.DRIVE_FOLDER_KEY, drive_folder, false);

    google_settings = new DejaDup.FilteredSettings(DejaDup.GOOGLE_ROOT, read_only);
    bind_folder(google_settings, DejaDup.GOOGLE_FOLDER_KEY, google_folder, false);
    set_up_google_reset.begin();

    local_settings = new DejaDup.FilteredSettings(DejaDup.LOCAL_ROOT, read_only);
    bind_folder(local_settings, DejaDup.LOCAL_FOLDER_KEY, local_folder, true);

    remote_settings = new DejaDup.FilteredSettings(DejaDup.REMOTE_ROOT, read_only);
    bind_folder(remote_settings, DejaDup.REMOTE_FOLDER_KEY, remote_folder, true);
    remote_settings.bind(DejaDup.REMOTE_URI_KEY, remote_address,
                         "text", SettingsBindFlags.DEFAULT);

    combo = new ConfigLocationCombo(settings, drive_settings);
    combo.hexpand = true;
    attach(combo, 1, 0);
    location_label.mnemonic_widget = combo;

    combo.notify["selected-item"].connect(update_stack);
    update_stack();
  }

  void update_stack()
  {
    var item = combo.selected_item;
    if (item == null)
      return;

    var page = item.page;
    string support_explanation = null;
    if (!DejaDup.get_tool().supports_backend(item.backend_kind, out support_explanation))
      page = "unsupported";

    if (page == "unsupported")
      unsupported_label.label = support_explanation;

    location_stack.visible_child_name = page;
  }

  void bind_folder(Settings settings, string key, Gtk.Entry entry, bool allow_abs)
  {
    settings.bind_with_mapping(key, entry, "text",
      SettingsBindFlags.DEFAULT, get_folder_mapping, set_identity_mapping,
      ((int)allow_abs).to_pointer(), null);
  }

  static bool get_folder_mapping(Value val, Variant variant, void *data)
  {
    var allow_abs = (bool)int.from_pointer(data);
    var folder = DejaDup.process_folder_key(variant.get_string(), allow_abs, null);
    val.set_string(folder);
    return true;
  }

  // This shouldn't be needed, but vala warns about null args to bind_with_mapping
  static Variant set_identity_mapping(Value val, VariantType expected_type, void *data)
  {
    return new Variant.string(val.get_string());
  }

  [GtkCallback]
  void on_local_file_selected()
  {
    if (DejaDup.BackendDrive.set_volume_info_from_file(local_browse.file, drive_settings)) {
      settings.set_string(DejaDup.BACKEND_KEY, "drive");
    } else {
      local_folder.text = local_browse.path;
    }
  }

  [GtkCallback]
  void on_google_reset_clicked()
  {
    DejaDup.BackendGoogle.clear_refresh_token.begin();
    google_reset.visible = false;
  }

  async void set_up_google_reset()
  {
    var token = yield DejaDup.BackendGoogle.lookup_refresh_token();
    if (token != null) {
      google_reset.visible = true;
    }
  }
}
