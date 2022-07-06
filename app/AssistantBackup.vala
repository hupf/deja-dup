/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Canonical Ltd
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class AssistantBackup : AssistantOperation
{
  public bool automatic {get; construct; default = false;}

  public AssistantBackup(bool automatic)
  {
    Object(automatic: automatic);
  }

  construct
  {
    default_title = C_("back up is verb", "Back Up");
    can_resume = true;
  }

  Gtk.Widget include_exclude_page;

  protected override string get_apply_text() {
    return C_("back up is verb", "_Back Up");
  }

  protected override void add_custom_config_pages()
  {
    var settings = DejaDup.get_settings();
    var last_run = settings.get_string(DejaDup.LAST_RUN_KEY);

    // If we've never backed up before, let's prompt for settings
    if (last_run == "") {
      var scroll = new Gtk.ScrolledWindow();
      scroll.child = new ConfigFolderPage();
      append_page(scroll);

      var clamp = new Adw.Clamp();
      clamp.child = new ConfigLocationGroup();
      DejaDup.set_margins(clamp, 12);
      append_page(clamp);
    }
  }

  async string[] get_unavailable_includes()
  {
    string[] unavailable = {};
    var install_env = DejaDup.InstallEnv.instance();
    var settings = DejaDup.get_settings();
    var include_list = settings.get_file_list(DejaDup.INCLUDE_LIST_KEY);
    foreach (var include in include_list) {
      if (!install_env.is_file_available(include))
        unavailable += yield DejaDup.get_nickname(include);
    }
    return unavailable;
  }

  protected override async DejaDup.Operation? create_op()
  {
    // First, check that we aren't trying to back up any unavailable files
    var unavailable = yield get_unavailable_includes();
    if (unavailable.length > 0) {
      var msg = _("The following folders cannot be backed up because Backups does not have access to them:");
      msg += " " + string.joinv(", ", unavailable);
      show_error(msg, null);
      Notifications.backup_finished(this, false, false, null);
      return null;
    }

    var rv = new DejaDup.OperationBackup(DejaDup.Backend.get_default());

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

    return rv;
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
          do_delete();
      }
    }
    else if (page == progress_page) {
      set_page_title(page, _("Backing Up…"));
    }
    else if (page == include_exclude_page) {
      // In the unlikely event the user turned on automatic backups but never
      // made a backup, we should tell them if we start up and need to be
      // configured for first time.
      Notifications.attention_needed(this, _("Backups needs your input to continue"), title);
    }
  }

  protected override void apply_finished(DejaDup.Operation op, bool success, bool cancelled, string? detail)
  {
    Notifications.backup_finished(this, success, cancelled, detail);
    base.apply_finished(op, success, cancelled, detail);
  }

  protected override uint inhibit(Gtk.Application app)
  {
    var flags = Gtk.ApplicationInhibitFlags.SUSPEND;

    // We don't prevent logging out for automatic backups, because they can
    // just be resumed later and weren't triggered by user actions.
    // So they aren't worth preventing the user from doing something and might
    // be a surprising addition to the logout dialog.
    if (!automatic)
      flags |= Gtk.ApplicationInhibitFlags.LOGOUT;

    return app.inhibit(this, flags, _("Backup in progress"));
  }
}
