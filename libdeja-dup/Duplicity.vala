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

[CCode (cheader_filename = "sys/wait.h")]
public class Duplicity : Object
{
  public signal void done(bool success, bool cancelled);
  public signal void raise_error(string errstr);
  
  public Gtk.Window toplevel {get; construct;}
  
  bool verbose = false;
  
  public Duplicity(Gtk.Window? win) {
    toplevel = win;
  }
  
  public void start(List<string> argv, List<string> envp) throws SpawnError
  {
    var verbose_str = Environment.get_variable("DEJA_DUP_DEBUG");
    if (verbose_str != null && verbose_str.to_int() > 0)
      verbose = true;
    
    // Copy current environment, add custom variables
    var myenv = Environment.list_variables();
    int myenv_len = 0;
    while (myenv[myenv_len] != null)
      ++myenv_len;
    
    var env_len = myenv_len + envp.length();
    string[] real_envp = new string[env_len + 1];
    int i = 0;
    for (; i < myenv_len; ++i)
      real_envp[i] = "%s=%s".printf(myenv[i], Environment.get_variable(myenv[i]));
    foreach (string env in envp)
      real_envp[i++] = env;
    real_envp[i] = null;
    
    // Open pipes to communicate with subprocess
    if (pipe(pipes) != 0) {
      done(false, false);
      return;
    }
    
    if (verbose)
      argv.prepend("--verbosity=9");
    
    // Add always-there arguments
    argv.prepend("--log-fd=%d".printf(pipes[1]));
    argv.prepend("duplicity");
    
    string cmd = null;
    string[] real_argv = new string[argv.length()];
    i = 0;
    foreach(string a in argv) {
      real_argv[i++] = a;
      if (cmd == null)
        cmd = a;
      else if (a != null)
        cmd = "%s %s".printf(cmd, a);
    }
    debug("Running the following duplicity command: %s", cmd);
    
    Process.spawn_async_with_pipes(null, real_argv, real_envp,
                        SpawnFlags.SEARCH_PATH |
                        SpawnFlags.DO_NOT_REAP_CHILD |
                        SpawnFlags.LEAVE_DESCRIPTORS_OPEN |
                        SpawnFlags.STDOUT_TO_DEV_NULL |
                        SpawnFlags.STDERR_TO_DEV_NULL,
                        null, out child_pid, null, null, null);
    
    reader = new IOChannel.unix_new(pipes[0]);
    stanza_id = reader.add_watch(IOCondition.IN, read_stanza);
    close(pipes[1]);
    
    ChildWatch.add(child_pid, spawn_finished);
  }
  
  uint stanza_id;
  Pid child_pid;
  int[] pipes;
  IOChannel reader;
  bool error_issued;
  construct {
    reader = null;
    pipes = new int[2];
    pipes[0] = pipes[1] = -1;
    error_issued = false;
  }
  
  public bool is_started()
  {
    return (int)child_pid > 0;
  }
  
  bool read_stanza(IOChannel channel, IOCondition cond)
  {
    string result;
    int len;
    try {
      IOStatus status;
      List<string> stanza = new List<string>();
      while (true) {
        status = channel.read_line(out result, null, null);
        if (status == IOStatus.NORMAL && result != "\n") {
          if (verbose)
            print("DUPLICITY: %s", result); // result has line ending
          stanza.append(result);
        }
        else
          break;
      }
      
      if (verbose)
        print("\n"); // breather
      
      process_stanza(stanza);
    }
    catch (Error e) {
      printerr("%s\n", e.message);
    }
    
    return true;
  }
  
  void process_stanza(List<string> stanza)
  {
    var firstline = stanza.data.split(" ");
    var keyword = firstline[0];
    if (keyword == "ERROR") {
      var errorstr = grab_stanza_text(stanza);
      error_issued = true;
      
      raise_error(errorstr);
    }
  }
  
  string grab_stanza_text(List<string> stanza)
  {
    string text = "";
    foreach (string line in stanza) {
      if (line.has_prefix(". ")) {
        var split = line.split(". ", 2);
        text = "%s%s".printf(text, split[1]);
      }
    }
    return text.chomp();
  }
  
  void spawn_finished(Pid pid, int status)
  {
    if (stanza_id != 0)
      Source.remove(stanza_id);
    
    bool success = Process.if_exited(status) && Process.exit_status(status) == 0;
    bool cancelled = !Process.if_exited(status);
    
    if (reader != null) {
      // Get last reads in before we shut down (needed sometimes, not sure why)
      while (true) {
        IOCondition cond = reader.get_buffer_condition();
        if (cond == IOCondition.IN)
          read_stanza(reader, cond);
        else
          break;
      }
      
      if (Process.if_exited(status)) {
        var exitval = Process.exit_status(status);
        debug("duplicity exited with value %i", exitval);
        
        if (exitval != 0) {
          if (!error_issued) {
            raise_error(_("Failed with an unknown error."));
          }
        }
      }
      
      try {
        reader.shutdown(false);
      } catch (Error e) {
        printerr("%s\n", e.message);
      }
      reader = null;
    }
    
    Process.close_pid(pid);
    
    done(success, cancelled);
  }
  
  public void cancel()
  {
    if (is_started())
      kill((int)child_pid, 15);
    else
      done(false, true);
  }
}

} // end namespace

