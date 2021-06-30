/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

internal abstract class DejaDup.ToolJoblet : DejaDup.ToolJob
{
  // Public interface
  public ToolJobChain chain {get; set;}

  public override void cancel() { // with cleanup, no success
    disconnect_inst();
    if (cancel_cleanup())
      done(true, false, null); // go to next job
    else
      done(false, true, null);
  }
  public override void stop() { // no cleanup, with success
    disconnect_inst();
    done(true, true, null);
  }
  public override void pause(string? reason) {
    if (inst != null)
      inst.pause();
  }
  public override void resume() {
    if (inst != null)
      inst.resume();
  }

  public override async void start()
  {
    List<string> argv = null;
    List<string> envp = null;

    try {
      yield backend.prepare();
      prepare(ref argv, ref envp); // let subclasses add what they want
    }
    catch (Error e) {
      show_error(e.message);
      done(false, false, null);
      return;
    }

    yield start_inst(argv, envp);
  }

  // Protected interface
  protected abstract ToolInstance make_instance();
  protected abstract void prepare(ref List<string> argv, ref List<string> envp) throws Error;

  // If this returns true, that means you are handling the cancel and you are
  // responsible for calling done().
  // The chain can be assumed to be empty by the time this is called.
  protected virtual bool cancel_cleanup() { return false; }

  protected void add_handler(ulong id) {
    handlers.append(id);
  }

  protected void show_error(string msg, string? detail = null)
  {
    error_issued = true;
    raise_error(msg, detail);
  }

  protected void finish() {
    disconnect_inst();
    done(true, false, null);
  }

  protected void disconnect_inst()
  {
    // Disconnect signals and cancel instance
    if (inst != null) {
      foreach (var id in handlers) {
        inst.disconnect(id);
      }
      handlers = null;

      inst.cancel();
      inst = null;
    }
  }

  // Private data & methods
  ToolInstance inst;
  List<ulong> handlers;
  bool error_issued;

  async void start_inst(List<string> argv, List<string> envp)
  {
    // Out with the old
    disconnect_inst();

    // And in with the new
    inst = make_instance();
    add_handler(inst.done.connect(handle_done));

    yield inst.start(argv, envp);
  }

  protected virtual void handle_done(bool success, bool cancelled)
  {
    if (error_issued)
      success = false;
    else if (!success && !cancelled && !error_issued) {
      // Should emit some sort of error...
      raise_error(_("Failed with an unknown error."), null);
    }

    disconnect_inst();
    done(success, cancelled, null);
  }
}
