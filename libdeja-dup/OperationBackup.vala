/* -*- Mode: C; indent-tabs-mode: nil; c-basic-offset: 2; tab-width: 2 -*- */
/*
    Déjà Dup
    © 2008 Michael Terry <mike@mterry.name>

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

errordomain BackupError {
  INTERNAL
}

public class OperationBackup : Operation
{
  public OperationBackup(Gtk.Window? win) {
    toplevel = win;
  }
  
  public override void start() throws Error
  {
    action_desc_changed(_("Backing up files..."));
    base.start();
  }
  
  protected override void operation_finished(Duplicity dup, bool success, bool cancelled)
  {
    if (cancelled && dup.is_started()) {
      // We have to cleanup after aborted job
      var clean = new OperationCleanup(toplevel);
      clean.done += (b, s) => {Gtk.main_quit();};
      
      try {clean.start();}
      catch (Error e) {printerr("%s\n", e.message);}
      
      Gtk.main();
    }
    
    if (success) {
      try {DejaDup.update_last_run_timestamp();}
      catch (Error e) {printerr("%s\n", e.message);}
    }
    
    done(success);
  }
  
  protected override List<string>? make_argv() throws Error
  {
    var target = backend.get_location();
    if (target == null)
      throw new BackupError.INTERNAL(_("Could not connect to backup location"));
    
    var client = GConf.Client.get_default();
    
    var include_list = parse_dir_list(client.get_list(INCLUDE_LIST_KEY,
                                                      GConf.ValueType.STRING));
    var exclude_list = parse_dir_list(client.get_list(EXCLUDE_LIST_KEY,
                                                      GConf.ValueType.STRING));
    var options = backend.get_options();
    
    List<string> rv = new List<string>();
    int i = 0;
    rv.append("duplicity");
    
    if (options != null) {
      for (int j = 0; j < options.length; ++j)
        rv.append(options[j]);
    }
    
    if (!client.get_bool(ENCRYPT_KEY))
      rv.append("--no-encryption");
    foreach (File s in exclude_list)
      rv.append("--exclude=%s".printf(s.get_path()));
    foreach (File s in include_list)
      rv.append("--include=%s".printf(s.get_path()));
    rv.append("--exclude=**");
    rv.append("/");
    rv.append(target);
    
    return rv;
  }
}

} // end namespace

