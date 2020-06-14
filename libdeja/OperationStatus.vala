/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class DejaDup.OperationStatus : Operation
{
  public signal void collection_dates(List<string>? dates);

  public OperationStatus(Backend backend) {
    Object(mode: ToolJob.Mode.STATUS, backend: backend);
  }

  protected override void connect_to_job()
  {
    job.collection_dates.connect((d, dates) => {collection_dates(dates);});
    base.connect_to_job();
  }
}
