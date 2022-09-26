/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public const string DRIVE_ROOT = "Drive";
public const string DRIVE_UUID_KEY = "uuid";
public const string DRIVE_NAME_KEY = "name";
public const string DRIVE_ICON_KEY = "icon";
public const string DRIVE_FOLDER_KEY = "folder";

public class BackendDrive : BackendFile
{
  public BackendDrive(Settings? settings) {
    Object(kind: Kind.LOCAL,
           settings: (settings != null ? settings : get_settings(DRIVE_ROOT)));
  }

  public override async void cleanup()
  {
    // Flush filesystem buffers, just to help guard against the user pulling
    // out the drive as we tell them the backup is finished.
    Posix.sync();
    yield base.cleanup();
  }

  string get_folder()
  {
    return get_folder_key(settings, DRIVE_FOLDER_KEY);
  }

  Volume? get_volume()
  {
    return find_volume(settings.get_string(DRIVE_UUID_KEY));
  }

  protected override File? get_root_from_settings()
  {
    var vol = get_volume();
    if (vol == null)
      return null;
    var mount = vol.get_mount();
    if (mount == null)
      return null;
    return mount.get_root();
  }

  internal override File? get_file_from_settings()
  {
    var root = get_root_from_settings();
    if (root == null)
      return null;
    try {
      return root.get_child_for_display_name(get_folder());
    } catch (Error e) {
      warning("%s", e.message);
      return null;
    }
  }

  public override string get_location_pretty()
  {
    var name = settings.get_string(DRIVE_NAME_KEY);
    var folder = get_folder();
    if (folder == "")
      return name;
    else
      // Translators: %2$s is the name of a removable drive, %1$s is a folder
      // on that removable drive.
      return _("%1$s on %2$s").printf(folder, name);
  }

  public override async bool is_ready(out string reason, out string message)
  {
    if (get_volume() == null) {
      var name = settings.get_string(DRIVE_NAME_KEY);
      reason = "drive-mounted";
      message = _("Backup will begin when %s is connected.").printf(name);
      return false;
    }
    reason = null;
    message = null;
    return true;
  }

  public override Icon? get_icon()
  {
    var icon_name = settings.get_string(DRIVE_ICON_KEY);

    try {
      return Icon.new_for_string(icon_name);
    }
    catch (Error e) {
      warning("%s", e.message);
      return null;
    }
  }

  public static string get_uuid(Volume v)
  {
    // Note that we don't call get_uuid() here. It is usually the same UUID,
    // except in the case of encrypted drives. Where get_uuid() gives you the
    // filesystem UUID of the inner volume, but get_identifier() always gives
    // you the outer volume UUID. Which is what we want to save & watch for.
    return v.get_identifier(VolumeIdentifier.UUID);
  }

  public static Volume? find_volume(string uuid)
  {
    // We don't call get_volume_for_uuid here, because encrypted volumes have
    // two different get_uuid() results, based on whether they are decrypted
    // or not.
    var monitor = DejaDup.get_volume_monitor();
    foreach (var v in monitor.get_volumes()) {
      if (get_uuid(v) == uuid || v.get_uuid() == uuid)
        return v;
    }
    return null;
  }

  public static bool is_allowed_volume(Volume vol)
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

    if (get_uuid(vol) == null)
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
      }
    }

    return false;
  }

  // Returns true if path is a volume path and we changed settings
  public static bool set_volume_info_from_file(File file, Settings settings)
  {
    Mount mount;
    try {
      mount = file.find_enclosing_mount();
    } catch (Error e) {
      return false;
    }

    var volume = mount.get_volume();
    if (volume == null || !is_allowed_volume(volume))
      return false;

    var folder = mount.get_root().get_relative_path(file);

    settings.set_string(DRIVE_UUID_KEY, get_uuid(volume));
    settings.set_string(DRIVE_FOLDER_KEY, folder == null ? "" : folder);
    update_volume_info(volume, settings);

    return true;
  }

  public static void update_volume_info(Volume volume, Settings settings)
  {
    // sanity check that these writable settings are for this volume
    var vol_uuid = get_uuid(volume);
    var fs_uuid = volume.get_uuid(); // not normally used, but just to be permissive
    var settings_uuid = settings.get_string(DRIVE_UUID_KEY);
    if (vol_uuid != settings_uuid && fs_uuid != settings_uuid)
      return;

    // We're updating to vol UUID here in case we are migrating from a past
    // release that set a filesystem UUID. But only do it if we are going to
    // change it, since writing this key notifies BackendWatcher.
    if (settings.get_string(DRIVE_UUID_KEY) != vol_uuid)
      settings.set_string(DRIVE_UUID_KEY, vol_uuid);
    settings.set_string(DRIVE_NAME_KEY, volume.get_name());
    settings.set_string(DRIVE_ICON_KEY, volume.get_icon().to_string());
  }

  async void delay(uint secs)
  {
    var loop = new MainLoop(null);
    Timeout.add_seconds(secs, () => {
      loop.quit();
      return false;
    });
    loop.run();
  }

  async bool mount_internal(Volume vol) throws Error
  {
    // Volumes sometimes return a generic error message instead of
    // IOError.ALREADY_MOUNTED, So let's check manually whether we're mounted.
    if (vol.get_mount() != null)
      return false;

    try {
      yield vol.mount(MountMountFlags.NONE, mount_op, null);
    } catch (IOError.ALREADY_MOUNTED e) {
      return false;
    } catch (IOError.FAILED_HANDLED e) {
      // needed mount_op but none provided
      needed_mount_op();
      return false;
    } catch (IOError.DBUS_ERROR e) {
      // This is not very descriptive, but IOError.DBUS_ERROR is the
      // error given when someone else is mounting at the same time.  Sometimes
      // happens when a USB stick is inserted and nautilus is fighting us.
      yield delay(2); // Try again in a bit
      return yield mount_internal(vol);
    }

    return true;
  }

  protected override async bool mount() throws Error
  {
    var vol = yield wait_for_volume();
    var rv = yield mount_internal(vol);
    update_volume_info(vol, settings);
    return rv;
  }

  async Volume wait_for_volume() throws Error
  {
    var vol = get_volume();
    if (vol == null) {
      var monitor = DejaDup.get_volume_monitor();
      var name = settings.get_string(DRIVE_NAME_KEY);
      pause_op(_("Storage location not available"), _("Waiting for ‘%s’ to become connected…").printf(name));
      var loop = new MainLoop(null, false);
      var sigid = monitor.volume_added.connect((m, v) => {
        loop.quit();
      });
      loop.run();
      monitor.disconnect(sigid);
      pause_op(null, null);
      return yield wait_for_volume();
    }

    return vol;
  }
}

} // end namespace
