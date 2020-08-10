/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class ConfigLocationGrid : BuilderWidget
{
  public bool read_only {get; construct;}

  public ConfigLocationGrid(Gtk.Builder builder, bool read_only = false) {
    Object(builder: builder, read_only: read_only);
  }

  public DejaDup.Backend get_backend()
  {
    string name = DejaDup.Backend.get_type_name(settings);

    Settings sub_settings = null;
    if (name == "drive")
      sub_settings = drive_settings;
    else if (name == "google")
      sub_settings = google_settings;
    else if (name == "local")
      sub_settings = local_settings;
    else if (name == "remote")
      sub_settings = remote_settings;

    return DejaDup.Backend.get_for_type(name, sub_settings);
  }

  Gtk.Popover hint;
  DejaDup.FilteredSettings settings;
  DejaDup.FilteredSettings drive_settings;
  DejaDup.FilteredSettings google_settings;
  DejaDup.FilteredSettings local_settings;
  DejaDup.FilteredSettings remote_settings;
  construct {
    adopt_name("location_grid");

    settings = new DejaDup.FilteredSettings(null, read_only);

    drive_settings = new DejaDup.FilteredSettings(DejaDup.DRIVE_ROOT, read_only);
    bind_folder(drive_settings, DejaDup.DRIVE_FOLDER_KEY, "drive_folder", false);

    google_settings = new DejaDup.FilteredSettings(DejaDup.GOOGLE_ROOT, read_only);
    bind_folder(google_settings, DejaDup.GOOGLE_FOLDER_KEY, "google_folder", false);
    set_up_google_reset.begin();

    local_settings = new DejaDup.FilteredSettings(DejaDup.LOCAL_ROOT, read_only);
    bind_folder(local_settings, DejaDup.LOCAL_FOLDER_KEY, "local_folder", true);
    var local_browse = builder.get_object("local_browse") as Gtk.Button;
    local_browse.clicked.connect(local_browse_clicked);

    remote_settings = new DejaDup.FilteredSettings(DejaDup.REMOTE_ROOT, read_only);
    bind_folder(remote_settings, DejaDup.REMOTE_FOLDER_KEY, "remote_folder", true);
    remote_settings.bind(DejaDup.REMOTE_URI_KEY, builder.get_object("remote_address"),
                        "text", SettingsBindFlags.DEFAULT);

    var remote_address = builder.get_object("remote_address") as Gtk.Entry;
    hint = create_hint(remote_address);
    remote_address.icon_press.connect(show_hint);

    new ConfigLocationCombo(builder, settings, drive_settings);
  }

  void bind_folder(Settings settings, string key, string widget_id, bool allow_abs)
  {
    settings.bind_with_mapping(key, builder.get_object(widget_id), "text",
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

  void show_hint(Gtk.Entry entry, Gtk.EntryIconPosition icon_pos, Gdk.Event event)
  {
    Gdk.Rectangle rect = entry.get_icon_area(icon_pos);
    hint.set_pointing_to(rect);
    hint.show_all();
  }

  Gtk.Popover create_hint(Gtk.Entry parent)
  {
    var hint_builder = new Builder("server-hint");
    var popover = hint_builder.get_object("server_adresses_popover") as Gtk.Popover;
    popover.relative_to = parent;
    return popover;
  }

  void local_browse_clicked()
  {
    var entry = builder.get_object("local_folder") as Gtk.Entry;

    var dlg = new Gtk.FileChooserNative(_("Choose Folder"),
                                        entry.get_toplevel() as Gtk.Window,
                                        Gtk.FileChooserAction.SELECT_FOLDER,
                                        _("_OK"), null);

    var current = DejaDup.BackendLocal.get_file_for_path(entry.text);
    if (current != null) {
      try {
        dlg.set_current_folder_file(current);
      }
      catch (Error e) {
        warning("%s\n", e.message);
      }
    }

    if (dlg.run() == Gtk.ResponseType.ACCEPT) {
      var file = dlg.get_file();
      if (DejaDup.BackendDrive.set_volume_info_from_file(file, drive_settings)) {
        settings.set_string(DejaDup.BACKEND_KEY, "drive");
      } else {
        var path = DejaDup.BackendLocal.get_path_from_file(file);
        if (path != null)
          entry.text = path;
      }
    }
  }

  async void set_up_google_reset()
  {
    var google_reset = builder.get_object("google_reset") as Gtk.Button;
    google_reset.clicked.connect(() => {
      DejaDup.BackendGoogle.clear_refresh_token.begin();
      google_reset.visible = false;
    });

    var token = yield DejaDup.BackendGoogle.lookup_refresh_token();
    if (token != null) {
      google_reset.visible = true;
    }
  }
}
