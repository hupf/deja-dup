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

  private DateTime time = null;
  private FileTree tree = null;

  public OperationFiles(Backend backend,
                        DateTime? time_in = null,
                        File? source = null) {
    Object(mode: ToolJob.Mode.LIST, source: source, backend: backend);
    if (time_in != null)
        time = time_in;
  }

  construct {
    tree = new FileTree();
  }

  public DateTime get_time()
  {
    return time;
  }

  protected override void connect_to_job()
  {
    job.listed_current_files.connect(handle_list_file);
    base.connect_to_job();
  }

  void handle_list_file(ToolJob job, string date, string file, string type)
  {
    tree.add(file, type);
  }

  internal async override void operation_finished(bool success, bool cancelled, string? detail)
  {
    if (success && !cancelled) {
      tree.finish();
      listed_current_files(tree);
    }
    yield base.operation_finished(success, cancelled, detail);
  }

  protected override List<string>? make_argv()
  {
    if (time != null)
      job.time = time.format("%s");
    else
      job.time = null;
    job.local = source;
    return null;
  }
}
