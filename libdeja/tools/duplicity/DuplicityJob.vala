/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[CCode (cheader_filename = "gpgrt.h", cname = "gpg_err_code_t", cprefix = "GPG_ERR_", has_type_id = false)]
extern enum GPGError {
  NO_SECKEY = 17,
  BAD_KEY = 19,
}

[CCode (cheader_filename = "gpgrt.h")]
extern unowned string gpg_strerror(GPGError code);

internal class DuplicityJob : DejaDup.ToolJob
{
  DejaDup.ToolJob.Mode original_mode {get; private set;}
  bool error_issued {get; private set; default = false;}
  bool was_stopped {get; private set; default = false;}

  protected enum State {
    NOT_STARTED,
    NORMAL,
    DRY_RUN, // used when backing up, and we need to first get time estimate
    STATUS, // used when backing up, and we need to first get collection info
    CLEANUP,
    DELETE,
  }
  protected State state {get; set;}

  DuplicityInstance inst;

  List<string> backend_argv;
  List<string> saved_argv;
  List<string> saved_envp;
  bool is_full_backup = false;
  bool cleaned_up_once = false;
  bool detected_encryption = false;
  bool existing_encrypted = false;

  string last_bad_volume;
  uint bad_volume_count;

  bool has_progress_total = false;
  uint64 progress_total; // zero, unless we already know limit
  uint64 progress_count; // count of how far we are along in the current instance

  static File slash;

  GenericSet<string?> local_error_files = new GenericSet<string?>(str_hash, str_equal);

  bool checked_collection_info = false;
  bool got_collection_info = false;
  struct DateInfo {
    public bool full;
    public DateTime time;
  }
  List<DateInfo?> collection_info = null;

  bool reported_full_backups = false;

  bool checked_backup_space = false;

  const int MINIMUM_FULL = 2;
  bool deleted_files = false;
  int delete_age = 0;

  File last_touched_file = null;
  string forced_cache_dir = null;

  void network_changed()
  {
    if (DejaDup.Network.get().connected)
      resume();
    else
      pause(_("Paused (no network)"));
  }

  construct {
    if (slash == null) {
      slash = File.new_for_path("/");
    }
  }

  ~DuplicityJob() {
    DejaDup.Network.get().notify["connected"].disconnect(network_changed);
  }

  public override void start()
  {
    // save arguments for calling duplicity again later
    if (original_mode == DejaDup.ToolJob.Mode.INVALID)
      original_mode = mode;
    mode = original_mode;
    saved_argv = new List<string>();
    saved_envp = new List<string>();
    backend_argv = new List<string>();
    backend.add_argv(DejaDup.ToolJob.Mode.INVALID, ref backend_argv);
    backend.add_argv(mode, ref saved_argv);

    if (mode == DejaDup.ToolJob.Mode.BACKUP)
      process_include_excludes();

    var settings = DejaDup.get_settings();
    delete_age = settings.get_int(DejaDup.DELETE_AFTER_KEY);

    async_setup.begin();
  }

  async void async_setup()
  {
    /* Fake cache dir if we need to */
    if ((flags & DejaDup.ToolJob.Flags.NO_CACHE) != 0) {
      /* Look like a duplicity tempdir so that clean_tempdirs will clean this for us */
      var template = Path.build_filename(yield DejaDup.get_tempdir(), "duplicity-XXXXXX");
      forced_cache_dir = DirUtils.mkdtemp(template);
    }

    /* Get custom environment from backend, if needed */
    try {
      backend.envp_ready.connect(continue_with_envp);
      yield backend.get_envp();
    }
    catch (Error e) {
      raise_error(e.message, null);
      done(false, false, null);
    }
  }

  void continue_with_envp(DejaDup.Backend b, bool success, List<string>? envp, string? error)
  {
    /*
     * Starts Duplicity backup with added enviroment variables
     *
     * Start Duplicity backup process with costum values for enviroment variables.
     */
    backend.envp_ready.disconnect(continue_with_envp);

    if (!success) {
      if (error != null)
        raise_error(error, null);
      done(false, false, null);
      return;
    }

    if (mode == DejaDup.ToolJob.Mode.INVALID) // already stopped
      return;

    foreach (string s in envp)
      saved_envp.append(s);

    if (!restart())
      done(false, false, null);

    if (!backend.is_native()) {
      DejaDup.Network.get().notify["connected"].connect(network_changed);
      if (!DejaDup.Network.get().connected) {
        debug("No connection found. Postponing the backup.");
        pause(_("Paused (no network)"));
      }
    }
  }

  // This will treat a < b iff a is 'lower' in the file tree than b
  int cmp_prefix(File? a, File? b)
  {
    if (a == null && b == null)
      return 0;
    else if (b == null || a.has_prefix(b))
      return -1;
    else if (a == null || b.has_prefix(a))
      return 1;
    else
      return 0;
  }

  string get_remote(DejaDup.Backend? backend_override = null)
  {
    if (backend_override == null)
      backend_override = backend;
    return backend_override.get_location();
  }

