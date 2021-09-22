/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

/**
 * FIXME:
 * - need to delete older as we run out of space
 * - enable verify operation (blocked by nested includes/excludes)
 * - removing old versions of duplicity as we make restic ones (wait until out of beta?)
 */

internal class ResticJoblet : DejaDup.ToolJoblet
{
  protected bool ignore_errors = false;
  string rclone_remote = null;
  string tmpdir = null;

  // Joblet interface
  protected override ToolInstance make_instance() {
    var instance = new ResticInstance();
    add_handler(instance.message.connect(handle_message));
    add_handler(instance.bad_password.connect(handle_bad_password));
    add_handler(instance.fatal_error.connect(handle_fatal_error));
    add_handler(instance.no_repository.connect(handle_no_repository));
    return instance;
  }

  protected override async void prepare() throws Error
  {
    yield base.prepare();
    tmpdir = yield DejaDup.get_tempdir(); // save and use in prepare_args

    var remote_backend = backend as DejaDup.BackendRemote;
    if (remote_backend != null) {
      // FIXME: I've found issues with mounting and unmounting often - it seems
      // to confuse FUSE. Which, fair. So just litter the user's session with
      // our mount.
      remote_backend.unmount_when_done = false;
    }
  }

  protected override void prepare_args(ref List<string> argv, ref List<string> envp) throws Error
  {
    argv.append(ResticPlugin.restic_command());
    argv.append("--json");
    argv.append("--cleanup-cache");

    var cachedir = restic_cachedir();
    if (cachedir != null)
      argv.append("--cache-dir=" + cachedir);

    if ((flags & DejaDup.ToolJob.Flags.NO_CACHE) != 0)
      argv.append("--no-cache");

    if (encrypt_password != null && encrypt_password != "")
      envp.append("RESTIC_PASSWORD=" + encrypt_password);

    // Fill envp with rclone config if needed
    if (backend.kind == DejaDup.Backend.Kind.GOOGLE ||
        backend.kind == DejaDup.Backend.Kind.MICROSOFT)
    {
      rclone_remote = Rclone.fill_envp_from_backend(backend, ref envp);
      argv.append("--option=rclone.program=" + Rclone.rclone_command());
    }

    if (DejaDup.ensure_directory_exists(tmpdir))
      envp.append("TMPDIR=%s".printf(tmpdir));
  }

  // Restic helpers
  protected string get_remote()
  {
    string repo = null;

    var file_backend = backend as DejaDup.BackendFile;
    if (file_backend != null) {
      var file = file_backend.get_file_from_settings();
      if (file != null)
        repo = file.get_path();
      // FIXME: error out
      // if (repo == null) error...
    }

    if (rclone_remote != null) {
      repo = "rclone:" + rclone_remote;
    }

    if (repo == null)
      repo = "invalid://"; // shouldn't happen! We should probably complain louder...
    else if (repo.has_suffix("/"))
      repo += "restic";
    else
      repo += "/restic";

    return "--repo=" + repo;
  }

  protected virtual bool process_message(string? msgid, Json.Reader reader) { return false; }

  protected string escape_pattern(string path)
  {
    // https://restic.readthedocs.io/en/latest/040_backup.html#excluding-files
    return path.replace("$", "$$");
  }

  protected string escape_path(string path)
  {
    // https://golang.org/pkg/path/filepath/#Match
    var escaped = path.replace("\\", "\\\\");
    escaped = escaped.replace("*", "\\*");
    escaped = escaped.replace("?", "\\?");
    escaped = escaped.replace("[", "\\[");
    return escape_pattern(escaped);
  }

  // Private helpers

  string? get_msgid(Json.Reader reader)
  {
    string msgid = null;
    if (reader.read_member("message_type"))
      msgid = reader.get_string_value();
    reader.end_member();

    return msgid;
  }

  void handle_message(Json.Reader reader)
  {
    var msgid = get_msgid(reader);
    process_message(msgid, reader);
  }

  void handle_bad_password()
  {
    bad_encryption_password();
  }

  protected virtual void handle_no_repository() {}

  protected override void handle_done(bool success, bool cancelled)
  {
    if (ignore_errors)
      success = true;
    base.handle_done(success, cancelled);
  }

