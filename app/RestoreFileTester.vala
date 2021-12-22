/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class RestoreFileTester : Object
{
  public static List<string> get_bad_paths(string prefix, DejaDup.FileTree tree,
                                           out bool all_bad, List<File>? files = null)
  {
    all_bad = true;

    // Get all requested file nodes to check (or just the main root if none)
    DejaDup.FileTree.Node[] roots = {};
    foreach (var file in files) {
      var node = tree.file_to_node(file);
      if (node != null)
        roots += node;
    }
    if (files.length() == 0) {
      roots = {tree.root};
    }

    // Now look up each and recurse any children if they exist
    var bad_paths = new List<string>();
    foreach (var node in roots) {
      recurse_node(prefix, tree, node, ref all_bad, ref bad_paths);
    }
    return bad_paths;
  }

  static void recurse_node(string prefix, DejaDup.FileTree tree,
                           DejaDup.FileTree.Node node, ref bool all_bad,
                           ref List<string> bad_paths)
  {
    string resolved;
    if (prefix == "/") { // original location
      resolved = Path.build_filename(prefix, tree.node_to_path(node));
    } else { // just dumping all files directly into 'prefix' folder
      resolved = Path.build_filename(prefix, node.filename);
      prefix = resolved;
    }
    bool exists;
    if (!can_restore(resolved, out exists))
      bad_paths.append(resolved);
    else if (node.kind != FileType.DIRECTORY)
      all_bad = false;
    if (!exists) // no use recursing if the files aren't local
      return;

    foreach (var child in node.children.get_values()) {
      recurse_node(prefix, tree, child, ref all_bad, ref bad_paths);
    }
  }

  static bool can_restore(string path, out bool exists)
  {
    exists = true;
    var fd = Posix.open(path, Posix.O_WRONLY | Posix.O_NONBLOCK | Posix.O_NOFOLLOW);
    if (fd < 0) {
      if (Posix.errno == Posix.EACCES ||
          Posix.errno == Posix.ENOTDIR ||
          Posix.errno == Posix.EPERM ||
          Posix.errno == Posix.EROFS) {
        return false;
      } else if (Posix.errno == Posix.ENOENT) {
        // File doesn't exist -- check if we have write access to nearest existing parent.
        // This isn't entirely accurate -- duplicity will chmod dirs as necessary to make
        // subfolders. So we really want to test that we own the file and/or have write
        // permission. But there's also issues with permissions in containers not being
        // the full story either. So ideally we'd try to chmod the dir and/or create
        // a file in it. But testing write access is probably good enough for now.
        exists = false;
        string iter = path;
        int access = -1;
        while (access != 0 && Posix.errno == Posix.ENOENT) {
          iter = Path.get_dirname(iter);
          access = Posix.euidaccess(iter, Posix.W_OK | Posix.X_OK);
        }
        if (access != 0)
          return false;
      }
    } else {
      Posix.close(fd);
    }

    return true;
  }
}