  void expand_links_in_file(File file, ref List<File> all, bool include, List<File>? seen = null)
  {
    // For symlinks, we want to add the link and its target to the list.
    // Normally, duplicity ignores targets, and this is fine and expected
    // behavior.  But if the user explicitly requested a directory with a
    // symlink in it's path, they expect a follow-through.
    // If a symlink is anywhere above the directory specified by the user,
    // duplicity will stop at that symlink and only backup the broken link.
    // So we try to work around that behavior by checking for symlinks and only
    // passing duplicity symlinks as leaf elements.
    //
    // This will be much easier if we approach it from the root down.  So
    // walk back towards root, keeping track of each piece as we go.
    List<string> pieces = new List<string>();
    File iter = file, parent;
    while ((parent = iter.get_parent()) != null) {
      pieces.prepend(parent.get_relative_path(iter));
      iter = parent;
    }

    try {
      File so_far = slash;
      foreach (weak string piece in pieces) {
        parent = so_far;
        so_far = parent.resolve_relative_path(piece);
        var info = so_far.query_info(FileAttribute.STANDARD_IS_SYMLINK + "," +
                                     FileAttribute.STANDARD_SYMLINK_TARGET,
                                     FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                                     null);
        if (info.get_is_symlink()) {
          // Check if we've seen this before (i.e. are we in a loop?)
          if (seen.find_custom(so_far, (a, b) => {
                return (a != null && b != null && a.equal(b)) ? 0 : 1;}) != null)
            return; // stop here

          if (include)
            all.append(so_far); // back up symlink as a leaf element of its path

          // Recurse on the new file (since it could point at a completely
          // new place, which has its own symlinks in its hierarchy, so we need
          // to check the whole thing over again).

          var symlink_target = info.get_symlink_target();
          File full_target;
          if (Path.is_absolute(symlink_target))
            full_target = File.new_for_path(symlink_target);
          else
            full_target = parent.resolve_relative_path(symlink_target);

          // Now add the rest of the undone pieces
          var remaining = so_far.get_relative_path(file);
          if (remaining != null)
            full_target = full_target.resolve_relative_path(remaining);

          if (include)
            all.remove(file); // may fail if it's not there, which is fine

          seen.prepend(so_far);

          expand_links_in_file(full_target, ref all, include, seen);
          return;
        }
      }

      // Survived symlink gauntlet, add it to list if this is not the original
      // request (i.e. if this is the final target of a symlink chain)
      if (seen != null)
        all.append(file);
    }
    catch (IOError.NOT_FOUND e) {
      // Don't bother keeping this file in the list
      all.remove(file);
    }
    catch (Error e) {
      warning("%s\n", e.message);
    }
  }

  void expand_links_in_list(ref List<File> all, bool include)
  {
    var all2 = all.copy();
    foreach (File file in all2)
      expand_links_in_file(file, ref all, include);
  }

  string escape_duplicity_path(string path)
  {
    // Duplicity paths are actually shell globs.  So we want to escape anything
    // that might fool duplicity into thinking this isn't the real path.
    // Specifically, anything in '[?*'.  Duplicity does not have escape
    // characters, so we surround each with brackets.
    string rv;
    rv = path.replace("[", "[[]");
    rv = rv.replace("?", "[?]");
    rv = rv.replace("*", "[*]");
    return rv;
  }

  void process_include_excludes()
  {
    expand_links_in_list(ref includes, true);
    expand_links_in_list(ref excludes, false);

    // We need to make sure that the most specific includes/excludes will
    // be first in the list (duplicity uses only first matched dir).  Includes
    // will be preferred if the same dir is present in both lists.
    includes.sort((CompareFunc)cmp_prefix);
    excludes.sort((CompareFunc)cmp_prefix);

    var excludes2 = excludes.copy();
    foreach (File i in includes) {
      foreach (File e in excludes2.copy()) {
        if (e.has_prefix(i)) {
          saved_argv.append("--exclude=" + escape_duplicity_path(e.get_path()));
          excludes2.remove(e);
        }
      }
      saved_argv.append("--include=" + escape_duplicity_path(i.get_path()));
    }
    foreach (File e in excludes2) {
      saved_argv.append("--exclude=" + escape_duplicity_path(e.get_path()));
    }

    // TODO: Figure out a more reasonable way to order regexps and files.
    // For now, just stick regexps in the end, as they are more general.
    foreach (string r in exclude_regexps) {
      saved_argv.append("--exclude=" + r);
    }

    saved_argv.append("--exclude=**");
    saved_argv.append("--exclude-if-present=CACHEDIR.TAG");
    saved_argv.append("--exclude-if-present=.deja-dup-ignore");
  }

  public override void cancel() {
    var prev_mode = mode;
    mode = DejaDup.ToolJob.Mode.INVALID;

    if (prev_mode == DejaDup.ToolJob.Mode.BACKUP && state == State.NORMAL) {
      if (cleanup())
        return;
    }

    cancel_inst();
  }

  public override void stop() {
    // just abruptly stop, without a cleanup, duplicity will resume
    was_stopped = true;
    mode = DejaDup.ToolJob.Mode.INVALID;
    cancel_inst();
  }

  public override void pause(string? reason)
  {
    if (inst != null) {
      inst.pause();
      if (reason != null)
        set_status(reason, false);
    }
  }

  public override void resume()
  {
    if (inst != null) {
      inst.resume();
      set_saved_status();
    }
  }

  void cancel_inst()
  {
    disconnect_inst();
    handle_done(null, false, true);
  }

