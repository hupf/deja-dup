/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

/* This is meant to be used right after a successful OperationBackup to
   verify the results. */

public class DejaDup.OperationVerify : Operation
{
  public string tag {get; construct;}
  File metadir;
  File destdir;
  bool nag;

  public OperationVerify(Backend backend, string tag) {
    Object(mode: ToolJob.Mode.RESTORE, backend: backend, tag: tag);
  }

  construct {
    // Should we nag user about password, etc?  What this really means is that
    // we try to do our normal verification routine in as close an emulation
    // to a fresh restore after a disaster as possible.  So fresh cache, no
    // saved password, etc.  We do *not* explicitly unmount the backend,
    // because we may not be the only consumers.
    if (is_nag_time()) {
      use_cached_password = false;
      nag = true;
    }
  }

  public async override void start()
  {
    if (nag) {
      var fake_state = new State();
      fake_state.backend = backend;//.ref() as DejaDup.Backend;
      set_state(fake_state);
    }
    action_desc_changed(_("Verifying backup…"));
    yield base.start();
  }

  protected override void connect_to_job()
  {
    if (nag)
      job.flags |= ToolJob.Flags.NO_CACHE;

    metadir = get_metadir();
    job.restore_files.append(metadir);

    destdir = File.new_for_path("/");
    job.local = destdir;

    job.tag = tag;

    base.connect_to_job();
  }

  internal async override void operation_finished(bool success, bool cancelled, string? detail)
  {
    // Verify results
    if (success) {
      var verified = true;
      string contents;
      try {
        FileUtils.get_contents(Path.build_filename(metadir.get_path(), "README"), out contents);
      }
      catch (Error e) {
        verified = false;
      }

      if (verified) {
        var lines = contents.split("\n");
        verified = (lines[0] == "This folder can be safely deleted.");
      }

      if (!verified) {
        raise_error(_("Your backup appears to be corrupted.  You should delete the backup and try again."), null);
        success = false;
      }

      if (nag)
        update_nag_time();
    }

    new RecursiveDelete(metadir).start();

    yield base.operation_finished(success, cancelled, detail);
  }
}