  protected virtual void handle_fatal_error(string msg)
  {
    if (!ignore_errors)
      show_error(msg);
  }

  string? restic_cachedir()
  {
    string dir = Environment.get_user_cache_dir();
    if (dir == null)
      return null;
    return Path.build_filename(dir, Config.PACKAGE, "restic");
  }
}

internal class ResticMakeSpaceJoblet : ResticJoblet
{
  protected override void prepare_args(ref List<string> argv, ref List<string> envp) throws Error
  {
    base.prepare_args(ref argv, ref envp);
    argv.append(get_remote());
    argv.append("stats");
    argv.append("--tag=deja-dup");
    argv.append("--mode=raw-data");
  }

  protected override bool process_message(string? msgid, Json.Reader reader)
  {
    if (msgid == null)
      return process_stats(reader);

    return false;
  }

  protected bool process_stats(Json.Reader reader)
  {

    return true;
  }

  protected override void handle_done(bool success, bool cancelled)
  {
    if (success) {
      //chain.prepend_to_chain(...);
    }

    base.handle_done(success, cancelled);
  }
}

internal class ResticInitJoblet : ResticJoblet
{
  protected override void prepare_args(ref List<string> argv, ref List<string> envp) throws Error
  {
    base.prepare_args(ref argv, ref envp);
    argv.append(get_remote());
    argv.append("init");
  }
}

internal class ResticPruneJoblet : ResticJoblet
{
  protected override void prepare_args(ref List<string> argv, ref List<string> envp) throws Error
  {
    base.prepare_args(ref argv, ref envp);
    argv.append(get_remote());
    argv.append("prune");
  }

  protected override void handle_done(bool success, bool cancelled)
  {
    base.handle_done(false, true); // prune is always part of a cancel
  }
}

internal class ResticBackupJoblet : ResticJoblet
{
  int64 seconds_elapsed = -1;
  uint64 free_space = DejaDup.Backend.INFINITE_SPACE;
  uint64 total_space = DejaDup.Backend.INFINITE_SPACE;

  protected override bool cancel_cleanup()
  {
    chain.append_to_chain(new ResticPruneJoblet());
    return true;
  }

  protected override async void prepare() throws Error
  {
    yield base.prepare();

    // grab backend space info - we will compare against size of sources
    free_space = yield backend.get_space();
    total_space = yield backend.get_space(false);

    // Sanity check total here, plus this can actually happen if an overflow
    // occurs (GNOME bug 786177).
    if (free_space != DejaDup.Backend.INFINITE_SPACE && free_space > total_space)
      total_space = free_space;
  }

  protected override void prepare_args(ref List<string> argv, ref List<string> envp) throws Error
  {
    base.prepare_args(ref argv, ref envp);
    tag = "latest"; // for the restore check's benefit, at end of backup

    argv.append(get_remote());
    argv.append("backup");
    argv.append("--tag=deja-dup");
    argv.append("--exclude-caches");
    argv.append("--exclude-if-present=.deja-dup-ignore");
    add_include_excludes(ref argv);
  }

  bool process_status(Json.Reader reader)
  {
    // Read and save the seconds elapsed
    var current_seconds = seconds_elapsed;
    if (reader.read_member("seconds_elapsed"))
      seconds_elapsed = reader.get_int_value();
    else
      seconds_elapsed = 0;
    reader.end_member();

    // Throttle ourselves from updating the UI too often.
    // (arguably should be done in UI layer)
    if (current_seconds == seconds_elapsed)
      return true;

    // Check the total size
    reader.read_member("total_bytes");
    var total_bytes = reader.get_int_value();
    reader.end_member();
    if (total_bytes > total_space) {
      // Tiny backup location.  Suggest they get a larger one.
      var msg = _("Backup location is too small. Try using one with at least %s.");
      show_error(msg.printf(format_size(total_bytes)));
      done(false, false, null);
      return true;
    }

    // Read the percent
    reader.read_member("percent_done");
    var percent_done = reader.get_double_value();
    reader.end_member();
    progress(percent_done);

    // Read an optional filename
    if (reader.read_member("current_files")) { // array of strings
      var count = reader.count_elements();
      if (count > 0) {
        reader.read_element(0); // only bother with looking at the first file
        var path = reader.get_string_value();
        reader.end_element();
        action_file_changed(File.new_for_path(path), true);
      }
    }
    reader.end_member();

    return true;
  }