  bool restart()
  {
    state = State.NORMAL;
    if (restore_files == null) // only clear if we're not in middle of restore sequence
      local_error_files.remove_all();

    if (mode == DejaDup.ToolJob.Mode.INVALID)
      return false;

    var extra_argv = new List<string>();
    string action_desc = null;
    File custom_local = null;

    switch (original_mode) {
    case DejaDup.ToolJob.Mode.BACKUP:
      // We need to first check the backup status to see if we need to start
      // a full backup and to see if we should use encryption.
      if (!checked_collection_info) {
        mode = DejaDup.ToolJob.Mode.STATUS;
        state = State.STATUS;
        action_desc = _("Preparing…");
      }
      else if (!reported_full_backups && got_collection_info) {
        report_full_backups.begin();
        return true;
      }
      // If we're backing up, and the version of duplicity supports it, we should
      // first run using --dry-run to get the total size of the backup, to make
      // accurate progress bars.
      else if ((flags & DejaDup.ToolJob.Flags.NO_PROGRESS) == 0 && !has_progress_total) {
        state = State.DRY_RUN;
        action_desc = _("Preparing…");
        extra_argv.append("--dry-run");
      }
      else if (!checked_backup_space) {
        check_backup_space.begin();
        return true;
      }
      else {
        if (has_progress_total)
          progress(0f);
        if (is_full_backup) {
          // Make sure duplicity has to verify new password against the
          // existing backup files by deleting any local manifests.
          // Duplicity will re-download and re-decrypt them with the
          // currently provided passphrase.
          // This avoids a duplicity bug/feature(?) where you can have
          // different passphrases for each full backup chain, as long
          // as you never re-download past metadata.
          // https://bugs.launchpad.net/duplicity/+bug/918489
          try {
            delete_cache(new Regex("^duplicity-full\\..*\\.manifest$", 0, 0));
          }
          catch (Error e) {
            warning("%s\n", e.message);
          }
        }
      }

      break;

    case DejaDup.ToolJob.Mode.RESTORE:
      // We need to first check the backup status to see if we should use
      // encryption.
      if (!checked_collection_info) {
        mode = DejaDup.ToolJob.Mode.STATUS;
        state = State.STATUS;
        action_desc = _("Preparing…");
      }
      else {
        // If the tree has recorded an old home for the user, let's tell
        // duplicity to also rename to our new home.
        if (tree != null && tree.old_home != null) {
          var old_home = File.new_for_path(tree.old_home);
          var new_home = File.new_for_path(Environment.get_home_dir());
          extra_argv.append("--rename");
          extra_argv.append(slash.get_relative_path(old_home));
          extra_argv.append(slash.get_relative_path(new_home));
        }

        if (restore_files != null) {
          // Just do first one.  Others will come when we're done

          // make path to specific restore file, since duplicity will just
          // drop the file exactly where you ask it
          var local_file = make_local_rel_path(restore_files.data);
          try {
            // won't have correct permissions...
            local_file.get_parent().make_directory_with_parents(null);
          }
          catch (IOError.EXISTS e) {
            // ignore
          }
          catch (Error e) {
            show_error(e.message);
            return false;
          }
          custom_local = local_file;

          var target_file = restore_files.data;
          if (tree != null) {
            var translated_path = tree.original_path(target_file.get_path());
            target_file = File.new_for_path(translated_path);
          }
          var rel_file_path = slash.get_relative_path(target_file);
          extra_argv.append("--file-to-restore=%s".printf(rel_file_path));
        }

        progress(0f);
      }
      break;

    default:
      break;
    }

    // Send appropriate description for what we're about to do.  Is often
    // very quickly overridden by a message like "Backing up file X"
    if (action_desc == null)
      action_desc = DejaDup.Operation.mode_to_string(mode);
    set_status(action_desc);

    connect_and_start(extra_argv, null, null, custom_local);
    return true;
  }

  File make_local_rel_path(File file)
  {
    if (local.get_parent() == null)
      return file; // original locations, leave file alone
    else
      return local.get_child(file.get_basename());
  }

  async void report_full_backups()
  {
    DateTime full_backup = null;
    foreach (DateInfo info in collection_info) {
      if (info.full)
        full_backup = info.time;
    }
    var first_backup = full_backup == null;

    var do_restart = true;
    reported_full_backups = true; // don't do this a second time

    // Set full backup threshold and determine whether we should trigger
    // a full backup.
    var threshold = DejaDup.get_full_backup_threshold_date();
    if (full_backup == null || threshold.compare(full_backup) > 0) {
      is_full_backup = true;
      is_full(first_backup);
    }

    if (do_restart && !restart())
      done(false, false, null);
  }

  async void check_backup_space()
  {
    checked_backup_space = true;

    if (!has_progress_total) {
      if (!restart())
        done(false, false, null);
      return;
    }

    var formatted_progress_total = format_size(progress_total);
    var free = yield backend.get_space();
    var total = yield backend.get_space(false);
    // Sanity check total here, plus this can actually happen if an overflow
    // occurs (GNOME bug 786177).
    if (free != DejaDup.Backend.INFINITE_SPACE && free > total)
      total = free;
    if (total < progress_total) {
        // Tiny backup location.  Suggest they get a larger one.
        var msg = _("Backup location is too small. Try using one with at least %s.");
        show_error(msg.printf(formatted_progress_total));
        done(false, false, null);
        return;
    }

    if (free < progress_total) {
      if (got_collection_info) {
        // Alright, let's look at collection data
        int full_dates = 0;
        foreach (DateInfo info in collection_info) {
          if (info.full)
            ++full_dates;
        }

        if (full_dates > 1) {
          delete_excess(full_dates - 1);
          // don't set checked_backup_space, we want to be able to do this again if needed
          checked_backup_space = false;
          checked_collection_info = false; // get info again
          got_collection_info = false;
          return;
        }
      }
      else {
        var msg = _("Backup location does not have enough free space. Try using one with at least %s.");
        show_error(msg.printf(formatted_progress_total));
        done(false, false, null);
        return;
      }
    }

    if (!restart())
      done(false, false, null);
  }

