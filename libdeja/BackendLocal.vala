/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[CCode (cname = "g_unix_mount_points_get")]
extern List<UnixMountPoint> mount_points_get(out uint64 time_read = null);

namespace DejaDup {

public const string LOCAL_ROOT = "Local";
public const string LOCAL_FOLDER_KEY = "folder";

public class BackendLocal : BackendFile
{
  public BackendLocal(Settings? settings) {
    Object(kind: Kind.LOCAL,
           settings: (settings != null ? settings : get_settings(LOCAL_ROOT)));
  }

  // path may be relative to home or absolute
  public static File? get_file_for_path(string path)
  {
    if (Path.is_absolute(path)) {
      return File.new_for_path(path);
    }

    var root = File.new_for_path(Environment.get_home_dir());

    if (path == "~") {
      return root;
    }

    var child = path;
    if (child.has_prefix("~/")) {
      child = child.substring(2);
    }

    try {
      return root.get_child_for_display_name(child);
    } catch (Error e) {
      warning("%s", e.message);
      return null;
    }
  }

  // returns either an absolute path or a relative one from home
  public static string get_path_from_file(File file)
  {
    var root = File.new_for_path(Environment.get_home_dir());
    var path = root.get_relative_path(file);
    if (path == null)
      return file.get_path();
    return path;
  }

  // Get mountable root
  protected override File? get_root_from_settings()
  {
    return File.new_for_path(Environment.get_home_dir());
  }

  // Get full URI to backup folder
  internal override File? get_file_from_settings()
  {
    var folder = get_folder_key(settings, LOCAL_FOLDER_KEY, true);
    return get_file_for_path(folder);
  }

  public override Icon? get_icon()
  {
    try {
      return Icon.new_for_string("folder");
    }
    catch (Error e) {}

    return null;
  }

  string? get_mount_point()
  {
    var file = get_file_from_settings();
    var points = mount_points_get();
    foreach (unowned UnixMountPoint point in points) {
      if (point.get_mount_path() != "/" &&
          file.has_prefix(File.new_for_path(point.get_mount_path())))
      {
        return point.get_mount_path();
      }
    }
    return null;
  }

  // Yes, this is just a local folder, but it might have an fstab entry and
  // thus be mountable (like pointing at a NAS).
  public override async bool mount() throws Error
  {
    var mount_path = get_mount_point();
    if (mount_path == null)
      return false;

    // Unfortunately, gio does not make this easy for us. It can totally handle
    // unix volumes internally (does it for partitions and the like). But I
    // couldn't find any way to get a Volume for an fstab entry and then mount
    // that through gio. So instead, we call 'mount' ourselves.
    try {
      var process = new Subprocess(SubprocessFlags.NONE, "mount", mount_path);
      yield process.wait_async();
    } catch (Error e) {
      // ignore it, we'll surface an error later
      return false;
    }

    return true;
  }

  protected override async void unmount()
  {
    var mount_path = get_mount_point();
    if (mount_path == null)
      return;

    try {
      var process = new Subprocess(SubprocessFlags.NONE, "umount", mount_path);
      yield process.wait_async();
    } catch (Error e) {
      // ignore it, we'll surface an error later
    }
  }
}

} // end namespace
