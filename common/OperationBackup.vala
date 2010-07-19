/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*- */
/*
    This file is part of Déjà Dup.
    © 2008–2010 Michael Terry <mike@mterry.name>
    © 2010 Michael Vogt <michael.vogt@ubuntu.com>

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

namespace DejaDup {

public errordomain BackupError {
  BAD_CONFIG
}

public class OperationBackup : Operation
{
  public OperationBackup(uint xid = 0) {
    Object(xid: xid, mode: Mode.BACKUP);
  }
  
  protected override void operation_finished(Duplicity dup, bool success, bool cancelled)
  {
    if (success) {
      try {DejaDup.update_last_run_timestamp();}
      catch (Error e) {warning("%s\n", e.message);}
    }
    
    base.operation_finished(dup, success, cancelled);
  }
  
  void add_to_file_list(ref List<File> list, File file)
  {
    // For the common case, we just add the file directly to the list.
    // For symlinks, we want to add the link and its target to the list.
    // Normally, duplicity ignores targets, and this is fine and expected
    // behavior.  But if the user explicitly requested a symlink, they expect
    // a follow-through, I believe.
    try {
      FileInfo info = file.query_info(FILE_ATTRIBUTE_STANDARD_IS_SYMLINK + "," +
                                      FILE_ATTRIBUTE_STANDARD_SYMLINK_TARGET,
                                      FileQueryInfoFlags.NOFOLLOW_SYMLINKS, 
                                      null);
      if (info.get_is_symlink()) {
        string symlink_target = info.get_symlink_target();
        File parent_dir = file.get_parent();
        dup.includes.prepend(parent_dir.resolve_relative_path(symlink_target));
      }
    }
    catch (Error e) {
      warning("%s\n", e.message);
    }
    
    list.prepend(file);
  }
  
  protected override List<string>? make_argv() throws Error
  {
    var settings = get_settings();
    
    var include_val = settings.get_value(INCLUDE_LIST_KEY);
    var include_list = parse_dir_list(include_val.get_strv());
    var exclude_val = settings.get_value(EXCLUDE_LIST_KEY);
    var exclude_list = parse_dir_list(exclude_val.get_strv());
    
    List<string> rv = new List<string>();
    
    // Exclude directories no one wants to backup
    var always_excluded = get_always_excluded_dirs();
    foreach (string dir in always_excluded)
      add_to_file_list(ref dup.excludes, File.new_for_path(dir));
    
    foreach (File s in exclude_list)
      add_to_file_list(ref dup.excludes, s);
    foreach (File s in include_list)
      add_to_file_list(ref dup.includes, s);
    
    dup.local = File.new_for_path("/");
    
    return rv;
  }
  
  List<string> get_always_excluded_dirs()
  {
    List<string> rv = new List<string>();
    
    // User doesn't care about cache
    string dir = Environment.get_user_cache_dir();
    if (dir != null)
      rv.append(dir);
    
    // Likewise, user doesn't care about cache-like thumbnail directory
    dir = Environment.get_home_dir();
    if (dir != null) {
      rv.append(Path.build_filename(dir, ".thumbnails"));
      rv.append(Path.build_filename(dir, ".gvfs"));
      rv.append(Path.build_filename(dir, ".xsession-errors"));
      rv.append(Path.build_filename(dir, ".recently-used.xbel"));
      rv.append(Path.build_filename(dir, ".recent-applications.xbel"));
      rv.append(Path.build_filename(dir, ".Private")); // encrypted copies of stuff in $HOME
    }
    
    // Some problematic directories like /tmp and /proc should be left alone
    dir = Environment.get_tmp_dir();
    if (dir != null)
      rv.append(dir);
    
    rv.append("/proc");
    rv.append("/sys");
    
    return rv;
  }
}

} // end namespace

