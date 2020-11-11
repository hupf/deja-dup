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

} // end namespace
