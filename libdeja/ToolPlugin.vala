/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public abstract class ToolJob : Object
{
  // life cycle signals
  public signal void done(bool success, bool cancelled, string? detail);
  public signal void raise_error(string errstr, string? detail);

  // hints to UI
  public signal void action_desc_changed(string action);
  public signal void action_file_changed(File file, bool actual);
  public signal void progress(double percent);
  public signal void is_full(bool first);

  // hints that interaction is needed
  public signal void bad_encryption_password();
  public signal void question(string title, string msg);

  // type-specific signals
  public signal void collection_dates(List<string>? dates); // STATUS
  public signal void listed_current_files(string date, string file, string type); // LIST

  // life cycle control
  public abstract void start ();
  public abstract void cancel (); // destroy progress so far
  public abstract void stop (); // just abruptly stop
  public abstract void pause (string? reason);
  public abstract void resume ();

  public enum Mode {
    INVALID, BACKUP, RESTORE, STATUS, LIST,
  }
  public Mode mode {get; set; default = Mode.INVALID;}

  public enum Flags {
    NO_PROGRESS,
    NO_CACHE,
  }
  public Flags flags {get; set;}

  public File local {get; set;}
  public Backend backend {get; set;}
  public string encrypt_password {get; set;}

  public List<File> includes; // BACKUP
  public List<File> excludes; // BACKUP
  public List<string> exclude_regexps; // BACKUP

  protected List<File> _restore_files;
  public List<File> restore_files { // RESTORE
    get {
      return this._restore_files;
    }
    set {
      this._restore_files = value.copy_deep ((CopyFunc) Object.ref);
    }
  }
  public FileTree tree {get; set;} // RESTORE
  public string time {get; set;} // RESTORE
}

public abstract class ToolPlugin : Object
{
  public string name {get; protected set;}
  public abstract string get_version() throws Error;
  public virtual string[] get_dependencies() {return {};} // list of what-provides hints
  public abstract ToolJob create_job () throws Error;
}

} // end namespace

