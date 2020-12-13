/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/ConfigLocationCombo.ui")]
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

  enum Group {
    CLOUD,
    REMOTE,
    VOLUMES,
    LOCAL,
  }

  class Item : Object {
    public Icon icon {get; set;}
    public string text {get; set;}
    public string sort_key {get; construct;}
    public string id {get; construct;}
    public string page {get; construct;}
    public Group group {get; construct;}

    public Item(Icon? icon, string text, string sort_key, string id,
                string page, Group group)
    {
      Object(icon: icon, text: text, sort_key: sort_key, id: id, page: page,
             group: group);
    }
  }

  [GtkChild]
  Gtk.DropDown combo;

  ListStore store;
  construct {
    // Here we have a model wrapped inside a sortable model.  This is so we
    // can keep indices around for the inner model while the outer model appears
    // nice and sorted to users.
    store = new ListStore(typeof(Item));
    combo.model = store;

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
                               combo, "selected",
                               SettingsBindFlags.DEFAULT,
                               get_mapping, set_mapping,
                               this.ref(), Object.unref);

    combo.notify["selected-item"].connect(update_stack);
    update_stack();
  }

  [GtkCallback]
  bool on_mnemonic_activate(bool group_cycling) {
    return combo.mnemonic_activate(group_cycling);
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

  uint add_entry_full(string id, Icon? icon, string label, Group group,
                      string? page)
  {
    var calculated_page = page == null ? id : page;
    var sort_key = "%d%s".printf((int)group, label.casefold().collate_key());
    var item = new Item(icon, label, sort_key, id, calculated_page, group);
    return store.insert_sorted(item, (CompareDataFunc)itemcmp);
  }

  static int itemcmp(Item a, Item b) {
    return strcmp(a.sort_key, b.sort_key);
  }

  // A null id is a wildcard, will return first valid result
  Item? lookup_id(string? prefix, string? id, out uint position)
  {
    position = uint.MAX;
    var full_id = (prefix != null && id != null) ? prefix + ":" + id : id;

    for (uint i = 0; i < store.get_n_items(); i++) {
      var item = (Item)store.get_item(i);
      if (full_id == null || item.id == full_id) {
        position = i;
        return item;
      }
    }

    return null;
  }

  void add_volume(VolumeMonitor monitor, Volume v)
  {
    if (is_allowed_volume(v))
    {
      add_volume_full(DejaDup.BackendDrive.get_uuid(v), v.get_name(), v.get_icon());
    }
  }

  uint add_volume_full(string uuid, string name, Icon icon)
  {
    var position = update_volume_full(uuid, name, icon);
    if (position != uint.MAX)
      return position;

    return add_entry_full("drive:" + uuid, icon, name, Group.VOLUMES, "drive");
  }

  void update_volume(VolumeMonitor monitor, Volume v)
  {
    update_volume_full(DejaDup.BackendDrive.get_uuid(v), v.get_name(), v.get_icon());
  }

  uint update_volume_full(string uuid, string name, Icon icon)
  {
    uint position;
    var item = lookup_id("drive", uuid, out position);
    if (item == null)
      return uint.MAX;

    item.icon = icon;
    item.text = name;
    return position;
  }

  void remove_volume(VolumeMonitor monitor, Volume v)
  {
    remove_volume_full(DejaDup.BackendDrive.get_uuid(v));
  }

  void remove_volume_full(string uuid)
  {
    uint position;
    var item = lookup_id("drive", uuid, out position);
    if (item == null)
      return;

    // Make sure it isn't the saved volume; we never want to remove that
    var saved_uuid = drive_settings.get_string(DejaDup.DRIVE_UUID_KEY);
    if (uuid == saved_uuid)
      return;

    store.remove(position);
  }

  // returns saved volume item position, if any
  uint add_saved_volume()
  {
    var uuid = drive_settings.get_string(DejaDup.DRIVE_UUID_KEY);
    if (uuid == "")
      return uint.MAX;

    uint position;
    var item = lookup_id("drive", uuid, out position);
    if (item != null)
      return position;

    Icon vol_icon = null;
    try {
      var icon_string = drive_settings.get_string(DejaDup.DRIVE_ICON_KEY);
      vol_icon = Icon.new_for_string(icon_string);
    }
    catch (Error e) {warning("%s\n", e.message);}

    var vol_name = drive_settings.get_string(DejaDup.DRIVE_NAME_KEY);

    return add_volume_full(uuid, vol_name, vol_icon);
  }

  static bool get_mapping(Value val, Variant variant, void *data)
  {
    var self = (ConfigLocationCombo)data;
    uint position;

    var id = variant.get_string();
    if (id == "drive") {
      position = self.add_saved_volume();
    }
    else if (self.lookup_id(null, id, out position) == null) {
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
      position = self.add_entry_full(id, null, label, Group.CLOUD, "unsupported");
    }

    if (position == uint.MAX)
      return false; // odd - maybe a drive backend, but without a saved uuid?

    val.set_uint(position);
    return true;
  }

  static Variant set_mapping(Value val, VariantType expected_type, void *data)
  {
    var self = (ConfigLocationCombo)data;
    var position = val.get_uint();
    var item = (Item)self.store.get_item(position);
    var id = item.id;

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
    if (combo.selected_item != null)
      stack.visible_child_name = ((Item)combo.selected_item).page;
  }

  void handle_drive_uuid_change()
  {
    var position = add_saved_volume();
    if (position != uint.MAX)
      combo.selected = position;
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
