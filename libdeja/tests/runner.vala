/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

bool system_mode = false;

string get_top_builddir()
{
  var builddir = Environment.get_variable("top_builddir");
  if (builddir == null)
    builddir = "../../builddir";
  return builddir;
}

string get_srcdir()
{
  var srcdir = Environment.get_variable("srcdir");
  if (srcdir == null)
    srcdir = ".";
  return srcdir;
}

void setup_gsettings()
{
  if (!system_mode) {
    var dir = Environment.get_variable("DEJA_DUP_TEST_HOME");

    var schema_dir = Path.build_filename(dir, "share", "glib-2.0", "schemas");
    DirUtils.create_with_parents(schema_dir, 0700);

    var data_dirs = Environment.get_variable("XDG_DATA_DIRS");
    Environment.set_variable("XDG_DATA_DIRS", "%s:%s".printf(Path.build_filename(dir, "share"), data_dirs), true);

    if (Posix.system("cp %s/data/%s.gschema.xml %s".printf(get_top_builddir(), Config.APPLICATION_ID, schema_dir)) != 0)
      warning("Could not copy schema to %s", schema_dir);

    if (Posix.system("glib-compile-schemas %s".printf(schema_dir)) != 0)
      warning("Could not compile schemas in %s", schema_dir);
  }

  Environment.set_variable("GSETTINGS_BACKEND", "memory", true);
}

KeyFile load_script()
{
  try {
    var script = Environment.get_variable("DEJA_DUP_TEST_SCRIPT");
    var keyfile = new KeyFile();
    keyfile.load_from_file(script, KeyFileFlags.KEEP_COMMENTS);
    return keyfile;
  }
  catch (Error e) {
    warning("%s\n", e.message);
    assert_not_reached();
  }
}

void backup_setup()
{
  // Intentionally don't create @TEST_HOME@/backup, as the mkdir test relies
  // on us not doing so.

  var dir = Environment.get_variable("DEJA_DUP_TEST_HOME");

  Environment.set_variable("DEJA_DUP_TEST_MOCKSCRIPT", Path.build_filename(dir, "mockscript"), true);
  Environment.set_variable("XDG_CACHE_HOME", Path.build_filename(dir, "cache"), true);
  Environment.set_variable("PATH",
                           get_srcdir() + "/mock:" +
                             Environment.get_variable("DEJA_DUP_TEST_PATH"),
                           true);

  var tempdir = Path.build_filename(dir, "tmp");
  DejaDup.ensure_directory_exists(tempdir);
  Environment.set_variable("DEJA_DUP_TEMPDIR", tempdir, true);

  var settings = DejaDup.get_settings();
  settings.set_string(DejaDup.BACKEND_KEY, "local");
  settings = DejaDup.get_settings(DejaDup.LOCAL_ROOT);
  settings.set_string(DejaDup.LOCAL_FOLDER_KEY, Path.build_filename(dir, "backup"));
}

void backup_teardown()
{
  Environment.set_variable("PATH",
                           Environment.get_variable("DEJA_DUP_TEST_PATH"),
                           true);

  var mockscript_path = Environment.get_variable("DEJA_DUP_TEST_MOCKSCRIPT");
  var file = File.new_for_path(mockscript_path);
  if (file.query_exists(null)) {
    // Fail the test, something went wrong
    warning("Mockscript file still exists");
  }

  file = File.new_for_path(mockscript_path + ".failed");
  if (file.query_exists(null)) {
    // Fail the test, something went wrong
    warning("Mockscript had fatal error");
  }

  var test_home = Environment.get_variable("DEJA_DUP_TEST_HOME");
  file = File.new_for_path(Path.build_filename(test_home, "backup"));
  if (file.query_exists(null)) {
    try {
      file.delete(null);
    }
    catch (Error e) {
      assert_not_reached();
    }
  }

  if (Posix.system("rm -r --interactive=never %s".printf(Environment.get_variable("DEJA_DUP_TEST_HOME"))) != 0)
    warning("Could not clean TEST_HOME %s", Environment.get_variable("DEJA_DUP_TEST_HOME"));

  Environment.unset_variable("DEJA_DUP_TEST_MOCKSCRIPT");
  Environment.unset_variable("XDG_CACHE_HOME");
}

public enum Mode {
  NONE,
  STATUS,
  DRY,
  BACKUP,
  VERIFY,
  CLEANUP,
  REMOVE,
  RESTORE,
  RESTORE_STATUS,
  LIST,
}

