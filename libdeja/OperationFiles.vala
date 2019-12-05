/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {
public class OperationFiles : Operation {
  public signal void listed_current_files(string date, string file);
  public File source {get; construct;}

  private DateTime time = null;

  public OperationFiles(Backend backend,
                        DateTime? time_in,
                        File source) {
    Object(mode: ToolJob.Mode.LIST, source: source, backend: backend);
    if (time_in != null)
        time = time_in;
  }

  public DateTime get_time()
  {
    return time;
  }

  protected override void connect_to_job()
  {
    job.listed_current_files.connect((d, date, file) => {listed_current_files(date, file);});
    base.connect_to_job();
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
}
