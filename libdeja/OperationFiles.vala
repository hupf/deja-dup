/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class DejaDup.OperationFiles : Operation
{
  public signal void listed_current_files(FileTree tree);
  public File? source {get; construct;}
  public string tag {get; construct;}

  private FileTree tree = null;

  public OperationFiles(Backend backend, string tag, File? source = null)
  {
    Object(mode: ToolJob.Mode.LIST, source: source, backend: backend, tag: tag);
  }

  construct {
    tree = new FileTree();
  }

  protected override void connect_to_job()
  {
    job.listed_current_files.connect(handle_list_file);
    base.connect_to_job();
  }

  void handle_list_file(ToolJob job, string file, FileType type)
  {
    tree.add(file, type);
  }

  internal async override void operation_finished(bool success, bool cancelled)
  {
    if (success && !cancelled) {
      tree.finish();
      listed_current_files(tree);
    }
    yield base.operation_finished(success, cancelled);
  }

  protected override List<string>? make_argv()
  {
    job.tag = tag;
    job.local = source;
    return null;
  }
}