string duplicity_args(BackupRunner br, Mode mode = Mode.NONE, bool encrypted = false,
                      string extra = "", string include_args = "", string exclude_args = "",
                      bool tmp_archive = false, int remove_n = -1, string? file_to_restore = null)
{
  var cachedir = Environment.get_variable("XDG_CACHE_HOME");
  var test_home = Environment.get_variable("DEJA_DUP_TEST_HOME");
  var backupdir = Path.build_filename(test_home, "backup");
  var restoredir = Path.build_filename(test_home, "restore");

  string enc_str = "";
  if (!encrypted)
    enc_str = "--no-encryption ";

  var tempdir = Path.build_filename(test_home, "tmp");
  var archive = tmp_archive ? "%s/duplicity-?".printf(tempdir) : "%s/deja-dup".printf(cachedir);

  var end_str = "%s'--verbosity=9' '--timeout=120' '--archive-dir=%s' '--tempdir=%s' '--log-fd=?'"
    .printf(enc_str, archive, tempdir);

  if (mode == Mode.CLEANUP)
    return "cleanup '--force' 'gio+file://%s' %s".printf(backupdir, end_str);
  else if (mode == Mode.RESTORE) {
    string file_arg = "", dest_arg = "";
    if (file_to_restore != null) {
      file_arg = "'--file-to-restore=%s' ".printf(file_to_restore.substring(1)); // skip root /
      dest_arg = "/" + File.new_for_path(file_to_restore).get_basename();
    }
    return "'restore' %s%s'--force' 'gio+file://%s' '%s%s' %s"
      .printf(file_arg, extra, backupdir, restoredir, dest_arg, end_str);
  }
  else if (mode == Mode.VERIFY)
    return "'restore' '--file-to-restore=%s/deja-dup/metadata' '--force' 'gio+file://%s' '%s/deja-dup/metadata' %s"
      .printf(cachedir.substring(1), backupdir, cachedir, end_str);
  else if (mode == Mode.LIST)
    return "'list-current-files' %s'gio+file://%s' %s".printf(extra, backupdir, end_str);
  else if (mode == Mode.REMOVE)
    return "'remove-all-but-n-full' '%d' '--force' 'gio+file://%s' %s".printf(remove_n, backupdir, end_str);

  string source_str = "";
  if (mode == Mode.DRY || mode == Mode.BACKUP)
    source_str = "--volsize=1 / ";

  string dry_str = "";
  if (mode == Mode.DRY)
    dry_str = "--dry-run ";

  string args = "";

  if (br.is_full && !br.is_first && (mode == Mode.BACKUP || mode == Mode.DRY))
    args += "full ";

  if (mode == Mode.STATUS || mode == Mode.RESTORE_STATUS)
    args += "collection-status ";

  if (mode == Mode.STATUS || mode == Mode.NONE || mode == Mode.DRY || mode == Mode.BACKUP) {
    args += "'--include=%s/deja-dup/metadata' ".printf(cachedir);
    args += "'--exclude=%s/snap/*/*/.cache' ".printf(Environment.get_home_dir());
    args += "'--exclude=%s/.var/app/*/cache' ".printf(Environment.get_home_dir());

    string[] excludes1 = {"~/Downloads", "$DATADIR/Trash", "~/.xsession-errors",
                          "~/.steam/root", "~/.Private", "~/.gvfs", "~/.ccache",
                           "~/.cache"};
    foreach (string ex in excludes1) {
      ex = ex.replace("~", Environment.get_home_dir());
      ex = ex.replace("$DATADIR", Environment.get_user_data_dir());
      if (FileUtils.test (ex, FileTest.IS_SYMLINK | FileTest.EXISTS))
        args += "'--exclude=%s' ".printf(ex);
    }

    var sys_sym_excludes = "";
    foreach (string sym in excludes1) {
      sym = sym.replace("~", Environment.get_home_dir());
      if (FileUtils.test (sym, FileTest.IS_SYMLINK) &&
          FileUtils.test (sym, FileTest.EXISTS)) {
        try {
          sym = FileUtils.read_link (sym);
          sym = Filename.to_utf8 (sym, -1, null, null);
          if (sym.has_prefix (Environment.get_home_dir()))
            args += "'--exclude=%s' ".printf(sym);
          else // delay non-home paths until very end
            sys_sym_excludes += "'--exclude=%s' ".printf(sym);
        }
        catch (Error e) {
          assert_not_reached();
        }
      }
    }

    if (FileUtils.test (Environment.get_home_dir(), FileTest.EXISTS)) {
      args += "'--include=%s' ".printf(Environment.get_home_dir());
    }
    args += include_args;

    string[] excludes2 = {"/sys", "/run", "/proc", "/dev", tempdir};
    foreach (string ex in excludes2) {
      if (FileUtils.test (ex, FileTest.EXISTS))
        args += "'--exclude=%s' ".printf(ex);
    }

    args += "'--exclude=%s/deja-dup' '--exclude=%s' ".printf(cachedir, cachedir);
    args += "'--exclude=%s' ".printf(backupdir);

    // Really, these following two lists can be interweaved, depending on
    // what the paths are and the order in gsettings.  But tests are careful
    // to avoid having us duplicate the sorting logic in DuplicityJob by
    // putting /tmp paths at the end of exclude lists.  This lets us get away
    // with the simple logic of just appending the two lists.
    args += exclude_args;
    args += sys_sym_excludes;

    args += "'--exclude=**' ";
    args += "'--exclude-if-present=CACHEDIR.TAG' ";
    args += "'--exclude-if-present=.deja-dup-ignore' ";
  }

  args += "%s %s%s'gio+file://%s' %s".printf(extra, dry_str, source_str, backupdir, end_str);

  return args;
}