  bool cleanup() {
    if (state == State.CLEANUP)
      return false;

    state = State.CLEANUP;
    var cleanup_argv = new List<string>();
    cleanup_argv.append("cleanup");
    cleanup_argv.append("--force");
    cleanup_argv.append(get_remote());

    set_status(_("Cleaning up…"));
    connect_and_start(null, null, cleanup_argv);

    return true;
  }

  void delete_excess(int cutoff, DejaDup.Backend? backend_override = null) {
    state = State.DELETE;
    var argv = new List<string>();
    argv.append("remove-all-but-n-full");
    argv.append("%d".printf(cutoff));
    argv.append("--force");
    argv.append(get_remote(backend_override));

    set_status(_("Cleaning up…"));
    connect_and_start(null, null, argv);

    return;
  }

  bool can_ignore_error()
  {
    // Ignore errors during cleanup.  If they're real, they'll repeat.
    // They might be not-so-real, like the errors one gets when restoring
    // from a backup when not all of the signature files are in your archive
    // dir (which happens when you start using an archive dir in the middle
    // of a backup chain).
    return state == State.CLEANUP;
  }

  List<unowned string> get_sorted_local_error_files()
  {
    var error_files = local_error_files.get_values();
    error_files.sort(strcmp);
    return error_files;
  }

  void handle_done(DuplicityInstance? inst, bool success, bool cancelled)
  {
    string detail = null;

    if (can_ignore_error())
      success = true;

    if (!cancelled && success) {
      switch (state) {
      case State.DRY_RUN:
        has_progress_total = true;
        progress_total = progress_count; // save max progress for next run
        if (restart())
          return;
        break;

      case State.DELETE:
        if (restart()) // In case we were interrupting normal flow
          return;
        break;

      case State.CLEANUP:
        cleaned_up_once = true;
        if (restart()) // restart in case cleanup was interrupting normal flow
          return;

        // Else, we probably started cleaning up after a cancel.  Just continue
        // that cancels
        success = false;
        cancelled = true;
        break;

      case State.STATUS:
        checked_collection_info = true;
        var should_restart = mode != original_mode;
        mode = original_mode;

        if (should_restart) {
          if (restart())
            return;
        }
        break;

      case State.NORMAL:
        if (mode == DejaDup.ToolJob.Mode.RESTORE && restore_files != null) {
          _restore_files.delete_link(_restore_files);
          if (restore_files != null) {
            if (restart())
              return;
          }
        }

        if (mode == DejaDup.ToolJob.Mode.BACKUP) {
          if (local_error_files.length > 0) {
            // OK, we succeeded yay!  But some files didn't make it into the backup
            // because we couldn't read them.  So tell the user so they don't think
            // everything is hunky dory.
            detail = _("Could not back up the following files.  Please make sure you are able to open them.");
            detail += "\n";
            foreach (var f in get_sorted_local_error_files()) {
              detail += "\n%s".printf(f);
            }
          }

          mode = DejaDup.ToolJob.Mode.INVALID; // mark 'done' so when we delete, we don't restart
          if (delete_files_if_needed())
            return;
        }
        else if (mode == DejaDup.ToolJob.Mode.RESTORE) {
          if (local_error_files.length > 0) {
            // OK, we succeeded yay!  But some files didn't actually restore
            // because we couldn't write to them.  So tell the user so they
            // don't think everything is hunky dory.
            detail = _("Could not restore the following files.  Please make sure you are able to write to them.");
            detail += "\n";
            foreach (var f in get_sorted_local_error_files()) {
              detail += "\n%s".printf(f);
            }
          }
        }
        break;

      case NOT_STARTED:
        break;
      }
    }
    else if (was_stopped)
      success = true; // we treat stops as success

    if (error_issued)
      success = false;

    if (!success && !cancelled && !error_issued)
      show_error(_("Failed with an unknown error."));

    inst = null;
    done(success, cancelled, detail);
  }

  string saved_status;
  File saved_status_file;
  bool saved_status_file_action;
  void set_status(string msg, bool save = true)
  {
    if (save) {
      saved_status = msg;
      saved_status_file = null;
    }
    action_desc_changed(msg);
  }

  void set_status_file(File file, bool action, bool save = true)
  {
    if (save) {
      saved_status = null;
      saved_status_file = file;
      saved_status_file_action = action;
    }
    action_file_changed(file, action);
  }

  void set_saved_status()
  {
    if (saved_status != null)
      set_status(saved_status, false);
    else
      set_status_file(saved_status_file, saved_status_file_action, false);
  }

  // Should only be called *after* a successful backup
  bool delete_files_if_needed()
  {
    if (delete_age == 0) {
      deleted_files = true;
      return false;
    }

    // Check if we need to delete any backups
    // If we got collection info, examine it to see if we should delete old
    // files.
    if (got_collection_info && !deleted_files) {
      // Alright, let's look at collection data
      int full_dates = 0;
      int too_old = 0;
      DateTime today = new DateTime.now_local();
      DateTime prev_time = null;

      foreach (DateInfo info in collection_info) {
        if (info.full) {
          if (prev_time != null && today.difference(prev_time) / TimeSpan.DAY > delete_age)
            ++too_old;
          ++full_dates;
        }
        prev_time = info.time;
      }
      if (prev_time != null && today.difference(prev_time) / TimeSpan.DAY > delete_age)
        ++too_old;

      // Did we just finished a successful full backup?
      // Collection info won't have our recent backup, because it is done at
      // beginning of backup.
      if (is_full_backup)
        ++full_dates;

      if (too_old > 0 && full_dates > MINIMUM_FULL) {
        // Alright, let's delete those ancient files!
        int cutoff = int.max(MINIMUM_FULL, full_dates - too_old);
        delete_excess(cutoff);
        return true;
      }

      // If we don't need to delete, pretend we did and move on.
      deleted_files = true;
      return false;
    }
    else
      return false;
  }