  protected override void handle_no_repository()
  {
    disconnect_inst(); // otherwise we might run handle_done() during is_full

    // We need to notify upper layers that we have a first backup!
    is_full(true); // this will take over main loop to ask user for passphrase

    chain.prepend_to_chain(new ResticBackupJoblet());
    chain.prepend_to_chain(new ResticInitJoblet());

    done(true, false, null);
  }

  protected override bool process_message(string? msgid, Json.Reader reader)
  {
    if (msgid == "status")
      return process_status(reader);

    return false;
  }

  bool list_contains_file(List<File> list, File file)
  {
    foreach (var f in list) {
      if (f.equal(file))
        return true;
    }
    return false;
  }

  void add_include_excludes(ref List<string> argv)
  {
    // FIXME: nested folders don't work:
    // https://github.com/restic/restic/issues/3408

    // Expand symlinks and ignore mising targets.
    // Restic will back up a symlink if specified directly. But if we left
    // synlinks in parent paths, it will treat them as normal directories.
    // These calls make sure we include the sym link and the target dirs.
    // (Which is consistent behavior with our Duplicity tool support.)
    DejaDup.expand_links_in_list(ref includes, true);
    DejaDup.expand_links_in_list(ref includes_priority, true);
    DejaDup.expand_links_in_list(ref excludes, false);

    foreach (var regexp in exclude_regexps) {
      argv.append("--exclude=" + escape_pattern(regexp));
    }
    foreach (var file in excludes) {
      // Avoid duplicating an exclude and an include - restic will choose exclude
      if (!list_contains_file(includes_priority, file) &&
          !list_contains_file(includes, file))
      {
        argv.append("--exclude=" + escape_path(file.get_path()));
      }
    }
    foreach (var file in includes_priority) {
      argv.append(file.get_path());
    }
    foreach (var file in includes) {
      argv.append(file.get_path());
    }
  }
}

internal class ResticDeleteOldBackupsJoblet : ResticJoblet
{
  public int delete_after {get; construct;}

  public ResticDeleteOldBackupsJoblet(int delete_after) {
    Object(delete_after: delete_after);
  }

  protected override void prepare_args(ref List<string> argv, ref List<string> envp) throws Error
  {
    base.prepare_args(ref argv, ref envp);
    argv.append(get_remote());
    argv.append("forget");
    argv.append("--tag=deja-dup");
    argv.append("--group-by=tags");
    argv.append("--keep-within=%dd".printf(delete_after));
    argv.append("--prune");
  }
}

internal class ResticStatusJoblet : ResticJoblet
{
  protected override void prepare_args(ref List<string> argv, ref List<string> envp) throws Error
  {
    base.prepare_args(ref argv, ref envp);
    argv.append(get_remote());
    argv.append("snapshots");
    argv.append("--tag=deja-dup");
  }

  protected override void handle_no_repository()
  {
    var dates = new Tree<DateTime, string>((a, b) => {return a.compare(b);});
    collection_dates(dates);
    ignore_errors = true;
  }

  protected override bool process_message(string? msgid, Json.Reader reader)
  {
    if (msgid == null)
      return process_snapshots(reader);

    return false;
  }

  bool process_snapshots(Json.Reader reader)
  {
    var dates = new Tree<DateTime, string>((a, b) => {return a.compare(b);});

    for (int i = 0; i < reader.count_elements(); i++) {
      reader.read_element(i);

      reader.read_member("id");
      var tag = reader.get_string_value();
      reader.end_member();

      reader.read_member("time");
      var strtime = reader.get_string_value();
      reader.end_member();

      var time = new DateTime.from_iso8601(strtime, new TimeZone.utc());
      dates.insert(time, tag);

      reader.end_element();
    }

    collection_dates(dates);
    return true;
  }
}

internal class ResticListJoblet : ResticJoblet
{
  protected override void prepare_args(ref List<string> argv, ref List<string> envp) throws Error
  {
    base.prepare_args(ref argv, ref envp);
    argv.append(get_remote());
    argv.append("ls");
    argv.append(tag);
  }

  protected override bool process_message(string? msgid, Json.Reader reader)
  {
    if (msgid == null)
      return process_file(reader);

    return false;
  }