class BackupRunner : Object
{
  public delegate void OpCallback (DejaDup.Operation op);
  public DejaDup.Operation op = null;
  public string path = null;
  public string script = null;
  public string init_script = null;
  public bool success = true;
  public bool cancelled = false;
  public string? detail = null;
  public string? error_str = null;
  public string? error_regex = null;
  public string? error_detail = null;
  public string restore_date = "now";
  public List<File> restore_files = null;
  public OpCallback? callback = null;
  public bool is_full = false; // we don't often give INFO 3 which triggers is_full()
  public bool is_first = false;
  public int passphrases = 0;
  public bool default_passphrase = false;

  public void run()
  {
    if (script != null)
      run_script(script);

    if (path != null)
      Environment.set_variable("PATH", path, true);

    DejaDup.initialize();

    if (init_script != null)
      run_script(init_script);

    if (op == null)
      return;

    var loop = new MainLoop(null);
    op.done.connect((op, s, c, d) => {
      Test.message("Done: %d, %d, %s", (int)s, (int)c, d);
      if (success != s)
        warning("Success didn't match; expected %d, got %d", (int) success, (int) s);
      if (cancelled != c)
        warning("Cancel didn't match; expected %d, got %d", (int) cancelled, (int) c);
      if (detail != d)
        warning("Detail didn't match; expected %s, got %s", detail, d);
      loop.quit();
    });

    op.raise_error.connect((str, det) => {
      Test.message("Error: %s, %s", str, det);
      if (error_str != null && error_str != str)
        warning("Error string didn't match; expected %s, got %s", error_str, str);
      if (error_regex != null && !GLib.Regex.match_simple (error_regex, str))
        warning("Error string didn't match regex; expected %s, got %s", error_regex, str);
      if (error_detail != det)
        warning("Error detail didn't match; expected %s, got %s", error_detail, det);
      error_str = null;
      error_regex = null;
      error_detail = null;
    });

    op.action_desc_changed.connect((action) => {
    });
    op.action_file_changed.connect((file, actual) => {
    });
    op.progress.connect((percent) => {
    });

    if (default_passphrase)
      op.set_passphrase("test");
    op.passphrase_required.connect(() => {
      Test.message("Passphrase required");
      if (passphrases == 0)
        warning("Passphrase needed but not provided");
      else {
        passphrases--;
        op.set_passphrase("test");
      }
    });

    op.question.connect((title, msg) => {
      Test.message("Question asked: %s, %s", title, msg);
    });

    var seen_is_full = false;
    op.is_full.connect((first) => {
      Test.message("Is full; is first: %d", (int)first);
      if (!is_full)
        warning("IsFull was not expected");
      if (is_first != first)
        warning("IsFirst didn't match; expected %d, got %d", (int) is_first, (int) first);
      seen_is_full = true;
    });

    Idle.add(() => {op.start.begin(); return false;});
    if (callback != null) {
      Timeout.add_seconds(5, () => {
        callback(op);
        return false;
      });
    }
    loop.run();

    if (!seen_is_full && is_full) {
      warning("IsFull was expected");
      if (is_first)
        warning("IsFirst was expected");
    }
    if (error_str != null)
      warning("Error str didn't match; expected %s, never got error", error_str);
    if (error_regex != null)
      warning("Error regex didn't match; expected %s, never got error", error_regex);
    if (error_detail != null)
      warning("Error detail didn't match; expected %s, never got error", error_detail);

    if (passphrases > 0)
      warning("Passphrases expected, but not seen");
  }
}

