/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

internal class DejaDup.ToolJobChain : DejaDup.ToolJob
{
  public override async void start() {
    yield start_first();
  }
  public override void cancel() {
    if (current != null)
      current.cancel();
    clear_all();
  }
  public override void stop() {
    if (current != null)
      current.stop();
    clear_all();
  }
  public override void pause(string? reason) {
    if (current != null)
      current.pause(reason);
  }
  public override void resume() {
    if (current != null)
      current.resume();
  }

  // Chain management
  public void prepend_to_chain(ToolJoblet joblet)
  {
    chain.prepend(joblet);
  }
  public void append_to_chain(ToolJoblet joblet)
  {
    chain.append(joblet);
  }

  // Private
  List<ToolJoblet> chain;
  ToolJoblet current;

  void sync_property(ToolJob job, string property)
  {
    bind_property(property, job, property, BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
  }

  void sync_job(ToolJoblet job) // sync data and connect signals
  {
    job.done.connect(handle_done);
    job.raise_error.connect((e, d) => {raise_error(e, d);});
    job.action_desc_changed.connect((a) => {action_desc_changed(a);});
    job.action_file_changed.connect((f, a) => {action_file_changed(f, a);});
    job.progress.connect((p) => {progress(p);});
    job.is_full.connect((f) => {is_full(f);});
    job.bad_encryption_password.connect(() => {bad_encryption_password();});
    job.question.connect((t, m) => {question(t, m);});
    job.collection_dates.connect((d) => {collection_dates(d);});
    job.listed_current_files.connect((f, t) => {listed_current_files(f, t);});

    sync_property(job, "mode");
    sync_property(job, "flags");
    sync_property(job, "local");
    sync_property(job, "backend");
    sync_property(job, "encrypt-password");
    sync_property(job, "tag");
    sync_property(job, "restore-files");
    sync_property(job, "tree");

    // Not actual gobject properties:
    job.includes = includes.copy_deep ((CopyFunc) Object.ref);
    job.includes_priority = includes_priority.copy_deep ((CopyFunc) Object.ref);
    job.excludes = excludes.copy_deep ((CopyFunc) Object.ref);
    job.exclude_regexps = exclude_regexps.copy_deep ((CopyFunc) strdup);

    job.chain = this;
  }

  void clear_current()
  {
    if (current != null) {
      current.chain = null;
    }
    current = null;
  }

  void clear_all()
  {
    clear_current();
    chain = null;
  }

  async void start_first()
  {
    if (chain == null) {
      done(true, false, null);
      return;
    }

    current = chain.data;
    chain.remove_link(chain);

    sync_job(current);
    yield current.start();
  }

  void handle_done(bool success, bool cancelled, string? detail)
  {
    if (success && !cancelled && chain != null) {
      clear_current();
      start_first.begin();
      return;
    }

    done(success, cancelled, detail);
  }
}