  protected const int ERROR_GENERIC = 1;
  protected const int ERROR_HOSTNAME_CHANGED = 3;
  protected const int ERROR_RESTORE_DIR_NOT_FOUND = 19;
  protected const int ERROR_EXCEPTION = 30;
  protected const int ERROR_GPG = 31;
  protected const int ERROR_BAD_VOLUME = 44;
  protected const int ERROR_BACKEND = 50;
  protected const int ERROR_BACKEND_PERMISSION_DENIED = 51;
  protected const int ERROR_BACKEND_NOT_FOUND = 52;
  protected const int ERROR_BACKEND_NO_SPACE = 53;
  protected const int INFO_PROGRESS = 2;
  protected const int INFO_COLLECTION_STATUS = 3;
  protected const int INFO_DIFF_FILE_NEW = 4;
  protected const int INFO_DIFF_FILE_CHANGED = 5;
  protected const int INFO_DIFF_FILE_DELETED = 6;
  protected const int INFO_PATCH_FILE_WRITING = 7;
  protected const int INFO_PATCH_FILE_PATCHING = 8;
  protected const int INFO_FILE_STAT = 10;
  protected const int INFO_SYNCHRONOUS_UPLOAD_BEGIN = 11;
  protected const int INFO_ASYNCHRONOUS_UPLOAD_BEGIN = 12;
  protected const int INFO_SYNCHRONOUS_UPLOAD_DONE = 13;
  protected const int INFO_ASYNCHRONOUS_UPLOAD_DONE = 14;
  protected const int WARNING_ORPHANED_SIG = 2;
  protected const int WARNING_UNNECESSARY_SIG = 3;
  protected const int WARNING_UNMATCHED_SIG = 4;
  protected const int WARNING_INCOMPLETE_BACKUP = 5;
  protected const int WARNING_ORPHANED_BACKUP = 6;
  protected const int WARNING_CANNOT_STAT = 9;
  protected const int WARNING_CANNOT_READ = 10;
  protected const int WARNING_CANNOT_PROCESS = 12; // basically, cannot write or change attrs
  protected const int DEBUG_GENERIC = 1;

  void delete_cache(Regex? only=null)
  {
    string dir = Environment.get_user_cache_dir();
    if (dir == null)
      return;

    var cachedir = Path.build_filename(dir, Config.PACKAGE);
    var del = new DejaDup.RecursiveDelete(File.new_for_path(cachedir), "metadata", only);
    del.start();
  }

  bool restarted_without_cache = false;
  bool restart_without_cache()
  {
    if (restarted_without_cache)
      return false;

    restarted_without_cache = true;

    delete_cache();
    return restart();
  }

  void handle_exit(int code)
  {
    // Duplicity has a habit of dying and returning 1 without sending an error
    // if there was some unexpected issue with its cached metadata.  It often
    // goes away if you delete ~/.cache/deja-dup and try again.  This issue
    // happens often enough that we do that for the user here.  It should be
    // safe to do this, as the cache is not necessary for operation, only
    // a performance improvement.
    if (code == ERROR_GENERIC && !error_issued) {
      restart_without_cache();
    }
  }

  void handle_message(DuplicityInstance inst, string[] control_line,
                      List<string>? data_lines, string user_text)
  {
    /*
     * Based on duplicity's output handle message as either process data as error, info or warning
     */
    if (control_line.length == 0)
      return;

    var keyword = control_line[0];
    switch (keyword) {
    case "ERROR":
      process_error(control_line, data_lines, user_text);
      break;
    case "INFO":
      process_info(control_line, data_lines, user_text);
      break;
    case "WARNING":
      process_warning(control_line, data_lines, user_text);
      break;
    }
  }

  bool ask_question(string t, string m)
  {
    disconnect_inst();
    question(t, m);
    var rv = mode != DejaDup.ToolJob.Mode.INVALID; // return whether we were canceled
    if (!rv)
      handle_done(null, false, true);
    return rv;
  }

  // Hacky function to return later parts of a duplicity filename.
  // Used to chop off the date bit
  string parse_duplicity_file(string file, int skip_bits)
  {
    int next = 0;
    while (skip_bits-- > 0 && next >= 0)
      next = file.index_of_char('.', next) + 1;
    if (next < 0)
      return "";
    else
      return file.substring(next);
  }

  void report_encryption_error()
  {
    bad_encryption_password(); // notify upper layers, if they want to do anything
    show_error(_("Bad encryption password."));
  }

  bool check_encryption_error(string text)
  {
    // GPG does not expose the true reason in a machine-readable way for duplicity
    // to pass on.  So we try to find out why it failed by looking for the
    // "bad session key" error message that is given if the password was incorrect.
    // Any other error should be presented to the user so they can maybe fix it
    // (bad configuration files or something).
    var no_seckey_msg = gpg_strerror(GPGError.NO_SECKEY);
    var bad_key_msg = gpg_strerror(GPGError.BAD_KEY);
    if (text.contains(no_seckey_msg) || text.contains(bad_key_msg)) {
      report_encryption_error();
      return true;
    }

    return false;
  }