void add_to_mockscript(string contents)
{
  var script = Environment.get_variable("DEJA_DUP_TEST_MOCKSCRIPT");
  string initial = "";
  try {
    FileUtils.get_contents(script, out initial, null);
    initial += "\n\n=== deja-dup ===";
  }
  catch (Error e) {
    initial = "";
  }

  var real_contents = initial + "\n" + contents;
  try {
    FileUtils.set_contents(script, real_contents);
  }
  catch (Error e) {
    assert_not_reached();
  }
}

string replace_keywords(string in)
{
  var home = Environment.get_home_dir();
  var user = Environment.get_user_name();
  var mockdir = get_srcdir() + "/mock";
  var cachedir = Environment.get_variable("XDG_CACHE_HOME");
  var test_home = Environment.get_variable("DEJA_DUP_TEST_HOME");
  var path = Environment.get_variable("PATH");
  return in.replace("@HOME@", home).
            replace("@MOCK_DIR@", mockdir).
            replace("@PATH@", path).
            replace("@USER@", user).
            replace("@APPID@", Config.APPLICATION_ID).
            replace("@XDG_CACHE_HOME@", cachedir).
            replace("@TEST_HOME@", test_home);
}

string run_script(string in)
{
  string output;
  string errstr;
  try {
    Process.spawn_sync(null, {"/bin/sh", "-c", in}, null, 0, null, out output, out errstr, null);
    if (errstr != null && errstr != "")
      warning("Error running script: %s", errstr);
  }
  catch (SpawnError e) {
    warning(e.message);
    assert_not_reached();
  }
  return output;
}

void process_operation_block(KeyFile keyfile, string group, BackupRunner br) throws Error
{
  var test_home = Environment.get_variable("DEJA_DUP_TEST_HOME");
  var restoredir = Path.build_filename(test_home, "restore");

  if (keyfile.has_key(group, "RestoreFiles")) {
    var array = keyfile.get_string_list(group, "RestoreFiles");
    br.restore_files = new List<File>();
    foreach (var file in array)
      br.restore_files.append(File.new_for_path(replace_keywords(file)));
  }
  if (keyfile.has_key(group, "RestoreDate"))
    br.restore_date = keyfile.get_string(group, "RestoreDate");

  if (keyfile.has_key(group, "Success"))
    br.success = keyfile.get_boolean(group, "Success");
  if (keyfile.has_key(group, "Canceled"))
    br.cancelled = keyfile.get_boolean(group, "Canceled");
  if (keyfile.has_key(group, "IsFull"))
    br.is_full = keyfile.get_boolean(group, "IsFull");
  if (keyfile.has_key(group, "IsFirst"))
    br.is_first = keyfile.get_boolean(group, "IsFirst");
  if (keyfile.has_key(group, "Detail"))
    br.detail = replace_keywords(keyfile.get_string(group, "Detail"));
  if (keyfile.has_key(group, "DiskFree"))
    Environment.set_variable("DEJA_DUP_TEST_SPACE_FREE", keyfile.get_string(group, "DiskFree"), true);
  if (keyfile.has_key(group, "InitScript"))
    br.init_script = replace_keywords(keyfile.get_string(group, "InitScript"));
  if (keyfile.has_key(group, "Error"))
    br.error_str = keyfile.get_string(group, "Error");
  if (keyfile.has_key(group, "ErrorRegex"))
    br.error_regex = keyfile.get_string(group, "ErrorRegex");
  if (keyfile.has_key(group, "ErrorDetail"))
    br.error_detail = keyfile.get_string(group, "ErrorDetail");
  if (keyfile.has_key(group, "Passphrases"))
    br.passphrases = keyfile.get_integer(group, "Passphrases");
  if (keyfile.has_key(group, "Path"))
    br.path = replace_keywords(keyfile.get_string(group, "Path"));
  if (keyfile.has_key(group, "Script"))
    br.script = replace_keywords(keyfile.get_string(group, "Script"));
  if (keyfile.has_key(group, "Settings")) {
    var settings_list = keyfile.get_string_list(group, "Settings");
    foreach (var setting in settings_list) {
      try {
        var tokens = replace_keywords(setting).split("=");
        var key_tokens = tokens[0].split(".");
        var settings = DejaDup.get_settings(key_tokens.length > 1 ? key_tokens[0] : null);
        var key = key_tokens[key_tokens.length - 1];
        var val = Variant.parse(null, tokens[1]);
        settings.set_value(key, val);
      }
      catch (Error e) {
        warning("%s\n", e.message);
        assert_not_reached();
      }
    }
  }
  var type = keyfile.get_string(group, "Type");
  if (type == "backup")
    br.op = new DejaDup.OperationBackup(DejaDup.Backend.get_default());
  else if (type == "restore")
    br.op = new DejaDup.OperationRestore(DejaDup.Backend.get_default(), restoredir,
                                         null, br.restore_date, br.restore_files);
  else if (type == "noop")
    br.op = null;
  else
    assert_not_reached();
}

