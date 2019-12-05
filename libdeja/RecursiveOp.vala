/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public abstract class RecursiveOp : Object
{
  public signal void done();
  public signal void raise_error(File src, File dst, string errstr);

  public File src {get; construct;}
  public File dst {get; construct;}

  protected FileType src_type;
  protected FileType dst_type;
  protected virtual void handle_file() {} // src is file
  protected virtual void handle_dir() {} // src is dir
  protected virtual void finish_dir() {} // src is dir we are done with
  protected abstract RecursiveOp? clone_for_info(FileInfo info);

  int refs;

  bool idle_action()
  {
    start_async.begin();
    return false;
  }

  public void start()
  {
    Idle.add(idle_action);
    var loop = new MainLoop(null, false);
    done.connect((m) => {loop.quit();});
    loop.run();
  }

  public async void start_async()
  {
    if (src != null)
      src_type = src.query_file_type(FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
    if (dst != null)
      dst_type = dst.query_file_type(FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);

    switch (src_type) {
    case FileType.DIRECTORY:
      yield do_dir();
      break;
    default:
      handle_file();
      check_ref();
      break;
    }
  }

  void recurse_on_info(FileInfo info)
  {
    add_ref();
    var op = clone_for_info(info);
    if (op == null) {
      remove_ref();
      return;
    }
    op.ref();
    op.done.connect((m) => {remove_ref(); m.unref();});
    op.raise_error.connect((m, s, d, e) => {raise_error(s, d, e);}); // percolate up
    op.start_async.begin();
  }

  const int NUM_ENUMERATED = 16;
  async void do_dir()
  {
    handle_dir();

    // Now descend
    add_ref();
    try {
      var enumerator = yield src.enumerate_children_async(
                         FileAttribute.STANDARD_NAME,
                         FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                         Priority.DEFAULT, null);

      while (true) {
        var infos = yield enumerator.next_files_async(NUM_ENUMERATED,
                                                      Priority.DEFAULT, null);

        foreach (FileInfo info in infos)
          recurse_on_info(info);

        if (infos.length() != NUM_ENUMERATED) {
          remove_ref(); // parent dir itself
          break;
        }
      }
    }
    catch (Error e) {
      raise_error(src, dst, e.message);
      remove_ref(); // parent dir itself
    }
  }

  void add_ref() {
    ++refs;
  }

  void remove_ref() {
    --refs;
    check_ref();
  }

  void check_ref() {
    if (refs == 0) {
      if (src_type == FileType.DIRECTORY)
        finish_dir();
      done();
    }
  }
}

} // namespace
