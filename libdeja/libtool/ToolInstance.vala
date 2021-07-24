/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

internal abstract class ToolInstance : Object
{
  public signal void done(bool success, bool cancelled);
  public signal void exited(int code);

  public bool verbose {get; private set; default = false;}
  public string forced_cache_dir {get; set; default = null;}

  public async void start(List<string> argv_in, List<string>? envp_in)
  {
    try {
      /* Make deep copies of the lists, so if our caller doesn't yield, the
         lists won't be invalidated. */
      var argv = argv_in.copy_deep(strdup);
      var envp = envp_in.copy_deep(strdup);
      yield start_internal(argv, envp);
    }
    catch (Error e) {
      // Fake a generic message
      _send_error(e);
      done(false, false);
    }
  }

  public bool is_started()
  {
    return (int)child_pid > 0;
  }

  public void cancel()
  {
    if (is_started())
      kill_child();
    else
      done(false, true);
  }

  public void pause()
  {
    if (is_started())
      stop_child();
  }

  public void resume()
  {
    if (is_started())
      cont_child();
  }

  protected abstract void _send_error(Error e);

  protected virtual void _prefix_command(ref List<string> argv) {}

  // true if we finished the stanza
  protected abstract bool _process_line(string stanza, string line) throws Error;

  uint watch_id;
  Pid child_pid;
  bool process_done;
  int status;
  int stdout;
  int stderr;
  MainLoop read_loop;

  ~ToolInstance()
  {
    if (watch_id != 0)
      Source.remove(watch_id);

    if (is_started()) {
      debug("tool (%i) process killed\n", (int)child_pid);
      kill_child();
    }
  }

  async void start_internal(List<string> argv_in, List<string>? envp_in) throws Error
  {
    var verbose_str = Environment.get_variable("DEJA_DUP_DEBUG");
    if (verbose_str != null && int.parse(verbose_str) > 0)
      verbose = true;

    // Copy current environment, add custom variables
    var myenv = Environment.list_variables();
    int myenv_len = 0;
    while (myenv[myenv_len] != null)
      ++myenv_len;

    var env_len = myenv_len + envp_in.length();
    string[] real_envp = new string[env_len + 1];
    int i = 0;
    for (; i < myenv_len; ++i)
      real_envp[i] = "%s=%s".printf(myenv[i], Environment.get_variable(myenv[i]));
    foreach (string env in envp_in)
      real_envp[i++] = env;
    real_envp[i] = null;

    List<string> argv = new List<string>();
    foreach (string arg in argv_in)
      argv.append(arg);

    _prefix_command(ref argv);

    // Grab version of command line to show user
    string user_cmd = null;
    foreach(string a in argv) {
      if (a == null)
        break;
      if (user_cmd == null)
        user_cmd = a;
      else
        user_cmd = "%s %s".printf(user_cmd, Shell.quote(a));
    }

    string[] real_argv = new string[argv.length()];
    i = 0;
    foreach(string a in argv)
      real_argv[i++] = a;

    Process.spawn_async_with_pipes(null, real_argv, real_envp,
                                   SpawnFlags.SEARCH_PATH |
                                   SpawnFlags.DO_NOT_REAP_CHILD,
                                   () => {
                                      // Drop support for /dev/tty inside the tool.
                                      // Helps duplicity with password handling,
                                      // and helps restic with rclone support.
                                      Posix.setsid();
                                   },
                                   out child_pid, null, out stdout, out stderr);

    debug("Running the following tool (%i) command: %s\n", (int)child_pid, user_cmd);

    watch_id = ChildWatch.add(child_pid, spawn_finished);

    yield read_log();
  }

  void kill_child() {
    Posix.kill((Posix.pid_t)child_pid, Posix.Signal.KILL);
  }

  void stop_child() {
    Posix.kill((Posix.pid_t)child_pid, Posix.Signal.STOP);
  }

  void cont_child() {
    Posix.kill((Posix.pid_t)child_pid, Posix.Signal.CONT);
  }

  async void read_log_lines(DataInputStream reader)
  {
    string stanza = "";
    while (reader != null) {
      try {
        if (process_done) {
          if (is_started())
            send_done_for_status();
          break;
        }

        var line = yield reader.read_line_utf8_async();
        if (line == null) { // EOF
          // We're reading faster than the tool can provide.  Wait a bit before trying again.
          var loop = new MainLoop(null);
          Timeout.add_seconds(1, () => {loop.quit(); return false;});
          loop.run();
          continue;
        }

        if (verbose)
          print("TOOL: %s\n", line);

        stanza += line;

        try {
          if (_process_line(stanza, line))
            stanza = "";
        }
        catch (Error err) {
          warning("%s\n", err.message);
          stanza = "";
        }
      }
      catch (Error err) {
        warning("%s\n", err.message);
        break;
      }
    }
  }

  async void read_log()
  {
   /*
    * Asynchronous reading of restic's log via stream
    *
    * Stream initiated either from log file or pipe
    */
    var err_stream = new UnixInputStream(stderr, true);
    var err_reader = new DataInputStream(err_stream);

    var out_stream = new UnixInputStream(stdout, true);
    var out_reader = new DataInputStream(out_stream);

    // This loop goes on while rest of class is doing its work.  We ref
    // it to make sure that the rest of the class doesn't drop from under us.
    ref();
    read_loop = new MainLoop(null);
    read_log_lines.begin(err_reader);
    read_log_lines.begin(out_reader);
    read_loop.run();
    read_loop = null;
    unref();
  }

  void spawn_finished(Pid pid, int status)
  {
    this.status = status;

    if (Process.if_exited(status)) {
      var exitval = Process.exit_status(status);
      debug("tool (%i) exited with value %i\n", (int)pid, exitval);
    }
    else {
      debug("tool (%i) process killed\n", (int)pid);
    }

    watch_id = 0;
    Process.close_pid(pid);

    process_done = true;
    if (read_loop == null)
      send_done_for_status();
  }

  void send_done_for_status()
  {
    bool success = Process.if_exited(status) && Process.exit_status(status) == 0;
    bool cancelled = !Process.if_exited(status);

    if (Process.if_exited(status))
      exited(Process.exit_status(status));

    child_pid = (Pid)0;
    done(success, cancelled);
    read_loop.quit();
  }
}