string get_string_field(KeyFile keyfile, string group, string key) throws Error
{
  var field = keyfile.get_string(group, key);
  if (field == "^")
    return replace_keywords(keyfile.get_comment(group, key));
  if (field == "^sh")
    return run_script(replace_keywords(keyfile.get_comment(group, key))).strip();
  else
    return replace_keywords(field);
}

string[] get_string_list(KeyFile keyfile, string group, string key) throws Error
{
  var list = keyfile.get_string_list(group, key);
  string[] replaced = {};
  foreach (var item in list) {
    replaced += replace_keywords(item);
  }
  return replaced;
}

void process_duplicity_run_block(KeyFile keyfile, string run, BackupRunner br) throws Error
{
  string outputscript = null;
  string extra_args = "";
  string include_args = "";
  string exclude_args = "";
  string file_to_restore = null;
  bool encrypted = false;
  bool cancel = false;
  bool stop = false;
  bool passphrase = false;
  bool tmp_archive = false;
  int return_code = 0;
  int remove_n = -1;
  string script = null;
  Mode mode = Mode.NONE;

  var parts = run.split(" ", 2);
  var type = parts[0];
  var group = "Duplicity " + run;

  if (keyfile.has_group(group)) {
    if (keyfile.has_key(group, "ArchiveDirIsTmp"))
      tmp_archive = keyfile.get_boolean(group, "ArchiveDirIsTmp");
    if (keyfile.has_key(group, "Cancel"))
      cancel = keyfile.get_boolean(group, "Cancel");
    if (keyfile.has_key(group, "Encrypted"))
      encrypted = keyfile.get_boolean(group, "Encrypted");
    if (keyfile.has_key(group, "ExtraArgs")) {
      extra_args = get_string_field(keyfile, group, "ExtraArgs");
      if (!extra_args.has_suffix(" "))
        extra_args += " ";
    }
    if (keyfile.has_key(group, "IncludeArgs")) {
      include_args = get_string_field(keyfile, group, "IncludeArgs");
      if (!include_args.has_suffix(" "))
        include_args += " ";
    }
    if (keyfile.has_key(group, "ExcludeArgs")) {
      exclude_args = get_string_field(keyfile, group, "ExcludeArgs");
      if (!exclude_args.has_suffix(" "))
        exclude_args += " ";
    }
    if (keyfile.has_key(group, "FileToRestore"))
      file_to_restore = get_string_field(keyfile, group, "FileToRestore");
    if (keyfile.has_key(group, "Output") && keyfile.get_boolean(group, "Output"))
      outputscript = replace_keywords(keyfile.get_comment(group, "Output"));
    else if (keyfile.has_key(group, "OutputScript") && keyfile.get_boolean(group, "OutputScript"))
      outputscript = run_script(replace_keywords(keyfile.get_comment(group, "OutputScript")));
    if (keyfile.has_key(group, "Passphrase"))
      passphrase = keyfile.get_boolean(group, "Passphrase");
    if (keyfile.has_key(group, "RemoveButN"))
      remove_n = keyfile.get_integer(group, "RemoveButN");
    if (keyfile.has_key(group, "Return"))
      return_code = keyfile.get_integer(group, "Return");
    if (keyfile.has_key(group, "Stop"))
      stop = keyfile.get_boolean(group, "Stop");
    if (keyfile.has_key(group, "Script"))
      script = get_string_field(keyfile, group, "Script");
  }

  if (type == "status")
    mode = Mode.STATUS;
  else if (type == "status-restore")
    mode = Mode.RESTORE_STATUS; // should really consolidate the statuses
  else if (type == "dry")
    mode = Mode.DRY;
  else if (type == "list")
    mode = Mode.LIST;
  else if (type == "backup")
    mode = Mode.BACKUP;
  else if (type == "verify")
    mode = Mode.VERIFY;
  else if (type == "remove")
    mode = Mode.REMOVE;
  else if (type == "restore")
    mode = Mode.RESTORE;
  else if (type == "cleanup")
    mode = Mode.CLEANUP;
  else
    assert_not_reached();

  var cachedir = Environment.get_variable("XDG_CACHE_HOME");

  var dupscript = "ARGS: " + duplicity_args(br, mode, encrypted, extra_args, include_args, exclude_args,
                                          tmp_archive, remove_n, file_to_restore);

  if (tmp_archive)
    dupscript += "\n" + "TMP_ARCHIVE";

  if (cancel) {
    dupscript += "\n" + "DELAY: 10";
    br.callback = (op) => {
      op.cancel();
    };
  }

  if (stop) {
    dupscript += "\n" + "DELAY: 10";
    br.callback = (op) => {
      op.stop();
    };
  }

  if (return_code != 0)
    dupscript += "\n" + "RETURN: %d".printf(return_code);

  var verify_script = ("mkdir -p %s/deja-dup/metadata && " +
                       "echo 'This folder can be safely deleted.' > %s/deja-dup/metadata/README && " +
                       "echo -n '0' >> %s/deja-dup/metadata/README").printf(cachedir, cachedir, cachedir);
  if (mode == Mode.VERIFY)
    dupscript += "\n" + "SCRIPT: " + verify_script;
  if (script != null) {
    if (mode == Mode.VERIFY)
      dupscript += " && " + script;
    else
      dupscript += "\n" + "SCRIPT: " + script;
  }

  if (passphrase)
    dupscript += "\n" + "PASSPHRASE: test";
  else if (!encrypted) // when not encrypted, we always expect empty string
    dupscript += "\n" + "PASSPHRASE:";

  if (outputscript != null && outputscript != "") {
    // GLib prior to 2.59 added an extra \n to outputscript, but we need \n\n
    // here, so we add them ourselves.
    dupscript += "\n\n" + outputscript.chomp() + "\n\n";
  }

  add_to_mockscript(dupscript);
}

