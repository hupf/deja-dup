// -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2; coding: utf-8 -*-
/*
    This file is part of Déjà Dup.
    For copyright information, see AUTHORS.

    Déjà Dup is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Déjà Dup is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Déjà Dup.  If not, see <http://www.gnu.org/licenses/>.
*/

using GLib;

void setup_gsettings()
{
  var dir = Environment.get_variable("DEJA_DUP_TEST_HOME");

  var schema_dir = Path.build_filename(dir, "share", "glib-2.0", "schemas");
  DirUtils.create_with_parents(schema_dir, 0700);

  var data_dirs = Environment.get_variable("XDG_DATA_DIRS");
  Environment.set_variable("XDG_DATA_DIRS", "%s:%s".printf(Path.build_filename(dir, "share"), data_dirs), true);

  if (Posix.system("cp ../../data/org.gnome.DejaDup.gschema.xml %s".printf(schema_dir)) != 0)
    warning("Could not copy schema to %s", schema_dir);

  if (Posix.system("glib-compile-schemas %s".printf(schema_dir)) != 0)
    warning("Could not compile schemas in %s", schema_dir);

  Environment.set_variable("GSETTINGS_BACKEND", "memory", true);
}

void backup_setup()
{
  var dir = Environment.get_variable("DEJA_DUP_TEST_HOME");

  var cachedir = Path.build_filename(dir, "cache");
  DirUtils.create_with_parents(Path.build_filename(cachedir, "deja-dup"), 0700);

  Environment.set_variable("DEJA_DUP_TEST_MOCKSCRIPT", Path.build_filename(dir, "mockscript"), true);
  Environment.set_variable("XDG_CACHE_HOME", cachedir, true);
  Environment.set_variable("PATH", "./mock:" + Environment.get_variable("PATH"), true);

  var settings = DejaDup.get_settings();
  settings.set_string(DejaDup.BACKEND_KEY, "file");
  settings = DejaDup.get_settings(DejaDup.FILE_ROOT);
  settings.set_string(DejaDup.FILE_PATH_KEY, "/tmp/not/a/thing");
}

void backup_teardown()
{
  var path = Environment.get_variable("PATH");
  if (path.has_prefix("./mock:")) {
    path = path.substring(7);
    Environment.set_variable("PATH", path, true);
  }

  var file = File.new_for_path(Environment.get_variable("DEJA_DUP_TEST_MOCKSCRIPT"));
  if (file.query_exists(null)) {
    // Fail the test, something went wrong
    warning("Mockscript file still exists");
  }

  file = File.new_for_path("/tmp/not/a/thing");
  if (file.query_exists(null)) {
    try {
      file.delete(null);
    }
    catch (Error e) {
      assert_not_reached();
    }
  }

  if (Posix.system("rm -r %s".printf(Environment.get_variable("DEJA_DUP_TEST_HOME"))) != 0)
    warning("Could not clean TEST_HOME %s", Environment.get_variable("DEJA_DUP_TEST_HOME"));

  Environment.unset_variable("DEJA_DUP_TEST_MOCKSCRIPT");
  Environment.unset_variable("XDG_CACHE_HOME");
}

public enum Mode {
  NONE,
  STATUS,
  DRY,
  BACKUP,
  CLEANUP,
  RESTORE,
  RESTORE_STATUS,
  LIST,
}

public string default_args(Mode mode = Mode.NONE, bool encrypted = false, string extra = "")
{
  var cachedir = Environment.get_variable("XDG_CACHE_HOME");

  if (mode == Mode.CLEANUP)
    return "'--force' 'file:///tmp/not/a/thing' '--gio' '--no-encryption' '--verbosity=9' '--gpg-options=--no-use-agent' '--archive-dir=%s/deja-dup' '--log-fd=?'".printf(cachedir);
  else if (mode == Mode.RESTORE)
    return "'restore' '--gio' '--force' 'file:///tmp/not/a/thing' '/tmp/not/a/restore' '--no-encryption' '--verbosity=9' '--gpg-options=--no-use-agent' '--archive-dir=%s/deja-dup' '--log-fd=?'".printf(cachedir);
  else if (mode == Mode.LIST)
    return "'list-current-files' '--gio' 'file:///tmp/not/a/thing' '--no-encryption' '--verbosity=9' '--gpg-options=--no-use-agent' '--archive-dir=%s/deja-dup' '--log-fd=?'".printf(cachedir);

  string source_str = "";
  if (mode == Mode.DRY || mode == Mode.BACKUP)
    source_str = "--volsize=50 / ";

  string dry_str = "";
  if (mode == Mode.DRY)
    dry_str = "--dry-run ";

  string enc_str = "";
  if (!encrypted)
    enc_str = "--no-encryption ";

  string args = "";

  if (mode == Mode.STATUS)
    args += "collection-status ";

  if (mode == Mode.STATUS || mode == Mode.NONE || mode == Mode.DRY || mode == Mode.BACKUP) {
    args += "'--exclude=/tmp/not/a/thing' ";

    string[] excludes1 = {"~/Downloads", "~/.local/share/Trash", "~/.xsession-errors", "~/.thumbnails", "~/.Private", "~/.gvfs", "~/.adobe/Flash_Player/AssetCache"};

    var user = Environment.get_user_name();
    string[] excludes2 = {"/home/.ecryptfs/%s/.Private".printf(user), "/sys", "/proc", "/tmp"};

    foreach (string ex in excludes1) {
      ex = ex.replace("~", Environment.get_home_dir());
      if (FileUtils.test (ex, FileTest.EXISTS))
        args += "'--exclude=%s' ".printf(ex);
    }

    args += "'--include=%s' ".printf(Environment.get_home_dir());

    foreach (string ex in excludes2) {
      ex = ex.replace("~", Environment.get_home_dir());
      if (FileUtils.test (ex, FileTest.EXISTS))
        args += "'--exclude=%s' ".printf(ex);
    }

    args += "'--exclude=%s/deja-dup' '--exclude=%s' '--exclude=**' ".printf(cachedir, cachedir);
  }

  args += "%s%s'--gio' %s'file:///tmp/not/a/thing' %s'--verbosity=9' '--gpg-options=--no-use-agent' '--archive-dir=%s/deja-dup' '--log-fd=?'".printf(extra, dry_str, source_str, enc_str, cachedir);

  return args;
}

