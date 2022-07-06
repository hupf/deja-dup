/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/ConfigLocationGroup.ui")]
public class ConfigLocationGroup : DynamicPreferencesGroup
{
  public bool read_only {get; construct;}

  public ConfigLocationGroup(bool read_only = false) {
    Object(read_only: read_only);
  }

  public DejaDup.Backend get_backend()
  {
    string name = DejaDup.Backend.get_key_name(settings);

    Settings sub_settings = null;
    if (name == "drive")
      sub_settings = drive_settings;
    else if (name == "google")
      sub_settings = google_settings;
    else if (name == "microsoft")
      sub_settings = microsoft_settings;
    else if (name == "local")
      sub_settings = local_settings;
    else if (name == "remote")
      sub_settings = remote_settings;

    return DejaDup.Backend.get_for_key(name, sub_settings);
  }

  [GtkChild]
  unowned ConfigLocationCombo combo;

  [GtkChild]
  unowned Adw.EntryRow google_folder;
  [GtkChild]
  unowned Gtk.Button google_reset;

  [GtkChild]
  unowned Adw.EntryRow microsoft_folder;
  [GtkChild]
  unowned Gtk.Button microsoft_reset;

  [GtkChild]
  unowned Adw.EntryRow remote_address;
  [GtkChild]
  unowned Adw.EntryRow remote_folder;

  [GtkChild]
  unowned Adw.EntryRow drive_folder;

  [GtkChild]
  unowned Adw.EntryRow local_folder;
  [GtkChild]
  unowned FolderChooserButton local_browse;

  [GtkChild]
  unowned Gtk.Label unsupported_label;

  DejaDup.FilteredSettings settings;
  DejaDup.FilteredSettings drive_settings;
  DejaDup.FilteredSettings google_settings;
  DejaDup.FilteredSettings microsoft_settings;
  DejaDup.FilteredSettings local_settings;
  DejaDup.FilteredSettings remote_settings;
  construct {
    settings = new DejaDup.FilteredSettings(null, read_only);

    // Google
    google_settings = new DejaDup.FilteredSettings(DejaDup.GOOGLE_ROOT, read_only);
    bind_folder(google_settings, DejaDup.GOOGLE_FOLDER_KEY, google_folder, false);
    set_up_google_reset.begin();

    // Microsoft
    microsoft_settings = new DejaDup.FilteredSettings(DejaDup.MICROSOFT_ROOT, read_only);
    bind_folder(microsoft_settings, DejaDup.MICROSOFT_FOLDER_KEY, microsoft_folder, false);
    set_up_microsoft_reset.begin();

    // Remote
    remote_settings = new DejaDup.FilteredSettings(DejaDup.REMOTE_ROOT, read_only);
    bind_folder(remote_settings, DejaDup.REMOTE_FOLDER_KEY, remote_folder, true);
    remote_settings.bind(DejaDup.REMOTE_URI_KEY, remote_address,
                         "text", SettingsBindFlags.DEFAULT);
    DejaDup.configure_entry_row(remote_address, false, Gtk.InputHints.NO_SPELLCHECK, Gtk.InputPurpose.URL);

    // Drive
    drive_settings = new DejaDup.FilteredSettings(DejaDup.DRIVE_ROOT, read_only);
    bind_folder(drive_settings, DejaDup.DRIVE_FOLDER_KEY, drive_folder, false);

    // Local
    local_settings = new DejaDup.FilteredSettings(DejaDup.LOCAL_ROOT, read_only);
    bind_folder(local_settings, DejaDup.LOCAL_FOLDER_KEY, local_folder, true);

    combo.setup(settings, drive_settings);
    combo.notify["selected-item"].connect(update_stack);
    update_stack();
  }

  void update_stack()
  {
    var item = combo.selected_item as ConfigLocationCombo.Item;
    if (item == null)
      return;

    var page = item.page;
    string support_explanation = null;
    if (!DejaDup.get_tool().supports_backend(item.backend_kind, out support_explanation))
      page = "unsupported";

    if (page == "unsupported")
      unsupported_label.label = support_explanation;

    mode = page;
  }

  void bind_folder(Settings settings, string key, Adw.EntryRow entry, bool allow_abs)
  {
    settings.bind_with_mapping(key, entry, "text",
      SettingsBindFlags.DEFAULT, get_folder_mapping, set_identity_mapping,
      ((int)allow_abs).to_pointer(), null);

    DejaDup.configure_entry_row(entry, false, Gtk.InputHints.NO_SPELLCHECK);
  }

  static bool get_folder_mapping(Value val, Variant variant, void *data)
  {
    var allow_abs = (bool)int.from_pointer(data);
    var folder = DejaDup.process_folder_key(variant.get_string(), allow_abs, null);
    if (DejaDup.in_demo_mode())
      folder = "hostname";
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
    var backend = new DejaDup.BackendGoogle(google_settings);
    backend.clear_refresh_token.begin();
    google_reset.visible = false;
  }

  async void set_up_google_reset()
  {
    var backend = new DejaDup.BackendGoogle(google_settings);
    var token = yield backend.lookup_refresh_token();
    google_reset.visible = token != null && !DejaDup.in_demo_mode();
  }

  [GtkCallback]
  void on_microsoft_reset_clicked()
  {
    var backend = new DejaDup.BackendMicrosoft(microsoft_settings);
    backend.clear_refresh_token.begin();
    microsoft_reset.visible = false;
  }

  async void set_up_microsoft_reset()
  {
    var backend = new DejaDup.BackendMicrosoft(microsoft_settings);
    var token = yield backend.lookup_refresh_token();
    microsoft_reset.visible = token != null;
  }
}