  bool process_file(Json.Reader reader)
  {
    reader.read_member("type");
    var restic_type = reader.get_string_value();
    reader.end_member();

    if (restic_type == null)
      return false; // might be initial snapshot struct_type message

    reader.read_member("path");
    var path = reader.get_string_value();
    reader.end_member();

    var file_type = FileType.UNKNOWN;
    if (restic_type == "file")
      file_type = FileType.REGULAR;
    else if (restic_type == "dir")
      file_type = FileType.DIRECTORY;
    else if (restic_type == "symlink")
      file_type = FileType.SYMBOLIC_LINK;

    listed_current_files(path, file_type);
    return true;
  }
}

// Only handles one file at a time, given in constructor
internal class ResticRestoreJoblet : ResticJoblet
{
  public File restore_file {get; construct;}
  public ResticRestoreJoblet(File? restore_file)
  {
    Object(restore_file: restore_file);
  }

  construct {
    // FIXME: restic will error out even for benign errors like "we can't
    // set file properties on /home":
    // ```
    // ignoring error for /home: UtimesNano: operation not permitted
    // Fatal: There were 1 errors
    // ```
    // We need a more nuanced approach here.
    ignore_errors = true;
  }

  string dump_to_command()
  {
    var testing_str = Environment.get_variable("DEJA_DUP_TESTING");
    if (testing_str != null && int.parse(testing_str) > 0)
      return "restic-dump-to";
    else
      return Path.build_filename(Config.PKG_LIBEXEC_DIR, "restic-dump-to");
  }

  void prepare_args_to_dir(ref List<string> argv, ref List<string> envp) throws Error
  {
    // We use a wrapper script to handle the details of "restic dump" sometimes
    // giving back a tar file and sometimes a direct file to stdout. Easier to
    // handle that sort of piping in a shell script. This script wants a few
    // arguments, including the file type, which we'll look up from the file tree.
    var include_path = restore_file == null ? "/" : restore_file.get_path();
    var nodekind = FileType.DIRECTORY;
    if (restore_file != null) {
      var node = tree.file_to_node(restore_file);
      if (node != null)
        nodekind = node.kind;
    }

    argv.append(dump_to_command());
    argv.append(nodekind == FileType.DIRECTORY ? "dir" : "reg");
    argv.append(local.get_path());
    argv.append(include_path);

    base.prepare_args(ref argv, ref envp);

    argv.append(get_remote());
    argv.append("dump");
    argv.append(tag);
    argv.append(include_path);
  }

  void prepare_args_to_original(ref List<string> argv, ref List<string> envp) throws Error
  {
    base.prepare_args(ref argv, ref envp);

    argv.append(get_remote());
    argv.append("restore");
    argv.append("--target=/");
    if (restore_file != null)
      argv.append("--include=" + escape_path(restore_file.get_path()));
    argv.append(tag);
  }

  protected override void prepare_args(ref List<string> argv, ref List<string> envp) throws Error
  {
    if (local.get_parent() == null)
      prepare_args_to_original(ref argv, ref envp);
    else
      prepare_args_to_dir(ref argv, ref envp);
  }
}

internal class ResticJob : DejaDup.ToolJobChain
{
  public override async void start()
  {
    switch (mode) {
    case Mode.BACKUP:
      var settings = DejaDup.get_settings();
      var delete_after = settings.get_int(DejaDup.DELETE_AFTER_KEY);

      //append_to_chain(new ResticMakeSpaceJoblet());
      append_to_chain(new ResticBackupJoblet());
      if (delete_after > 0)
        append_to_chain(new ResticDeleteOldBackupsJoblet(delete_after));

      break;
    case Mode.RESTORE:
      if (restore_files == null) {
        append_to_chain(new ResticRestoreJoblet(null));
      }
      else {
        foreach (var file in restore_files) {
          append_to_chain(new ResticRestoreJoblet(file));
        }
      }
      break;
    case Mode.STATUS:
      append_to_chain(new ResticStatusJoblet());
      break;
    case Mode.LIST:
      append_to_chain(new ResticListJoblet());
      break;
    default:
      warning("Unknown mode %d", mode);
      done(true, false, null);
      return;
    }

    yield base.start();
  }
}
