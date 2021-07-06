/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

internal class BorgJoblet : DejaDup.ToolJoblet
{
  // Joblet interface
  protected override ToolInstance make_instance() {
    var instance = new BorgInstance();
    add_handler(instance.message.connect(handle_message));
    return instance;
  }

  protected override void prepare_args(ref List<string> argv, ref List<string> envp) throws Error
  {
    argv.append(BorgPlugin.borg_command());
    argv.append("--info");
    argv.append("--log-json");

    envp.append("BORG_PASSPHRASE=" + (encrypt_password != null ? encrypt_password : ""));
  }

  // Borg helpers
  protected string get_remote(bool add_tag = true)
  {
    string repo = null;

    var file_backend = backend as DejaDup.BackendFile;
    if (file_backend != null) {
      var file = file_backend.get_file_from_settings();
      if (file != null)
        repo = file.get_path();
    }

    if (repo == null)
      return "invalid://"; // shouldn't happen! We should probably complain louder...

    if (add_tag && tag != null)
      repo += "::" + tag;
    return repo;
  }

  protected virtual bool process_message(string? msgid, Json.Reader reader) { return false; }

  // Private helpers

  // Returns null if not a log message.
  // Returns "" if no msgid defined.
  string? get_log_msgid(Json.Reader reader)
  {
    reader.read_member("type");
    var type = reader.get_string_value();
    reader.end_member();

    if (type != "log_message")
      return null;

    var msgid = "";
    if (reader.read_member("msgid"))
      msgid = reader.get_string_value();
    reader.end_member();

    return msgid;
  }

  // Returns true if processing should stop
  bool process_common_log_messages(string? msgid, Json.Reader reader)
  {
    if (msgid == null)
      return false;

    reader.read_member("levelname");
    var levelname = reader.get_string_value();
    reader.end_member();

    if (msgid == "" && levelname == "ERROR") {
      reader.read_member("message");
      var message = reader.get_string_value();
      reader.end_member();
      show_error(("Failed with an unknown error."), message);
      return true;
    }

    if (msgid == "PassphraseWrong") {
      bad_encryption_password();
      return true;
    }

    return false;
  }

  void process_unhandled_message(string? msgid, Json.Reader reader)
  {
    if (msgid == null)
      return;

    reader.read_member("levelname");
    var levelname = reader.get_string_value();
    reader.end_member();

    if (levelname == "ERROR") {
      reader.read_member("message");
      var message = reader.get_string_value();
      reader.end_member();
      show_error(("Failed with an unknown error."), message);
    }
  }

  void handle_message(BorgInstance? inst, Json.Reader reader)
  {
    var msgid = get_log_msgid(reader);

    if (process_common_log_messages(msgid, reader))
      return;

    if (process_message(msgid, reader))
      return;

    process_unhandled_message(msgid, reader);
  }
}

internal class BorgInitJoblet : BorgJoblet
{
  protected override void prepare_args(ref List<string> argv, ref List<string> envp) throws Error
  {
    base.prepare_args(ref argv, ref envp);
    argv.append("init");
    argv.append("--encryption=" + (encrypt_password != null ? "repokey-blake2" : "none"));
    argv.append("--make-parent-dirs");
    argv.append("--progress");
    argv.append(get_remote(false));
  }
}

internal class BorgBackupJoblet : BorgJoblet
{
  protected override void prepare_args(ref List<string> argv, ref List<string> envp) throws Error
  {
    base.prepare_args(ref argv, ref envp);

    assert(tag == null);
    var now = new DateTime.now_utc();
    tag = "%s.%s".printf(Config.PACKAGE, now.format("%s"));

    argv.append("create");
    //argv.append("--bypass-lock");
    argv.append("--progress");
    argv.append("--comment=%s %s".printf(Config.PACKAGE, Config.VERSION));
    add_include_excludes(ref argv);
    argv.append(get_remote());
  }

  bool process_progress(Json.Reader reader)
  {
    reader.read_member("current");
    var current = reader.get_int_value();
    reader.end_member();

    reader.read_member("total");
    var total = reader.get_int_value();
    reader.end_member();

    if (total > 0) {
      progress(((double)current) / total);
    }

    return true;
/*
BORG: {
BORG:   "original_size" : 3357035828,
BORG:   "compressed_size" : 3190880289,
BORG:   "deduplicated_size" : 3132839210,
BORG:   "nfiles" : 14748,
BORG:   "time" : 1608487103.8480146,
BORG:   "type" : "archive_progress",
BORG:   "path" : "home/mike/Downloads/Fedora-Silverblue-ostree-x86_64-33-1.2.iso"
BORG: }
*/
  }

