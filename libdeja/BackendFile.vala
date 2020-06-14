/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public abstract class BackendFile : Backend
{
  bool will_unmount = false;

  public override async void cleanup() {
    // unmount if we originally mounted the backup location
    if (will_unmount) {
      var root = get_root_from_settings();
      try {
        var mount = yield root.find_enclosing_mount_async();
        if (mount != null && mount.can_unmount())
          yield mount.unmount_with_operation(MountUnmountFlags.NONE, null);
      }
      catch (Error e) {
        // ignore
      }
      will_unmount = false;
    }
  }

  public override string[] get_dependencies()
  {
    return Config.GVFS_PACKAGES.split(",");
  }

  // Get mountable root
  public abstract File? get_root_from_settings();

  // Get full URI to backup folder
  protected abstract File? get_file_from_settings();

  // Location will be mounted by this time
  public override string get_location()
  {
    var file = get_file_from_settings();
    if (file == null)
      return "invalid://"; // shouldn't happen!

    return "gio+" + file.get_uri();
  }

  public override string get_location_pretty()
  {
    var file = get_file_from_settings();
    if (file == null)
      return "";
    return get_file_desc(file);
  }

  public override bool is_native() {
    return true;
  }

  // will be mounted by this time
  public override void add_argv(ToolJob.Mode mode, ref List<string> argv)
  {
    if (mode == ToolJob.Mode.BACKUP) {
      var file = get_file_from_settings();
      if (file != null && file.is_native())
        argv.prepend("--exclude=%s".printf(file.get_path()));
    }
  }

  // This doesn't *really* worry about envp, it just is a convenient point to
  // hook into the operation steps to mount the file.
  public override async void get_envp() throws Error
  {
    this.ref();
    try {
      yield do_mount();
    }
    catch (Error e) {
      envp_ready(false, new List<string>(), e.message);
    }
    this.unref();
  }

  async bool query_exists_async(File file)
  {
    try {
      yield file.query_info_async(FileAttribute.STANDARD_TYPE,
                                  FileQueryInfoFlags.NONE,
                                  Priority.DEFAULT, null);
      return true;
    }
    catch (Error e) {
      return false;
    }
  }

  async void do_mount() throws Error
  {
    will_unmount = (yield mount()) || will_unmount;

    var gfile = get_file_from_settings();

    // Ensure directory exists (we check first rather than just doing it,
    // because this makes some backends -- like google-drive: -- work better,
    // as they allow multiple files with the same name. Querying it
    // anchors the path to the backend object and we don't create a second
    // copy this way.
    if (gfile != null && !(yield query_exists_async(gfile))) {
      try {
        gfile.make_directory_with_parents (null);
      }
      catch (IOError.EXISTS err2) {
        // ignore
      }
    }

    envp_ready(true, new List<string>());
  }

  // Returns true if it needed to be mounted, false if already mounted
  public virtual async bool mount() throws Error {return false;}

  public override async uint64 get_space(bool free = true)
  {
    var attr = free ? FileAttribute.FILESYSTEM_FREE : FileAttribute.FILESYSTEM_SIZE;
    try {
      var file = get_file_from_settings();
      if (file == null)
        return INFINITE_SPACE;
      var info = yield file.query_filesystem_info_async(attr, Priority.DEFAULT, null);
      if (!info.has_attribute(attr))
        return INFINITE_SPACE;
      var space = info.get_attribute_uint64(attr);
      if (in_testing_mode() && free &&
          Environment.get_variable("DEJA_DUP_TEST_SPACE_FREE") != null) {
          var free_str = Environment.get_variable("DEJA_DUP_TEST_SPACE_FREE");
          var free_list = free_str.split(";");
          space = uint64.parse(free_list[0]);
          if (free_list[1] != null) {
            var space_free = string.joinv(";", free_list[1:free_list.length]);
            Environment.set_variable("DEJA_DUP_TEST_SPACE_FREE", space_free, true);
          }
      }
      if (space == INFINITE_SPACE)
        return space - 1; // avoid accidentally reporting infinite
      else
        return space;
    }
    catch (Error e) {
      warning("%s\n", e.message);
      return INFINITE_SPACE;
    }
  }
}

} // end namespace