  protected virtual void process_error(string[] firstline, List<string>? data,
                                       string text_in)
  {
    string text = text_in;

    if (can_ignore_error())
      return;

    if (firstline.length > 1) {
      switch (int.parse(firstline[1])) {

      case ERROR_GENERIC:
        if (text.contains("GnuPG") && check_encryption_error(text))
          return;
        break;

      case ERROR_EXCEPTION: // exception
        process_exception(firstline.length > 2 ? firstline[2] : "", text);
        return;

      case ERROR_RESTORE_DIR_NOT_FOUND:
        // make text a little nicer than duplicity gives
        // duplicity gives something like "home/blah/blah not found in archive,
        // no files restored".
        if (restore_files != null)
          text = _("Could not restore ‘%s’: File not found in backup").printf(
                   restore_files.data.get_parse_name());
        break;

      case ERROR_GPG:
        if (check_encryption_error(text_in))
          return;
        break;

      case ERROR_HOSTNAME_CHANGED:
        if (firstline.length >= 4) {
          var msg = _("The existing backup is of a computer named %s, but the " +
                      "current computer’s name is %s.  If this is unexpected, " +
                      "you should back up to a different location.");
          if (!ask_question(_("Computer name changed"), msg.printf(firstline[3], firstline[2])))
            return;
        }
        // Else just assume that user wants to allow the mismatch...
        // A little troubling but better than not letting user proceed
        saved_argv.append("--allow-source-mismatch");
        if (restart())
          return;
        break;

      case ERROR_BAD_VOLUME:
        // A volume was detected to be corrupt/incomplete after uploading.
        // We'll first try a restart because then duplicity will retry it.
        // If it's still bad, we'll do a full cleanup and try again.
        // If it's *still* bad, tell the user, but I'm not sure what they can
        // do about it.
        if (mode == DejaDup.ToolJob.Mode.BACKUP) {
          // strip date info from volume (after cleanup below, we'll get new date)
          var this_volume = parse_duplicity_file(firstline[2], 2);
          if (last_bad_volume != this_volume) {
            bad_volume_count = 0;
            last_bad_volume = this_volume;
          }

          if ((bad_volume_count == 0 && restart()) ||
              (bad_volume_count == 1 && cleanup())) {
            bad_volume_count += 1;
            return;
          }
        }
        break;

      case ERROR_BACKEND_PERMISSION_DENIED:
        if (firstline.length >= 5 && firstline[2] == "put") {
          var file = make_file_obj(firstline[4]);
          text = _("Permission denied when trying to create ‘%s’.").printf(file.get_parse_name());
        }
        if (firstline.length >= 5 && firstline[2] == "get") {
          var file = make_file_obj(firstline[3]); // assume error is on backend side
          text = _("Permission denied when trying to read ‘%s’.").printf(file.get_parse_name());
        }
        else if (firstline.length >= 4 && firstline[2] == "list") {
          var file = make_file_obj(firstline[3]);
          text = _("Permission denied when trying to read ‘%s’.").printf(file.get_parse_name());
        }
        else if (firstline.length >= 4 && firstline[2] == "delete") {
          var file = make_file_obj(firstline[3]);
          text = _("Permission denied when trying to delete ‘%s’.").printf(file.get_parse_name());
        }
        break;

      case ERROR_BACKEND_NOT_FOUND:
        if (firstline.length >= 4) {
          var file = make_file_obj(firstline[3]);
          text = _("Backup location ‘%s’ does not exist.").printf(file.get_parse_name());
        }
        break;

      case ERROR_BACKEND_NO_SPACE:
        if (firstline.length >= 5) {
          text = _("No space left.");
        }
        break;
      }
    }

    show_error(text);
  }

  void process_exception(string exception, string text)
  {
    switch (exception) {
    case "EOFError":
      // Duplicity tried to ask the user what the encryption password is.
      report_encryption_error();
      break;
    case "IOError":
      if (text.contains("GnuPG"))
        report_encryption_error();
      else if (text.contains("[Errno 5]") && // I/O Error
               last_touched_file != null) {
        if (mode == DejaDup.ToolJob.Mode.BACKUP)
          show_error(_("Error reading file ‘%s’.").printf(last_touched_file.get_parse_name()));
        else
          show_error(_("Error writing file ‘%s’.").printf(last_touched_file.get_parse_name()));
      }
      else if (text.contains("[Errno 28]")) { // No space left on device
        string where = null;
        if (mode == DejaDup.ToolJob.Mode.BACKUP)
          where = backend.get_location_pretty();
        else
          where = local.get_path();
        if (where == null)
          show_error(_("No space left."));
        else
          show_error(_("No space left in ‘%s’.").printf(where));
      }
      else if (text.contains("CRC check failed")) { // bug 676767
        if (restart_without_cache())
          return;
      }
      break;
    case "CollectionsError":
      show_error(_("No backup files found"));
      break;
    case "AssertionError":
      // This is an internal error.  Similar to when duplicity just returns
      // 1 with no message.  Some of these, like "time not moving forward" or
      // bug 877631, can be recovered from by clearing the cache.  Worth a
      // shot.
      if (restart_without_cache())
        return;
      break;
    }

    // For most, don't do anything special.  Show generic 'unknown error'
    // message, but provide the exception text for better bug reports.
    // Plus, sometimes it may clue the user in to what's wrong.
    // But first, try to restart without a cache, since that seems to quite
    // frequently fix odd metadata errors with duplicity.  If we hit an error
    // a second time, we'll show the unknown error message.
    if (!error_issued && !restart_without_cache())
      show_error(_("Failed with an unknown error."), text);
  }