void process_duplicity_block(KeyFile keyfile, string group, BackupRunner br) throws Error
{
  var version = "9.9.99";
  if (keyfile.has_key(group, "Version"))
    version = keyfile.get_string(group, "Version");
  add_to_mockscript("ARGS: --version\n\nduplicity " + version + "\n");

  if (keyfile.has_key(group, "IsFull"))
    br.is_full = keyfile.get_boolean(group, "IsFull");

  if (keyfile.has_key(group, "Runs")) {
    var runs = keyfile.get_string_list(group, "Runs");
    foreach (var run in runs)
      process_duplicity_run_block(keyfile, run, br);
  }
}

void duplicity_run()
{
  var settings = DejaDup.get_settings();
  settings.set_string(DejaDup.TOOL_KEY, "duplicity");

  try {
    var keyfile = load_script();
    var br = new BackupRunner();

    var groups = keyfile.get_groups();
    foreach (var group in groups) {
      if (group == "Operation")
        process_operation_block(keyfile, group, br);
      else if (group == "Duplicity")
        process_duplicity_block(keyfile, group, br);
    }

    br.run();
  }
  catch (Error e) {
    warning("%s\n", e.message);
    assert_not_reached();
  }
}

#if ENABLE_RESTIC
string parse_path(string path)
{
  return path.replace("$HOME", Environment.get_home_dir())
             .replace("$DATADIR", Environment.get_user_data_dir())
             .replace("$CACHEDIR", Environment.get_variable("XDG_CACHE_HOME"));
}

string? read_link(string path)
{
  if (!FileUtils.test(path, FileTest.IS_SYMLINK) ||
      !FileUtils.test(path, FileTest.EXISTS))
    return null;

  try {
    var sym = FileUtils.read_link(path);
    sym = Filename.to_utf8(sym, -1, null, null);
    return sym;
  }
  catch (Error e) {
    assert_not_reached();
  }
}

string? restic_exc(string path, bool must_exist=true)
{
  var parsed = parse_path(path);

  if (must_exist && !FileUtils.test(parsed, FileTest.IS_SYMLINK | FileTest.EXISTS))
    return null;

  return parsed;
}

List<string> restic_exc_list(string[] paths, out List<string> symlinks, bool check_symlinks = true)
{
  List<string> args = null;
  symlinks = null;

  foreach (var path in paths) {
    if (path == null)
      continue;

    if (check_symlinks) {
      var target = read_link(path);
      if (target != null)
        symlinks.append("'--exclude=%s'".printf(target));
    }

    args.append("'--exclude=%s'".printf(path));
  }

  return args;
}

