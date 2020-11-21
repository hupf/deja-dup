/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Canonical Ltd
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

internal class DuplicityInstance : Object
{
  public signal void done(bool success, bool cancelled);
  public signal void exited(int code);
  public signal void message(string[] control_line, List<string>? data_lines,
                             string user_text);

  public string forced_cache_dir {get; set; default = null;}

  public async void start(List<string> argv_in, List<string>? envp_in)
  {
    try {
      /* Make deep copies of the lists, so if our caller doesn't yield, the
         lists won't be invalidated. */
      var argv = new List<string>();
      foreach (var arg in argv_in)
        argv.append(arg);
      var envp = new List<string>();
      foreach (var env in envp_in)
        envp.append(env);
      if (!yield start_internal(argv, envp))
        done(false, false);
    }
    catch (Error e) {
      // Fake a generic message from duplicity
      message({"ERROR", "1"}, null, e.message);
      done(false, false);
    }
  }

  async bool start_internal(List<string> argv_in, List<string>? envp_in) throws Error
  {
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

    argv.append("--verbosity=9");

    // default timeout is 30s, but bump it to cover flaky connections better
    argv.append("--timeout=120");

    // Cache signature files
    var cache_dir = forced_cache_dir;
    if (cache_dir == null)
      cache_dir = Path.build_filename(Environment.get_user_cache_dir(),
                                      Config.PACKAGE);
    if (cache_dir != null && DejaDup.ensure_directory_exists(cache_dir))
      argv.append("--archive-dir=" + cache_dir);

    // Specify tempdir
    var tempdir = yield DejaDup.get_tempdir();
    if (DejaDup.ensure_directory_exists(tempdir))
      argv.append("--tempdir=%s".printf(tempdir));

    // Testing arguments
    var fast_fail_str = Environment.get_variable("DEJA_DUP_TEST_FAST_FAIL");
    if (fast_fail_str != null && int.parse(fast_fail_str) > 0)
      argv.append("--num-retries=1");

    // Finally, actual duplicity command
    argv.prepend(DuplicityPlugin.duplicity_command());

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

    // Open pipes to communicate with subprocess
    if (Posix.pipe(pipes) != 0)
      return false;

    // Add logging argument (after building user-visible command above, as we
    // don't want users to try to use --log-fd on console and get errors)
    argv.append("--log-fd=%d".printf(pipes[1]));

    string[] real_argv = new string[argv.length()];
    i = 0;
    foreach(string a in argv)
      real_argv[i++] = a;

    // Kill any lockfile, since our cancel methods may leave them around.
    // We already are pretty sure we don't have other duplicities in our
    // archive directories, because we use our own and we ensure we only have
    // one deja-dup running at a time via DBus.
    Posix.system("/bin/rm -f " + Shell.quote(cache_dir) + "/*/lockfile.lock");

    Process.spawn_async_with_pipes(null, real_argv, real_envp,
                        SpawnFlags.SEARCH_PATH |
                        SpawnFlags.DO_NOT_REAP_CHILD |
                        SpawnFlags.LEAVE_DESCRIPTORS_OPEN |
                        SpawnFlags.STDOUT_TO_DEV_NULL |
                        SpawnFlags.STDERR_TO_DEV_NULL,
                        () => {
                          // Drop support for /dev/tty inside duplicity.
                          // See our PASSPHRASE handling for more info.
                          Posix.setsid();
                        }, out child_pid, null, null, null);

    debug("Running the following duplicity (%i) command: %s\n", (int)child_pid, user_cmd);

    watch_id = ChildWatch.add(child_pid, spawn_finished);

    if (pipes[1] != -1)
      Posix.close(pipes[1]);

    yield read_log();
    return true;
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

  uint watch_id;
  Pid child_pid;
  int[] pipes;
  DejaDup.DuplicityLogger logger;
  bool process_done;
  int status;
  construct {
    pipes = new int[2];
    pipes[0] = pipes[1] = -1;
  }

  ~DuplicityInstance()
  {
    if (watch_id != 0)
      Source.remove(watch_id);

    if (is_started()) {
      debug("duplicity (%i) process killed\n", (int)child_pid);
      kill_child();
    }
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

  async void read_log()
  {
    logger = new DejaDup.DuplicityLogger.for_fd(pipes[0]);
    logger.message.connect((l, c, d, t) => message(c, d, t));

    var verbose_str = Environment.get_variable("DEJA_DUP_DEBUG");
    if (verbose_str != null && int.parse(verbose_str) > 0)
      logger.print_to_console = true;

    // This read goes on while rest of class is doing its work.  We ref
    // it to make sure that the rest of the class doesn't drop from under us.
    ref();
    yield logger.read();
    logger.write_tail_to_cache();
    unref();
  }

  void spawn_finished(Pid pid, int status)
  {
    this.status = status;

    if (Process.if_exited(status)) {
      var exitval = Process.exit_status(status);
      debug("duplicity (%i) exited with value %i\n", (int)pid, exitval);
    }
    else {
      debug("duplicity (%i) process killed\n", (int)pid);
    }

    watch_id = 0;
    Process.close_pid(pid);

    process_done = true;
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
  }
}
