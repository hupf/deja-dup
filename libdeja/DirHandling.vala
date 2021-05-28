/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public string get_trash_path()
{
  return Path.build_filename(Environment.get_user_data_dir(), "Trash");
}

// The path of the canary metadata dir we insert into our backups (with a "README" file)
public File get_metadir()
{
  var cachedir = Environment.get_user_cache_dir();
  var pkgdir = try_realpath(Path.build_filename(cachedir, Config.PACKAGE));
  return File.new_for_path(Path.build_filename(pkgdir, "metadata"));
}

public string? parse_keywords(string dir)
{
  string result = dir;

  // If vala supported a direct map syntax, I'd use that.  But instead, let's
  // use two arrays.
  string[] dirs = { "$DESKTOP", "$DOCUMENTS", "$DOWNLOAD", "$MUSIC",
                    "$PICTURES", "$PUBLIC_SHARE", "$TEMPLATES", "$VIDEOS" };
  UserDirectory[] enums = { UserDirectory.DESKTOP, UserDirectory.DOCUMENTS,
                            UserDirectory.DOWNLOAD, UserDirectory.MUSIC,
                            UserDirectory.PICTURES, UserDirectory.PUBLIC_SHARE,
                            UserDirectory.TEMPLATES, UserDirectory.VIDEOS };
  assert(dirs.length == enums.length);

  // Replace special variables when they are at the start of a larger path
  // The resulting string is an absolute path
  if (result.has_prefix("$HOME"))
    result = result.replace("$HOME", Environment.get_home_dir());
  else if (result.has_prefix("$TRASH"))
    result = result.replace("$TRASH", get_trash_path());
  else {
    for (int i = 0; i < dirs.length; i++) {
      if (result.has_prefix(dirs[i])) {
        var replacement = Environment.get_user_special_dir(enums[i]);
        if (replacement == null)
          return null;
        result = result.replace(dirs[i], replacement);
        break;
      }
    }
  }

  // Some variables can be placed anywhere in the path
  result = result.replace("$USER", Environment.get_user_name());

  // Relative paths are relative to the user's home directory
  if (Uri.parse_scheme(result) == null && !Path.is_absolute(result))
    result = Path.build_filename(Environment.get_home_dir(), result);

  return result;
}

public File remove_read_root(File folder)
{
  var root = InstallEnv.instance().get_read_root();
  if (root == null)
    return folder;

  var relpath = File.new_for_path(root).get_relative_path(folder);
  if (relpath == null)
    return folder;

  return File.new_for_path("/").resolve_relative_path(relpath);
}

public File? parse_dir(string dir)
{
  var result = parse_keywords(dir);
  if (result != null)
    return File.parse_name(result);
  else
    return null;
}

public File[] parse_dir_list(string*[] dirs)
{
  File[] rv = new File[0];

  foreach (string s in dirs) {
    var f = parse_dir(s);
    if (f != null)
      rv += f;
  }

  return rv;
}

void expand_links_in_file(File file, ref List<File> all, bool keep_internal, List<File>? seen = null)
{
  // For symlinks, we want to add the link and its target to the list.
  // This is mostly for the convenience of tools, where we want to back up
  // symlinks and the targets.
  //
  // This will be much easier if we approach it from the root down.  So
  // walk back towards root, keeping track of each piece as we go.
  List<string> pieces = new List<string>();
  File iter = file, parent;
  while ((parent = iter.get_parent()) != null) {
    pieces.prepend(parent.get_relative_path(iter));
    iter = parent;
  }

  try {
    File so_far = File.new_for_path("/");
    foreach (weak string piece in pieces) {
      parent = so_far;
      so_far = parent.resolve_relative_path(piece);
      var info = so_far.query_info(FileAttribute.STANDARD_IS_SYMLINK + "," +
                                   FileAttribute.STANDARD_SYMLINK_TARGET,
                                   FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                                   null);
      if (info.get_is_symlink()) {
        // Check if we've seen this before (i.e. are we in a loop?)
        if (seen.find_custom(so_far, (a, b) => {
              return (a != null && b != null && a.equal(b)) ? 0 : 1;}) != null)
          return; // stop here

        if (keep_internal)
          all.append(so_far); // back up symlink as a leaf element of its path

        // Recurse on the new file (since it could point at a completely
        // new place, which has its own symlinks in its hierarchy, so we need
        // to check the whole thing over again).

        var symlink_target = info.get_symlink_target();
        File full_target;
        if (Path.is_absolute(symlink_target))
          full_target = File.new_for_path(symlink_target);
        else
          full_target = parent.resolve_relative_path(symlink_target);

        // Now add the rest of the undone pieces
        var remaining = so_far.get_relative_path(file);
        if (remaining != null)
          full_target = full_target.resolve_relative_path(remaining);

        if (keep_internal)
          all.remove(file); // may fail if it's not there, which is fine

        seen.prepend(so_far);

        expand_links_in_file(full_target, ref all, keep_internal, seen);
        return;
      }
    }

    // Survived symlink gauntlet, add it to list if this is not the original
    // request (i.e. if this is the final target of a symlink chain)
    if (seen != null)
      all.append(file);
  }
  catch (IOError.NOT_FOUND e) {
    // Don't bother keeping this file in the list
    all.remove(file);
  }
  catch (Error e) {
    warning("%s\n", e.message);
  }
}

void expand_links_in_list(ref List<File> all, bool keep_internal)
{
  var all2 = all.copy();
  foreach (File file in all2)
    expand_links_in_file(file, ref all, keep_internal);
}

} // end namespace
