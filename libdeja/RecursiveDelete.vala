/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public class RecursiveDelete : RecursiveOp
{
  // skip should probably be an array of files to skip, instead of just a single
  // filename, but since we don't *need* that yet, we don't bother.
  public string? skip {get; construct;}

  // A regex to whitelist which files to delete
  public Regex? only {get; construct;}

  public RecursiveDelete(File source, string? skip=null, Regex? only=null)
  {
    Object(src: source, skip: skip, only: only);
  }

  protected override void handle_file()
  {
    if (only != null && !only.match(src.get_basename(), 0, null))
      return;

    try {
      src.@delete(null);
    }
    catch (Error e) {
      raise_error(src, dst, e.message);
    }
  }

  protected override void finish_dir()
  {
    if (only != null && !only.match(src.get_basename(), 0, null))
      return;

    try {
      src.@delete(null); // will only be deleted if empty, so we won't
                         // accidentally toss files left over from a failed
                         // restore
    }
    catch (Error e) {
      // Ignore.  It's in /tmp, so it'll disappear, and most likely is just
      // a non-empty directory.
    }
  }

  protected override RecursiveOp? clone_for_info(FileInfo info)
  {
    var child_name = info.get_name();
    if (child_name == skip)
      return null;

    var src_child = src.get_child(child_name);
    return new RecursiveDelete(src_child, null, only); // intentionally doesn't pass skip name
  }
}

} // namespace