string restic_args(BackupRunner br, string mode, string[] extra_excludes,
                   string[] sym_target_excludes, string[] extra_includes,
                   int keep_within = -1)
{
  var cachedir = Environment.get_variable("XDG_CACHE_HOME");
  var test_home = Environment.get_variable("DEJA_DUP_TEST_HOME");
  var backupdir = Path.build_filename(test_home, "backup");
  var tempdir = Path.build_filename(test_home, "tmp");

  List<string> args = null;
  args.append("--json");
  args.append("--cleanup-cache");
  args.append("--cache-dir=%s/deja-dup/restic".printf(cachedir));
  args.append("--repo=" + backupdir);

  switch (mode) {
    case "backup":
      args.append("backup");
      args.append("--exclude-caches");
      args.append("--exclude-if-present=.deja-dup-ignore");

      string[] regex_excludes = {
        restic_exc("$HOME/snap/*/*/.cache", false),
        restic_exc("$HOME/.var/app/*/cache", false)
      };
      string[] default_excludes = {
        restic_exc("$HOME/Downloads"),
        restic_exc("$DATADIR/Trash")
      };
      string[] builtin_excludes = {
        restic_exc("/sys"),
        restic_exc("/run"),
        restic_exc("/proc"),
        restic_exc("/dev"),
        restic_exc(tempdir),
        restic_exc("$HOME/.xsession-errors"),
        restic_exc("$HOME/.steam/root"),
        restic_exc("$HOME/.Private"),
        restic_exc("$HOME/.gvfs"),
        restic_exc("$HOME/.ccache"),
        restic_exc("$CACHEDIR/deja-dup", false),
        restic_exc("$HOME/.cache"),
        restic_exc("$CACHEDIR", false)
      };

      List<string> default_symlinks = null;
      List<string> builtin_symlinks = null;

      args.concat(restic_exc_list(regex_excludes, null));
      args.concat(restic_exc_list(extra_excludes, null));
      args.concat(restic_exc_list(default_excludes, out default_symlinks));
      args.concat(restic_exc_list(builtin_excludes, out builtin_symlinks));

      // Now delayed symlink targets
      args.concat(default_symlinks.copy_deep((CopyFunc) strdup));
      args.concat(restic_exc_list(sym_target_excludes, null));
      args.concat(builtin_symlinks.copy_deep((CopyFunc) strdup));

      // includes
      string[] includes = {
        "$CACHEDIR/deja-dup/metadata",
        "$HOME"
      };
      foreach (var path in includes) {
        args.append(parse_path(path));
      }
      if (extra_includes != null) {
        foreach (var inc in extra_includes) {
          args.append("'%s'".printf(inc));
        }
      }

      break;

    case "forget":
      args.append("forget");
      if (keep_within >= 0)
        args.append("--keep-within=%dd".printf(keep_within));
      args.append("--prune");
      break;

    case "prune":
      args.append("prune");
      break;

    case "verify":
      args.append("restore");
      args.append("--target=/");
      args.append("--include=" + parse_path("$CACHEDIR/deja-dup/metadata"));
      args.append("latest");
      break;

    default:
      assert_not_reached();
  }

  string command = args.data;
  foreach(var arg in args.next) {
    command += " " + arg;
  }
  return command;
}

void process_restic_run_block(KeyFile keyfile, string run, BackupRunner br) throws Error
{
  bool cancel = false;
  string[] excludes = null;
  string[] sym_target_excludes = null;
  string[] includes = null;
  int keep_within = -1;
  int return_code = 0;
  string script = null;
  bool stop = false;

  var parts = run.split(" ", 2);
  var mode = parts[0];
  var group = "Restic " + run;

  if (keyfile.has_group(group)) {
    if (keyfile.has_key(group, "Cancel"))
      cancel = keyfile.get_boolean(group, "Cancel");
    if (keyfile.has_key(group, "ExtraExcludes"))
      excludes = get_string_list(keyfile, group, "ExtraExcludes");
    if (keyfile.has_key(group, "ExtraIncludes"))
      includes = get_string_list(keyfile, group, "ExtraIncludes");
    if (keyfile.has_key(group, "KeepWithin"))
      keep_within = keyfile.get_integer(group, "KeepWithin");
    if (keyfile.has_key(group, "Script"))
      script = get_string_field(keyfile, group, "Script");
    if (keyfile.has_key(group, "Return"))
      return_code = keyfile.get_integer(group, "Return");
    if (keyfile.has_key(group, "Stop"))
      stop = keyfile.get_boolean(group, "Stop");
    if (keyfile.has_key(group, "SymlinkTargetExcludes"))
      sym_target_excludes = get_string_list(keyfile, group, "SymlinkTargetExcludes");
  }

  var cachedir = Environment.get_variable("XDG_CACHE_HOME");

  var dupscript = "ARGS: " + restic_args(br, mode, excludes, sym_target_excludes, includes, keep_within);

  if (cancel) {
    dupscript += "\n" + "DELAY: 10";
    br.callback = (op) => {
      op.cancel();
    };
  }

  if (stop) {
    dupscript += "\n" + "DELAY: 10";
    br.callback = (op) => {
      op.stop();
    };
  }

  if (return_code != 0)
    dupscript += "\n" + "RETURN: %d".printf(return_code);

  var verify_script = ("mkdir -p %s/deja-dup/metadata && " +
                       "echo 'This folder can be safely deleted.' > %s/deja-dup/metadata/README && " +
                       "echo -n '0' >> %s/deja-dup/metadata/README").printf(cachedir, cachedir, cachedir);
  if (mode == "verify")
    dupscript += "\n" + "SCRIPT: " + verify_script;
  if (script != null) {
    if (mode == "verify")
      dupscript += " && " + script;
    else
      dupscript += "\n" + "SCRIPT: " + script;
  }

  dupscript += "\n" + "PASSPHRASE: test";
  br.default_passphrase = true;

  add_to_mockscript(dupscript);
}