class BackupRunner : Object
{
  public delegate void OpCallback (DejaDup.Operation op);
  public DejaDup.Operation op = null;
  public bool success = true;
  public bool cancelled = false;
  public string? detail = null;
  public string? error_str = null;
  public string? error_detail = null;
  public OpCallback? callback = null;
  public bool is_full = true;

  public void run()
  {
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
      if (error_str != str)
        warning("Error string didn't match; expected %s, got %s", error_str, str);
      if (error_detail != det)
        warning("Error detail didn't match; expected %s, got %s", error_detail, det);
      error_str = null;
      error_detail = null;
    });
    op.action_desc_changed.connect((action) => {
    });
    op.action_file_changed.connect((file, actual) => {
    });
    op.progress.connect((percent) => {
    });
    op.passphrase_required.connect(() => {
      Test.message("Passphrase required");
    });
    op.question.connect((title, msg) => {
      Test.message("Question asked: %s, %s", title, msg);
    });
    op.is_full.connect((full) => {
      Test.message("Is full? %d", (int)full);
      if (is_full != full)
        warning("IsFull didn't match; expected %d, got %d", (int) is_full, (int) full);
    });

    op.start();
    if (callback != null) {
      Timeout.add_seconds(3, () => {
        callback(op);
        return false;
      });
    }
    loop.run();

    if (error_str != null)
      warning("Error str didn't match; expected %s, never got error", error_str);
    if (error_detail != null)
      warning("Error detail didn't match; expected %s, never got error", error_detail);
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

void process_operation_block(KeyFile keyfile, string group, BackupRunner br) throws Error
{
  var type = keyfile.get_string(group, "Type");
  if (type == "backup")
    br.op = new DejaDup.OperationBackup();
  if (keyfile.has_key(group, "Success"))
    br.success = keyfile.get_boolean(group, "Success");
  if (keyfile.has_key(group, "Canceled"))
    br.cancelled = keyfile.get_boolean(group, "Canceled");
  if (keyfile.has_key(group, "IsFull"))
    br.is_full = keyfile.get_boolean(group, "IsFull");
  if (keyfile.has_key(group, "Detail"))
    br.detail = keyfile.get_string(group, "Detail");
  if (keyfile.has_key(group, "Error"))
    br.error_str = keyfile.get_string(group, "Error");
  if (keyfile.has_key(group, "ErrorDetail"))
    br.error_detail = keyfile.get_string(group, "ErrorDetail");
}

void process_duplicity_run_block(KeyFile keyfile, string run) throws Error
{
  var dupscript = "";

  var parts = run.split(" ", 2);
  var type = parts[0];
  if (type == "status")
    dupscript = "ARGS: " + default_args(Mode.STATUS);
  else if (type == "dry")
    dupscript = "ARGS: " + default_args(Mode.DRY);
  else if (type == "backup")
    dupscript = "ARGS: " + default_args(Mode.BACKUP);

  var group = "Duplicity " + run;
  if (keyfile.has_group(group)) {
    if (keyfile.has_key(group, "Output") && keyfile.get_boolean(group, "Output")) {
      var commentscript = keyfile.get_comment(group, "Output");
      if (commentscript != null && commentscript != "")
        dupscript = dupscript + "\n\n" + commentscript + "\n";
    }
  }

  add_to_mockscript(dupscript);
}

void process_duplicity_block(KeyFile keyfile, string group, BackupRunner br) throws Error
{
  var runs = keyfile.get_string_list(group, "Runs");
  foreach (var run in runs)
    process_duplicity_run_block(keyfile, run);
}

void backup_run()
{
  try {
    var script = Environment.get_variable("DEJA_DUP_TEST_SCRIPT");
    var keyfile = new KeyFile();
    keyfile.load_from_file(script, KeyFileFlags.KEEP_COMMENTS);

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
    assert_not_reached();
  }
}

int main(string[] args)
{
  Test.init(ref args);

  var dir = "/tmp/deja-dup-test-XXXXXX";
  dir = DirUtils.mkdtemp(dir);
  Environment.set_variable("DEJA_DUP_TEST_HOME", dir, true);

  Environment.set_variable("DEJA_DUP_LANGUAGE", "en", true);
  Test.bug_base("https://launchpad.net/bugs/%s");

  setup_gsettings();

  var script = "unknown/unknown";
  if (args.length > 1)
    script = args[1];
  Environment.set_variable("DEJA_DUP_TEST_SCRIPT", script, true);

  var parts = script.split("/", 3);
  var suitename = parts[1];
  var testname = parts[2];

  var suite = new TestSuite(suitename);
  suite.add(new TestCase(testname, backup_setup, backup_run, backup_teardown));
  TestSuite.get_root().add_suite(suite);

  return Test.run();
}