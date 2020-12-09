/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class ConfigLocationCombo : Gtk.Box
{
  public Gtk.Stack stack {get; construct;}
  public DejaDup.FilteredSettings settings {get; construct;}
  public DejaDup.FilteredSettings drive_settings {get; construct;}

  public ConfigLocationCombo(Gtk.Stack stack,
                             DejaDup.FilteredSettings settings,
                             DejaDup.FilteredSettings drive_settings) {
    Object(stack: stack, settings: settings, drive_settings: drive_settings);
  }

  enum Col {
    ICON = 0,
    TEXT,
    SORT,
    ID,
    PAGE,
    GROUP,
    NUM,
  }

  enum Group {
    CLOUD,
    REMOTE,
    VOLUMES,
    LOCAL,
  }

  Gtk.ComboBox combo;
  Gtk.ListStore store;
  Gtk.TreeModelSort sort_model;
  construct {
    // *** Combo Box UI setup ***
    combo = new Gtk.ComboBox();
    combo.hexpand = true;
    append(combo);
    mnemonic_activate.connect(combo.mnemonic_activate);

    // Here we have a model wrapped inside a sortable model.  This is so we
    // can keep indices around for the inner model while the outer model appears
    // nice and sorted to users.
    store = new Gtk.ListStore(Col.NUM, typeof(Icon), typeof(string), typeof(string),
                              typeof(string), typeof(string), typeof(int), typeof(string));
    sort_model = new Gtk.TreeModelSort.with_model(store);
    sort_model.set_sort_column_id(Col.SORT, Gtk.SortType.ASCENDING);
    combo.model = sort_model;
    combo.id_column = Col.ID;

    var pixrenderer = new Gtk.CellRendererPixbuf();
    combo.pack_start(pixrenderer, false);
    combo.add_attribute(pixrenderer, "gicon", Col.ICON);

    var textrenderer = new Gtk.CellRendererText();
    textrenderer.xpad = 6;
    textrenderer.ellipsize = Pango.EllipsizeMode.END;
    textrenderer.ellipsize_set = true;
    textrenderer.max_width_chars = 10;
    combo.pack_start(textrenderer, false);
    combo.add_attribute(textrenderer, "markup", Col.TEXT);

    // *** Basic entries ***

    add_entry("google", "deja-dup-google-drive", _("Google Drive"), Group.CLOUD);
    add_entry("local", "folder", _("Local Folder"), Group.LOCAL);
    add_entry("remote", "network-server", _("Network Server"), Group.REMOTE);

    // *** Removable drives ***

    drive_settings.notify[DejaDup.DRIVE_UUID_KEY].connect(handle_drive_uuid_change);
    var monitor = DejaDup.get_volume_monitor();
    foreach (Volume v in monitor.get_volumes()) {
      add_volume(monitor, v);
    }
    add_saved_volume();

    monitor.volume_added.connect(add_volume);
    monitor.volume_changed.connect(update_volume);
    monitor.volume_removed.connect(remove_volume);

    // *** Now bind our combo to settings ***
    settings.bind_with_mapping(DejaDup.BACKEND_KEY,
                               combo, "active-id",
                               SettingsBindFlags.DEFAULT,
                               get_mapping, set_mapping,
                               this.ref(), Object.unref);

    combo.notify["active-id"].connect(update_stack);
    update_stack();
  }

  bool is_allowed_volume(Volume vol)
  {
    // Unfortunately, there is no convenience API to ask, "what type is this
    // GVolume?"  Instead, we ask for the icon and look for standard icon
    // names to determine type.
    // Maybe there is a way to distinguish between optical drives and flash
    // drives?  But I'm not sure what it is right now.

    if (vol.get_drive() == null)
      return false;

    // Don't add internal hard drives
    if (!vol.get_drive().is_removable())
      return false;

    // First, if the icon is emblemed, look past emblems to real icon
    Icon icon_in = vol.get_icon();
    EmblemedIcon icon_emblemed = icon_in as EmblemedIcon;
    if (icon_emblemed != null)
      icon_in = icon_emblemed.get_icon();

    ThemedIcon icon = icon_in as ThemedIcon;
    if (icon == null)
      return false;

    weak string[] names = icon.get_names();
    foreach (weak string name in names) {
      switch (name) {
      case "drive-harddisk":
      case "drive-removable-media":
      case "media-flash":
      case "media-floppy":
      case "media-tape":
        return true;
      //case "drive-optical":
      //case "media-optical":
      }
    }

    return false;
  }

  void add_entry(string id, string? icon, string label, Group category)
  {
    add_entry_full(id, new ThemedIcon(icon), label, category, null);
  }

  void add_entry_full(string id, Icon? icon, string label, Group category,
                      string? page)
  {
    var index = store.iter_n_children(null);
    var calculated_page = page == null ? id : page;
    store.insert_with_values(null, index, Col.ICON, icon, Col.TEXT, label,
                             Col.SORT, "%d%s".printf((int)category, label),
                             Col.ID, id, Col.PAGE, calculated_page,
                             Col.GROUP, category);
  }

  // A null id is a wildcard, will return first valid result
  bool lookup_id(string? prefix, string? id, out Gtk.TreeIter iter_in)
  {
    iter_in = Gtk.TreeIter();

    var full_id = (prefix != null && id != null) ? prefix + ":" + id : id;

    Gtk.TreeIter iter;
    if (store.get_iter_first(out iter)) {
      do {
        string iter_id;
        store.get(iter, Col.ID, out iter_id);
        if (full_id == null || iter_id == full_id)
        {
          iter_in = iter;
          return true;
        }
      } while (store.iter_next(ref iter));
    }

    return false;
  }

  void add_volume(VolumeMonitor monitor, Volume v)
  {
    if (is_allowed_volume(v))
    {
      add_volume_full(DejaDup.BackendDrive.get_uuid(v), v.get_name(), v.get_icon());
    }
  }

  void add_volume_full(string uuid, string name, Icon icon)
  {
    if (update_volume_full(uuid, name, icon))
      return;

    add_entry_full("drive:" + uuid, icon, name, Group.VOLUMES, "drive");
  }

  void update_volume(VolumeMonitor monitor, Volume v)
  {
    update_volume_full(DejaDup.BackendDrive.get_uuid(v), v.get_name(), v.get_icon());
  }

  bool update_volume_full(string uuid, string name, Icon icon)
  {
    Gtk.TreeIter iter;
    if (!lookup_id("drive", uuid, out iter))
      return false;

    store.set(iter, Col.ICON, icon, Col.TEXT, name);
    return true;
  }

  void remove_volume(VolumeMonitor monitor, Volume v)
  {
    remove_volume_full(DejaDup.BackendDrive.get_uuid(v));
  }

  void remove_volume_full(string uuid)
  {
    Gtk.TreeIter iter;
    if (!lookup_id("drive", uuid, out iter))
      return;

    // Make sure it isn't the saved volume; we never want to remove that
    var saved_uuid = drive_settings.get_string(DejaDup.DRIVE_UUID_KEY);
    if (uuid == saved_uuid)
      return;

    store.remove(ref iter);
  }

  void add_saved_volume()
  {
    // And add an entry for any saved volume
    var uuid = drive_settings.get_string(DejaDup.DRIVE_UUID_KEY);
    if (uuid == "")
      return;

    Icon vol_icon = null;
    try {
      vol_icon = Icon.new_for_string(drive_settings.get_string(DejaDup.DRIVE_ICON_KEY));
    }
    catch (Error e) {warning("%s\n", e.message);}

    var vol_name = drive_settings.get_string(DejaDup.DRIVE_NAME_KEY);

    add_volume_full(uuid, vol_name, vol_icon);
  }

  static bool get_mapping(Value val, Variant variant, void *data)
  {
    var self = (ConfigLocationCombo)data;

    var id = variant.get_string();
    if (id == "drive") {
      id = "drive:" + self.drive_settings.get_string(DejaDup.DRIVE_UUID_KEY);
      if (!self.lookup_id(null, id, null))
        self.add_saved_volume();
    }

    var found = self.lookup_id(null, id, null);
    if (!found) {
      var label = id;
      if (id == "gcs")
        label = _("Google Cloud Storage");
      else if (id == "google")
        label = _("Google Drive");
      else if (id == "openstack")
        label = _("OpenStack Swift");
      else if (id == "rackspace")
        label = _("Rackspace Cloud Files");
      else if (id == "s3")
        label = _("Amazon S3");

      // Assume that we should group with clouds, but not enough to assign
      // a cloud icon.
      self.add_entry_full(id, null, label, Group.CLOUD, "unsupported");
    }

    val.set_string(id);
    return true;
  }

  static Variant set_mapping(Value val, VariantType expected_type, void *data)
  {
    var self = (ConfigLocationCombo)data;
    var id = val.get_string();

    var parts = id.split(":", 2);
    if (parts.length == 2) {
      if (parts[0] == "drive")
        self.set_volume_info(parts[1]);
      id = parts[0];
    }

    return new Variant.string(id);
  }

  void update_stack()
  {
    Gtk.TreeIter sort_iter;
    if (!combo.get_active_iter(out sort_iter))
      return;

    Gtk.TreeIter iter;
    sort_model.convert_iter_to_child_iter(out iter, sort_iter);

    string page;
    store.get(iter, Col.PAGE, out page);

    stack.visible_child_name = page;
  }

  void handle_drive_uuid_change()
  {
    var uuid = drive_settings.get_string(DejaDup.DRIVE_UUID_KEY);
    if (uuid != "")
      combo.active_id = "drive:" + uuid;
  }

  void set_volume_info(string uuid)
  {
    drive_settings.set_string(DejaDup.DRIVE_UUID_KEY, uuid);

    var vol = DejaDup.BackendDrive.find_volume(uuid);
    if (vol == null) {
      // Not an error, it's just not plugged in right now
      return;
    }

    if (!drive_settings.read_only)
      DejaDup.BackendDrive.update_volume_info(vol, drive_settings);
  }
}
