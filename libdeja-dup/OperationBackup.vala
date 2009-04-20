/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*- */
/*
    Déjà Dup
    © 2008—2009 Michael Terry <mike@mterry.name>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

using GLib;

namespace DejaDup {

public errordomain BackupError {
  BAD_CONFIG
}

public class OperationBackup : Operation
{
  public OperationBackup(Gtk.Window? win, uint xid = 0) {
    toplevel = win;
    uppermost_xid = xid;
    mode = Mode.BACKUP;
  }
  
  protected override void operation_finished(Duplicity dup, bool success, bool cancelled)
  {
    if (success) {
      try {DejaDup.update_last_run_timestamp();}
      catch (Error e) {warning("%s\n", e.message);}
    }
    
    base.operation_finished(dup, success, cancelled);
  }
  
  protected override List<string>? make_argv() throws Error
  {
    var client = get_gconf_client();
    
    var include_list = parse_dir_list(client.get_list(INCLUDE_LIST_KEY,
                                                      GConf.ValueType.STRING));
    var exclude_list = parse_dir_list(client.get_list(EXCLUDE_LIST_KEY,
                                                      GConf.ValueType.STRING));
    
    List<string> rv = new List<string>();
    
    // Exclude directories no one wants to backup
    var always_excluded = get_always_excluded_dirs();
    foreach (string dir in always_excluded)
      rv.append("--exclude=%s".printf(dir));
    
    foreach (File s in exclude_list)
      rv.append("--exclude=%s".printf(s.get_path()));
    foreach (File s in include_list)
      rv.append("--include=%s".printf(s.get_path()));
    
    rv.append("--exclude=**");
    
    dup.local = "/";
    
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

