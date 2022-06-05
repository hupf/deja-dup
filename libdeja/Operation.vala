/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public abstract class Operation : Object
{
  /**
   * Abstract class that abstracts low level operations of duplicity
   * with specific classes for specific operations
   *
   * Abstract class that defines methods and properties that have to be defined
   * by classes that abstract operations from duplicity. It is generally unnecessary
   * but it is provided to provide easier development and an abstraction layer
   * in case Deja Dup project ever replaces its backend.
   */

  // success is true for normal successful finish or stop()
  // cancelled is true for stop() and cancel()
  public signal void done(bool success, bool cancelled, string? detail);

  public signal void raise_error(string errstr, string? detail);
  public signal void action_desc_changed(string action);
  public signal void action_file_changed(File file, bool actual);
  public signal void progress(double percent);
  public signal void passphrase_required();
  public signal void question(string title, string msg);
  public signal void install(string[] names, string[] ids);
  public signal void is_full(bool first);

  public bool use_cached_password {get; protected set; default = true;}
  public bool needs_password {get; set;}
  public Backend backend {get; protected set;}
  public bool use_progress {get; set; default = true;}

  public ToolJob.Mode mode {get; construct; default = ToolJob.Mode.INVALID;}

  public static string mode_to_string(ToolJob.Mode mode)
  {
    switch (mode) {
    case ToolJob.Mode.BACKUP:
      return _("Backing up…");
    case ToolJob.Mode.RESTORE:
      return _("Restoring…");
    case ToolJob.Mode.STATUS:
      return _("Checking for backups…");
    case ToolJob.Mode.LIST:
      return _("Listing files…");
    default:
      return _("Preparing…");
    }
  }

  // The State functions can be used to carry information from one operation
  // to another.
  public class State {
    public Backend backend;
    public string passphrase;
  }
  public State get_state() {
    var rv = new State();
    rv.backend = backend;
    rv.passphrase = passphrase;
    return rv;
  }
  public void set_state(State state) {
    backend = state.backend;
    set_passphrase(state.passphrase);
  }

  internal ToolJob job;
  protected string passphrase;
  bool finished = false;
  Operation chained_op = null;
  bool searched_for_passphrase = false;
  GenericSet<string?> local_error_files = new GenericSet<string?>(str_hash, str_equal);

  public async virtual void start()
  {
    action_desc_changed(_("Preparing…"));

    yield check_dependencies();
    if (finished) // might have been cancelled during check above
      return;

    string stdout, stderr;
    if (!run_custom_tool_command(DejaDup.CUSTOM_TOOL_SETUP_KEY, out stdout, out stderr)) {
      var detail = (stdout + stderr).strip();
      if (detail == "")
        detail = null;
      raise_error(_("Custom tool setup failed."), detail);
      done(false, false, null);
      return;
    }

    restart();
  }

  void restart()
  {
    if (job != null) {
      SignalHandler.disconnect_matched(job, SignalMatchType.DATA,
                                       0, 0, null, null, this);
      job.stop();
      job = null;
    }

    string support_explanation;
    if (!DejaDup.get_tool().supports_backend(backend.kind, out support_explanation)) {
      raise_error(support_explanation, null);
      done(false, false, null);
      return;
    }

    try {
      job = DejaDup.get_tool().create_job();
    }
    catch (Error e) {
      raise_error(e.message, null);
      done(false, false, null);
      return;
    }

    job.mode = mode;
    job.backend = backend;
    if (!use_progress)
      job.flags |= ToolJob.Flags.NO_PROGRESS;

    make_argv();
    connect_to_job();

    ref(); // don't know what might happen in passphrase_required call

    // Get encryption passphrase if needed
    if (needs_password && passphrase == null)
      find_passphrase_sync(); // will block and call set_passphrase when ready
    else
      job.encrypt_password = passphrase;

    if (!finished)
      job.start.begin();

    unref();
  }

  public void cancel()
  {
    if (chained_op != null)
      chained_op.cancel();
    else if (job != null)
      job.cancel();
    else
      operation_finished.begin(false, true);
  }

  public void stop()
  {
    if (chained_op != null)
      chained_op.stop();
    else if (job != null)
      job.stop();
    else
      operation_finished.begin(true, true);
  }

  protected virtual void connect_to_job()
  {
    /*
     * Connect Deja Dup to signals
     */
    job.done.connect((d, o, c) => {operation_finished.begin(o, c);});
    job.raise_error.connect((d, s, detail) => {raise_error(s, detail);});
    job.action_desc_changed.connect((d, s) => {action_desc_changed(s);});
    job.action_file_changed.connect((d, f, b) => {send_action_file_changed(f, b);});
    job.local_file_error.connect(note_local_file_error);
    job.progress.connect((d, p) => {progress(p);});
    job.question.connect((d, t, m) => {question(t, m);});
    job.is_full.connect((first) => {is_full(first);});
    job.bad_encryption_password.connect(() => {
      // If tool gives us a gpg error, we set needs_password so that
      // we will prompt for it.
      needs_password = true;
      passphrase = null;
      restart();
    });
  }

  protected virtual void send_action_file_changed(File file, bool actual)
  {
    action_file_changed(file, actual);
  }

  public void set_passphrase(string? passphrase)
  {
    needs_password = false;
    this.passphrase = passphrase;
    if (job != null)
      job.encrypt_password = passphrase;
  }

  // Returns any extra info (like specific files that didn't back up)
  protected virtual string? get_success_detail()
  {
    return null;
  }

  void send_done(bool success, bool cancelled)
  {
    string detail = null;
    if (success && !cancelled)
      detail = get_success_detail();

    done(success, cancelled, detail);
  }

  internal async virtual void operation_finished(bool success, bool cancelled)
  {
    finished = true;

    yield backend.cleanup();
    yield DejaDup.clean_tempdirs(false /* just duplicity temp files */);
    run_custom_tool_command(DejaDup.CUSTOM_TOOL_TEARDOWN_KEY);

    send_done(success, cancelled);
  }

  protected virtual List<string>? make_argv()
  {
  /**
   * Abstract method that prepares arguments that will be sent to duplicity
   *
   * Abstract method that will prepare arguments that will be sent to duplicity
   * and return a list of those arguments.
   */
    return null;
  }

  protected async void chain_op(Operation subop, string desc)
  {
    /**
     * Sometimes an operation wants to chain to a separate operation.
     * Here is the glue to make that happen.
     */
    assert(chained_op == null);

    chained_op = subop;
    subop.done.connect((s, c, d) => {
      // ignore detail from chained op for now - can fix if we need to
      send_done(s, c);
      chained_op = null;
    });
    subop.raise_error.connect((e, d) => {raise_error(e, d);});
    subop.progress.connect((p) => {progress(p);});
    subop.passphrase_required.connect(() => {
      needs_password = true;
      find_passphrase_sync();
      if (!needs_password)
        subop.set_passphrase(passphrase);
    });
    subop.question.connect((t, m) => {question(t, m);});
    subop.install.connect((p, i) => {install(p, i);});

    use_cached_password = subop.use_cached_password;
    subop.set_state(get_state());

    action_desc_changed(desc);
    progress(0);

    yield subop.start();
  }

  async string? lookup_keyring()
  {
    try {
      return Secret.password_lookup_sync(DejaDup.get_passphrase_schema(),
                                         null,
                                         "owner", Config.PACKAGE,
                                         "type", "passphrase");
    }
    catch (Error e) {
      warning("%s\n", e.message);
      return null;
    }
  }

  void find_passphrase_sync()
  {
    // First, looks locally in keyring
    if (!searched_for_passphrase && !DejaDup.in_testing_mode() && use_cached_password) {
      // If we get asked for passphrase again, it is because a
      // saved or entered passphrase didn't work.  So don't bother
      // searching a second time.
      searched_for_passphrase = true;

      string str = null;

      // First, try user's keyring
      var loop = new MainLoop(null);
      lookup_keyring.begin((obj, res) => {
        str = lookup_keyring.end(res);
        loop.quit();
      });
      loop.run();

      // Did we get anything?
      if (str != null) {
        set_passphrase(str);
        return;
      }
    }

    passphrase_required();
  }

  // Returns true if the command succeeded
  bool run_custom_tool_command(string key, out string stdout = null, out string stderr = null)
  {
    stdout = null;
    stderr = null;

    var settings = DejaDup.get_settings();
    var command = settings.get_string(key);
    if (command == "")
      return true;

    int status;
    try {
      debug("Running '%s'", command);
      Process.spawn_command_line_sync(command, out stdout, out stderr, out status);
    }
    catch (Error e) {
      stdout = e.message;
      stderr = "";
      return false;
    }

    // echo these to the console to help a user debugging their script
    print(stdout);
    print(stderr);

    return Process.if_exited(status) && Process.exit_status(status) == 0;
  }

  void note_local_file_error(string file)
  {
    local_error_files.add(file);
  }

  protected List<weak string?> get_local_error_files()
  {
    var sorted_error_files = local_error_files.get_values();
    sorted_error_files.sort(strcmp);
    return sorted_error_files;
  }

#if HAS_PACKAGEKIT
  async Pk.Results? get_pk_results(Pk.Client client, Pk.Bitfield bitfield, string[] pkgs)
  {
    Pk.Results results;
    try {
      results = yield client.resolve_async(bitfield, pkgs, null, () => {});
      if (results == null || results.get_error_code() != null)
        return null;
    } catch (IOError.NOT_FOUND e) {
      // This happens when the packagekit daemon isn't running -- it can't find the socket
      return null;
    } catch (Pk.ControlError e) {
      // This can happen when the packagekit daemon isn't installed or can't start(?)
      return null;
    } catch (Error e) {
      // For any other reason I can't foresee, we should just continue and
      // hope for the best, rather than bother the user with it.
      warning("%s\n".printf(e.message));
      return null;
    }

    return results;
  }
#endif

  // Returns true if we're all set, false if we should wait for install
  async void check_dependencies()
  {
#if HAS_PACKAGEKIT
    var deps = backend.get_dependencies();
    foreach (string dep in DejaDup.get_tool().get_dependencies())
      deps += dep;

    var client = new Pk.Client();

    // Check which deps have any version installed
    var bitfield = Pk.Bitfield.from_enums(Pk.Filter.INSTALLED, Pk.Filter.ARCH);
    Pk.Results results = yield get_pk_results(client, bitfield, deps);
    if (results == null)
      return;

    // Convert that to a set
    var installed = new GenericSet<string>(str_hash, str_equal);
    var package_array = results.get_package_array();
    for (var i = 0; i < package_array.length; i++) {
      installed.add(package_array.data[i].get_name());
    }

    // Now see which packages we actually have to bother installing
    string[] uninstalled = {};
    foreach (string pkg in deps) {
      if (!installed.contains(pkg))
        uninstalled += pkg;
    }
    if (uninstalled.length == 0)
      return;

    // Now get the list of uninstalled (we do both passes, because if there is
    // an update for a package, the new version can be returned here, even if
    // there is an older version installed -- NEWEST or NOT_NEWEST does not
    // affect this behavior).
    bitfield = Pk.Bitfield.from_enums(Pk.Filter.NOT_INSTALLED, Pk.Filter.ARCH, Pk.Filter.NEWEST);
    results = yield get_pk_results(client, bitfield, uninstalled);
    if (results == null)
      return;

    // Convert from List to arrays
    package_array = results.get_package_array();
    var package_ids = new string[0];
    var package_names = new string[0];
    for (var i = 0; i < package_array.length; i++) {
      package_names += package_array.data[i].get_name();
      package_ids += package_array.data[i].get_id();
    }

    if (package_names.length > 0)
      install(package_names, package_ids); // will block
#endif
  }
}

} // end namespace

