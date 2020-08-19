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
    Object(settings: (settings != null ? settings : get_settings(DRIVE_ROOT)));
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

  Volume get_volume()
  {
    var monitor = DejaDup.get_volume_monitor();
    var uuid = settings.get_string(DRIVE_UUID_KEY);
    return monitor.get_volume_for_uuid(uuid);
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

  protected override File? get_file_from_settings()
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

  public override async bool is_ready(out string when)
  {
    if (get_volume() == null) {
      var name = settings.get_string(DRIVE_NAME_KEY);
      when = _("Backup will begin when %s is connected.").printf(name);
      return false;
    }
    when = null;
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
    if (volume == null)
      return false;

    var folder = mount.get_root().get_relative_path(file);

    settings.delay();
    settings.set_string(DRIVE_UUID_KEY, volume.get_uuid());
    settings.set_string(DRIVE_FOLDER_KEY, folder == null ? "" : folder);
    update_volume_info(volume, settings);
    settings.apply();

    return true;
  }

  public static void update_volume_info(Volume volume, Settings settings)
  {
    var name = volume.get_name();
    var icon = volume.get_icon();

    // sanity check that these writable settings are for this volume
    var vol_uuid = volume.get_uuid();
    var settings_uuid = settings.get_string(DRIVE_UUID_KEY);
    if (vol_uuid != settings_uuid)
      return;

    settings.delay();

    settings.set_string(DRIVE_NAME_KEY, name);
    settings.set_string(DRIVE_ICON_KEY, icon.to_string());

    settings.apply();
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

  async bool mount_internal(Volume vol, bool recurse=true) throws Error
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
      yield delay(1); // Try again in a second
      if (recurse)
        return yield mount_internal(vol, false);
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
      var add_sigid = monitor.volume_added.connect((m, v) => {
        loop.quit();
      });
      var change_sigid = monitor.volume_changed.connect((m, v) => {
        loop.quit();
      });
      loop.run();
      monitor.disconnect(add_sigid);
      monitor.disconnect(change_sigid);
      pause_op(null, null);
      return yield wait_for_volume();
    }

    return vol;
  }
}

} // end namespace