  protected virtual void process_info(string[] firstline, List<string>? data,
                                      string text)
  {
    /*
     * Pass message to appropriate function considering the type of output
     */
    if (firstline.length > 1) {
      switch (int.parse(firstline[1])) {
      case INFO_DIFF_FILE_NEW:
      case INFO_DIFF_FILE_CHANGED:
      case INFO_DIFF_FILE_DELETED:
        if (firstline.length > 2)
          process_diff_file(firstline[2]);
        break;
      case INFO_PATCH_FILE_WRITING:
      case INFO_PATCH_FILE_PATCHING:
        if (firstline.length > 2)
          process_patch_file(firstline[2]);
        break;
      case INFO_PROGRESS:
        process_progress(firstline);
        break;
      case INFO_COLLECTION_STATUS:
        process_collection_status(data);
        break;
      case INFO_SYNCHRONOUS_UPLOAD_BEGIN:
      case INFO_ASYNCHRONOUS_UPLOAD_BEGIN:
        if (!backend.is_native())
          set_status(_("Uploading…"));
        break;
      case INFO_FILE_STAT:
        process_file_stat(firstline[2], firstline[3], firstline[4], data, text);
        break;
      }
    }
  }

  void process_file_stat(string date, string file, string type, List<string> data, string text)
  {
    if (mode != DejaDup.ToolJob.Mode.LIST)
      return;
    if (file == ".")
      return;
    listed_current_files(date, file, type);
  }

  void process_diff_file(string file) {
    var gfile = make_file_obj(file);
    last_touched_file = gfile;
    if (gfile.query_file_type(FileQueryInfoFlags.NONE, null) != FileType.DIRECTORY)
      set_status_file(gfile, state != State.DRY_RUN);
  }

  void process_patch_file(string file) {
    var gfile = make_file_obj(file);
    last_touched_file = gfile;
    if (gfile.query_file_type(FileQueryInfoFlags.NONE, null) != FileType.DIRECTORY)
      set_status_file(gfile, state != State.DRY_RUN);
  }

  void process_progress(string[] firstline)
  {
    double total;

    if (firstline.length > 2)
      this.progress_count = uint64.parse(firstline[2]);
    else
      return;

    if (firstline.length > 3)
      total = double.parse(firstline[3]);
    else if (this.progress_total > 0)
      total = this.progress_total;
    else
      return; // can't do progress without a total

    double percent = (double)this.progress_count / total;
    if (percent > 1)
      percent = 1;
    if (percent < 0) // ???
      percent = 0;
    progress(percent);
  }

  File make_file_obj(string file)
  {
    // All files are relative to root.
    return slash.resolve_relative_path(file);
  }

  void process_collection_status(List<string>? lines)
  {
    /*
     * Collect output of collection status and return list of dates as strings via a signal
     *
     * Duplicity returns collection status as a bunch of lines, some of which are
     * indented which contain information about specific chains. We gather
     * this all up and report back to caller via a signal.
     * We're really only interested in the list of entries in the complete chain.
     */
    if (mode != DejaDup.ToolJob.Mode.STATUS || got_collection_info)
      return;

    var dates = new List<string>();
    var infos = new List<DateInfo?>();
    bool in_chain = false;
    foreach (string line in lines) {
      if (line == "chain-complete" || line.index_of("chain-no-sig") == 0)
        in_chain = true;
      else if (in_chain && line.length > 0 && line[0] == ' ') {
        // OK, appears to be a date line.  Try to parse.  Should look like:
        // ' inc TIMESTR NUMVOLS [ENCRYPTED]'.
        // Since there's a space at the beginning, when we tokenize it, we
        // should expect an extra token at the front.
        string[] tokens = line.split(" ");
        if (tokens.length <= 2)
          continue;

        var datetime = new DateTime.from_iso8601(tokens[2], null);
        if (datetime == null)
          continue;

        dates.append(tokens[2]);

        var info = DateInfo();
        info.time = datetime;
        info.full = tokens[1] == "full";
        infos.append(info);

        if (!detected_encryption && tokens.length > 4) {
          // Just use the encryption status of the first one we see;
          // mixed-encryption backups is not supported.
          detected_encryption = true;
          existing_encrypted = tokens[4] == "enc";
        }
      }
      else if (in_chain)
        in_chain = false;
    }

    got_collection_info = true;
    collection_info = new List<DateInfo?>();
    foreach (DateInfo s in infos)
      collection_info.append(s); // we want to keep our own copy too

    collection_dates(dates);
  }

  bool is_file_in_list(File file, List<File> list)
  {
    foreach (File f in list) {
      if (file.equal(f))
        return true;
    }
    return false;
  }

  bool is_file_in_or_under_list(File file, List<File> list)
  {
    foreach (File f in list) {
      if (file.equal(f) || file.has_prefix(f))
        return true;
    }
    return false;
  }

  protected virtual void process_warning(string[] firstline, List<string>? data,
                                         string text)
  {
    if (firstline.length > 1) {
      switch (int.parse(firstline[1])) {
      case WARNING_ORPHANED_SIG:
      case WARNING_UNNECESSARY_SIG:
      case WARNING_UNMATCHED_SIG:
      case WARNING_INCOMPLETE_BACKUP:
      case WARNING_ORPHANED_BACKUP:
        // Random files left on backend from previous run.  Should clean them
        // up before we continue.  We don't want to wait until we finish to
        // clean them up, since we may want that space, and if there's a bug
        // in ourselves, we may never get to it.
        if (mode == DejaDup.ToolJob.Mode.BACKUP && !this.cleaned_up_once)
          cleanup(); // stops current backup, cleans up, then resumes
        break;

      case WARNING_CANNOT_STAT:
      case WARNING_CANNOT_READ:
        // A file couldn't be backed up!  We should note the name and present
        // the user with a list at the end.
        if (firstline.length > 2) {
          // Only add it if it's a child of one of our includes and isn't a
          // direct exclude. We check includes because sometimes Duplicity
          // likes to talk to us about folders like /lost+found and such that
          // we didn't ask about. And we check excludes because Duplicity will
          // warn us about unreadable files even if we exclude them (but not if
          // the files are under an excluded folder).
          var error_file = make_file_obj(firstline[2]);
          if (is_file_in_or_under_list(error_file, includes) &&
              !is_file_in_list(error_file, excludes))
            local_error_files.add(error_file.get_parse_name());
        }
        break;

      case WARNING_CANNOT_PROCESS:
        // A file couldn't be restored!  We should note the name and present
        // the user with a list at the end.
        if (firstline.length > 2) {
          // Only add it if it's a child of one of our includes.  Sometimes
          // Duplicity likes to talk to us about folders like /lost+found and
          // such that we don't care about.
          var error_file = make_file_obj(firstline[2]);
          if (!error_file.equal(slash) && // for some reason, duplicity likes to talk about '/'
              !text.contains("[Errno 1]")) // Errno 1 is "can't chown" or similar; very common and ignorable
            local_error_files.add(error_file.get_parse_name());
        }
        break;
      }
    }
  }