void process_restic_block(KeyFile keyfile, string group, BackupRunner br) throws Error
{
  var version = "9.9.99";
  if (keyfile.has_key(group, "Version"))
    version = keyfile.get_string(group, "Version");
  add_to_mockscript("ARGS: version\n\nrestic %s compiled with go1.15.8 on linux/amd64\n".printf(version));

  if (keyfile.has_key(group, "Runs")) {
    var runs = keyfile.get_string_list(group, "Runs");
    foreach (var run in runs)
      process_restic_run_block(keyfile, run, br);
  }
}

void restic_run()
{
  var settings = DejaDup.get_settings();
  settings.set_string(DejaDup.TOOL_KEY, "restic");

  try {
    var keyfile = load_script();
    var br = new BackupRunner();

    var groups = keyfile.get_groups();
    foreach (var group in groups) {
      if (group == "Operation")
        process_operation_block(keyfile, group, br);
      else if (group == "Restic")
        process_restic_block(keyfile, group, br);
    }

    br.run();
  }
  catch (Error e) {
    warning("%s\n", e.message);
    assert_not_reached();
  }
}
#endif

const OptionEntry[] OPTIONS = {
  {"system", 0, 0, OptionArg.NONE, ref system_mode, "Run against system install", null},
  {null}
};

int main(string[] args)
{
  Test.init(ref args);

  OptionContext context = new OptionContext("");
  context.add_main_entries(OPTIONS, null);
  try {
    context.parse(ref args);
  } catch (Error e) {
    printerr("%s\n\n%s", e.message, context.get_help(true, null));
    return 1;
  }

  try {
    var dir = DirUtils.make_tmp("deja-dup-test-XXXXXX");
    Environment.set_variable("DEJA_DUP_TEST_HOME", dir, true);
  } catch (Error e) {
    printerr("Could not make temporary dir\n");
    return 1;
  }

  Environment.set_variable("DEJA_DUP_TESTING", "1", true);
  Environment.set_variable("DEJA_DUP_DEBUG", "1", true);
  Environment.set_variable("DEJA_DUP_LANGUAGE", "en", true);
  Test.bug_base("https://gitlab.gnome.org/World/deja-dup/-/issues/%s");

  setup_gsettings();

  var script = "unknown/unknown";
  if (args.length > 1)
    script = args[1];
  Environment.set_variable("DEJA_DUP_TEST_SCRIPT", script, true);

  // Save PATH, as tests might reset it on us
  Environment.set_variable("DEJA_DUP_TEST_PATH",
                           Environment.get_variable("PATH"), true);

  var parts = script.split("/");
  var testname = parts[parts.length - 1].split(".")[0];
  var keyfile = load_script();
  var found_group = false;

  if (keyfile.has_group("Duplicity")) {
    var suite = new TestSuite("duplicity");
    suite.add(new TestCase(testname, backup_setup, duplicity_run, backup_teardown));
    TestSuite.get_root().add_suite(suite);
    found_group = true;
  }

#if ENABLE_RESTIC
  if (keyfile.has_group("Restic")) {
    var suite = new TestSuite("restic");
    suite.add(new TestCase(testname, backup_setup, restic_run, backup_teardown));
    TestSuite.get_root().add_suite(suite);
    found_group = true;
  }
#endif

  if (!found_group)
    assert_not_reached();

  return Test.run();
}
