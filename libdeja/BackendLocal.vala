/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public const string LOCAL_ROOT = "Local";
public const string LOCAL_FOLDER_KEY = "folder";

public class BackendLocal : BackendFile
{
  public BackendLocal(Settings? settings) {
    Object(settings: (settings != null ? settings : get_settings(LOCAL_ROOT)));
  }

  // path may be relative to home or absolute
  public static File? get_file_for_path(string path)
  {
    var root = File.new_for_path(Environment.get_home_dir());

    try {
      return root.get_child_for_display_name(path);
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
  protected override File? get_file_from_settings()
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
}

} // end namespace
