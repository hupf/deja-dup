/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Canonical Ltd
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class AssistantBackup : AssistantOperation
{
  DejaDup.Backend backend;

  public AssistantBackup(bool automatic)
  {
    Object(automatic: automatic);
  }

  construct
  {
    backend = DejaDup.Backend.get_default();

    title = C_("back up is verb", "Back Up");

    can_resume = true;
    resumed.connect(do_resume);
  }

  protected override string get_apply_text() {
    return C_("back up is verb", "_Back Up");
  }

  protected override DejaDup.Operation? create_op()
  {
    realize();
    var rv = new DejaDup.OperationBackup(backend);

    if (automatic) {
      // If in automatic mode, only use progress if it's a full backup (see below)
      rv.use_progress = false;
    }

    rv.is_full.connect((op, first) => {
      op.use_progress = true;
      set_secondary_label(first ? _("Creating the first backup.  This may take a while.")
                                : _("Creating a fresh backup to protect against backup corruption.  " +
                                    "This will take longer than normal."));

      // Ask user for password if first backup
      if (first)
        ask_passphrase(first);
    });

    if (automatic)
      hide_for_now();
    else
      show_all();

    return rv;
  }

  void do_resume()
  {
    hide_everything();
    if (op != null)
      op.stop();
    else {
      succeeded = true; // fake it
      do_close();
    }
  }

  protected override string get_progress_file_prefix()
  {
    // Translators:  This is the phrase 'Backing up' in the larger phrase
    // "Backing up '%s'".  %s is a filename.
    return _("Backing up:");
  }

  protected override void do_prepare(Assistant assist, Gtk.Widget page)
  {
    base.do_prepare(assist, page);

    if (page == summary_page) {
      if (error_occurred) {
        set_page_title(page, _("Backup Failed"));
      }
      else {
        set_page_title(page, _("Backup Finished"));

        // Also leave ourselves up if we just finished a restore test.
        if (nagged && summary_label.label == "")
          summary_label.label = _("Your files were successfully backed up and tested.");
        // If we don't have a special message to show the user, just bail.
        else if (!detail_widget.get_visible())
          Idle.add(() => {do_close(); return false;});
      }
    }
    else if (page == progress_page) {
      set_page_title(page, _("Backing Up…"));
    }
  }
}