  void show_error(string errorstr, string? detail = null)
  {
    if (error_issued == false) {
      error_issued = true;
      raise_error(errorstr, detail);
    }
  }

  // Returns volume size in megs
  int get_volsize()
  {
    // Advantages of a smaller value:
    // * takes less temp space
    // * retries of a volume take less time
    // * quicker restore of a particular file (less excess baggage to download)
    // * we get feedback more frequently (duplicity only gives us a progress
    //   report at the end of a volume) -- fixed by reporting when we're uploading
    // Downsides:
    // * less throughput:
    //   * some protocols have large per-file overhead (like sftp)
    //   * the network doesn't have time to ramp up to max tcp transfer speed per
    //     file
    // * lots of files looks ugly to users
    //
    // duplicity's default is 25 (used to be 5).
    //
    // For local filesystems, we'll choose large volsize.
    // For remote FSs, we'll go smaller.
    if (DejaDup.in_testing_mode())
      return 1;
    else if (backend.is_native())
      return 50;
    else
      return 25;
  }

  void disconnect_inst()
  {
    /* Disconnect signals and cancel call to duplicity instance */
    if (inst != null) {
      inst.done.disconnect(handle_done);
      inst.message.disconnect(handle_message);
      inst.exited.disconnect(handle_exit);
      inst.cancel();
      inst = null;
    }
  }

  void connect_and_start(List<string>? argv_extra = null,
                         List<string>? envp_extra = null,
                         List<string>? argv_entire = null,
                         File? custom_local = null)
  {
    /*
     * For passed arguments start a new duplicity instance, set duplicity in the right mode and execute command
     */
    /* Disconnect instance */
    disconnect_inst();

    /* Start new duplicity instance */
    inst = new DuplicityInstance();
    inst.done.connect(handle_done);

    if (forced_cache_dir != null)
      inst.forced_cache_dir = forced_cache_dir;

    /* As duplicity's data is returned via a signal, handle_message begins post-raw stream processing */
    inst.message.connect(handle_message);

    /* When duplicity exits, we may be also interested in its return code */
    inst.exited.connect(handle_exit);

    /* Set arguments for call to duplicity */
    weak List<string> base_argv = argv_entire == null ? saved_argv : argv_entire;
    weak File local_arg = custom_local == null ? local : custom_local;

    var argv = new List<string>();
    foreach (string s in base_argv) argv.append(s);
    foreach (string s in this.backend_argv) argv.append(s);
    foreach (string s in argv_extra) argv.append(s);

    /* Set duplicity into right mode */
    if (argv_entire == null) {
      // add operation, local, and remote args
      switch (mode) {
      case DejaDup.ToolJob.Mode.BACKUP:
        if (is_full_backup)
          argv.prepend("full");
        argv.append("--volsize=%d".printf(get_volsize()));
        argv.append(local_arg.get_path());
        argv.append(get_remote());
        break;
      case DejaDup.ToolJob.Mode.RESTORE:
        argv.prepend("restore");
        if (time != null)
          argv.append("--time=%s".printf(time));
        argv.append("--force");
        argv.append(get_remote());
        argv.append(local_arg.get_path());
        break;
      case DejaDup.ToolJob.Mode.STATUS:
        argv.prepend("collection-status");
        argv.append(get_remote());
        break;
      case DejaDup.ToolJob.Mode.LIST:
        argv.prepend("list-current-files");
        if (time != null)
          argv.append("--time=%s".printf(time));
        argv.append(get_remote());
        break;
      default:
        break;
      }
    }

    /* Set environmental parameters */
    var envp = new List<string>();
    foreach (string s in saved_envp) envp.append(s);
    foreach (string s in envp_extra) envp.append(s);

    bool use_encryption = false;
    if (detected_encryption)
      use_encryption = existing_encrypted;
    else if (encrypt_password != null)
      use_encryption = encrypt_password != "";

    if (use_encryption) {
      if (encrypt_password != null && encrypt_password != "")
        envp.append("PASSPHRASE=%s".printf(encrypt_password));
      // else duplicity will try to prompt user and we'll get an exception,
      // which is our cue to ask user for password.  We could pass an empty
      // passphrase (as we do below), but by not setting it at all, duplicity
      // will error out quicker, and notably before it tries to sync metadata.
    }
    else {
      argv.append("--no-encryption");
      envp.append("PASSPHRASE="); // duplicity sometimes asks for a passphrase when it doesn't need it (during cleanup), so this stops it from prompting the user and us getting an exception as a result
    }

    /* Start duplicity instance */
    inst.start.begin(argv, envp);
  }
}
