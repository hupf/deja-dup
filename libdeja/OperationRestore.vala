/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class DejaDup.OperationRestore : Operation
{
  public string dest {get; construct;} // Directory user wants to put files in
  public string tag {get; construct;} // Date user wants to restore to
  public FileTree tree {get; construct;}
  private List<File> _restore_files;
  public List<File> restore_files {
    get {
      return this._restore_files;
    }
    construct {
      this._restore_files = value.copy_deep ((CopyFunc) Object.ref);
    }
  }

  public OperationRestore(Backend backend,
                          string dest_in,
                          FileTree tree,
                          string tag,
                          List<File>? files_in = null) {
    Object(dest: dest_in, tree: tree, tag: tag, restore_files: files_in,
           mode: ToolJob.Mode.RESTORE, backend: backend);
  }

  public async override void start()
  {
    action_desc_changed(_("Restoring files…"));
    yield base.start();
  }

  protected override List<string>? make_argv()
  {
    job.restore_files = restore_files;
    job.tag = tag;
    job.tree = tree;
    job.local = File.new_for_path(dest);
    return null;
  }

  protected override string? get_success_detail()
  {
    string detail = null;

    var error_files = get_local_error_files();
    if (error_files.length() > 0) {
      detail = _("Could not restore the following files.  Please make sure you are able to write to them.");
      detail += "\n";
      foreach (var f in error_files) {
        detail += "\n%s".printf(f);
      }
    }

    return detail;
  }

  internal async override void operation_finished(bool success, bool cancelled)
  {
    if (success && !cancelled)
      DejaDup.update_last_run_timestamp(DejaDup.LAST_RESTORE_KEY);

    yield base.operation_finished(success, cancelled);
  }
}