  protected override bool process_message(string? msgid, Json.Reader reader)
  {
    reader.read_member("type");
    var type = reader.get_string_value();
    reader.end_member();

    if (msgid == "Repository.DoesNotExist" || msgid == "Repository.InvalidRepository") {
      disconnect_inst();

      // We need to notify upper layers that we have a first backup!
      is_full(true); // this will take over main loop to ask user for passphrase

      chain.append_to_chain(new BorgInitJoblet());
      chain.append_to_chain(new BorgBackupJoblet());
      finish();

      return true;
    }
    else if (type == "progress_progress")
      return process_progress(reader);

    return false;
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

  void add_include_excludes(ref List<string> argv)
  {
    argv.append("--pattern=Psh");

    // TODO: Figure out a more reasonable way to order regexps and files.
    // For now, just stick regexps in the beginning, as they are more general.
    foreach (string r in exclude_regexps) {
      argv.append("--pattern=-" + r);
    }

    // We need to make sure that the most specific includes/excludes will
    // be first in the list (duplicity uses only first matched dir).  Includes
    // will be preferred if the same dir is present in both lists.
    includes.sort((CompareFunc)cmp_prefix);
    excludes.sort((CompareFunc)cmp_prefix);

    argv.append("--pattern=Ppp");

    foreach (File i in includes) {
      var excludes2 = excludes.copy();
      foreach (File e in excludes2) {
        if (e.has_prefix(i)) {
          argv.append("--pattern=-" + e.get_path());
          excludes.remove(e);
        }
      }
      argv.append("--pattern=R" + i.get_path());
      argv.append("--pattern=+" + i.get_path());
    }
    foreach (File e in excludes) {
      argv.append("--pattern=-" + e.get_path());
    }
  }
}

internal class BorgStatusJoblet : BorgJoblet
{
  protected override void prepare_args(ref List<string> argv, ref List<string> envp) throws Error
  {
    base.prepare_args(ref argv, ref envp);
    argv.append("list");
    argv.append("--json");
    argv.append(get_remote());
  }

  protected override bool process_message(string? msgid, Json.Reader reader)
  {
    if (msgid == "Repository.InvalidRepository") {
      finish();
      return true;
    }

    return process_status(reader);
  }

  bool process_status(Json.Reader reader)
  {
    var dates = new Tree<DateTime, string>((a, b) => {return a.compare(b);});

    reader.read_member("archives");
    for (int i = 0; i < reader.count_elements(); i++) {
      reader.read_element(i);

      reader.read_member("archive");
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

internal class BorgListJoblet : BorgJoblet
{
  protected override void prepare_args(ref List<string> argv, ref List<string> envp) throws Error
  {
    base.prepare_args(ref argv, ref envp);
    argv.append("list");
    argv.append("--json-lines");
    argv.append(get_remote());
  }

  protected override bool process_message(string? msgid, Json.Reader reader)
  {
    reader.read_member("path");
    var path = reader.get_string_value();
    reader.end_member();

    reader.read_member("type");
    var borg_type = reader.get_string_value();
    reader.end_member();

    var file_type = FileType.UNKNOWN;
    if (borg_type == "-")
      file_type = FileType.REGULAR;
    else if (borg_type == "d")
      file_type = FileType.DIRECTORY;
    else if (borg_type == "s")
      file_type = FileType.SYMBOLIC_LINK;

    listed_current_files("/" + path, file_type);
    return true;
  }
}

// Only handles one file at a time, given in constructor
internal class BorgRestoreJoblet : BorgJoblet
{
  public File restore_file {get; construct;}
  public BorgRestoreJoblet(File restore_file)
  {
    Object(restore_file: restore_file);
  }

  protected override void prepare_args(ref List<string> argv, ref List<string> envp) throws Error
  {
    base.prepare_args(ref argv, ref envp);

    argv.append("extract");
    argv.append("--list");

    var path = restore_file.get_path();
    path = path[1:path.length]; // skip leading slash

    if (local.get_parent() != null) {
      var parts = path.split("/");
      argv.append("--strip-components=%d".printf(parts.length - 1));
    }

    argv.append(get_remote());
    argv.append(path);

    // borg always writes to the current directory
    Environment.set_current_dir(local.get_path());
  }
}

internal class BorgJob : DejaDup.ToolJobChain
{
  public override async void start()
  {
    switch (mode) {
    case Mode.BACKUP:
      append_to_chain(new BorgBackupJoblet());
      break;
    case Mode.RESTORE:
      foreach (var file in restore_files) {
        append_to_chain(new BorgRestoreJoblet(file));
      }
      break;
    case Mode.STATUS:
      append_to_chain(new BorgStatusJoblet());
      break;
    case Mode.LIST:
      append_to_chain(new BorgListJoblet());
      break;
    default:
      warning("Unknown mode %d", mode);
      done(true, false, null);
      return;
    }

    yield base.start();
  }
}
