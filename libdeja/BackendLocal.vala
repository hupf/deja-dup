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

  // Get mountable root
  protected override File? get_root_from_settings()
  {
    return File.new_for_path(Environment.get_home_dir());
  }

  // Get full URI to backup folder
  protected override File? get_file_from_settings()
  {
    var root = get_root_from_settings();
    var folder = get_folder_key(settings, LOCAL_FOLDER_KEY, true);

    try {
      return root.get_child_for_display_name(folder);
    } catch (Error e) {
      warning("%s", e.message);
      return null;
    }
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
