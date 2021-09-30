/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

MainLoop loop;
Scheduler scheduler;
ReadyWatcher ready_watcher;

bool no_delay = false;
bool replace = false;
bool show_version = false;
const OptionEntry[] OPTIONS = {
  {"no-delay", 0, OptionFlags.HIDDEN, OptionArg.NONE, ref no_delay, null, null},
  {"replace", 0, OptionFlags.HIDDEN, OptionArg.NONE, ref replace, null, null},
  {"version", 0, 0, OptionArg.NONE, ref show_version, N_("Show version"), null},
  {null}
};

bool handle_options(out int status)
{
  status = 0;

  if (show_version) {
    print("%s %s\n", "deja-dup-monitor", Config.VERSION);
    return false;
  }

  return true;
}

async void kickoff()
{
  string unready_message;
  bool ready = yield ready_watcher.is_ready(out unready_message);
  if (!ready) {
    if (unready_message != null) {
      yield BackupInterface.notify_not_ready(unready_message);
    }
    return;
  }

  debug("Running automatic backup.");
  yield BackupInterface.start_auto();
}

// Just a simple wrapper around kickoff that ensures we only are trying to
// kickoff one at a time. This is because we might have multiple kickoff
// triggers happening around the same time (Scheduler, network notifications,
// drives being connected, who knows -- they could happen simultaneously).
// This is exacerbated by the fact that kickoff might take a moment to check
// the ready status of the backend.
bool kicking_off = false;
async void single_kickoff()
{
  if (!kicking_off) {
    kicking_off = true;
    yield kickoff();
    kicking_off = false;
  } else {
    debug("Tried to kickoff twice.");
  }
}

async void stop_and_quit()
{
  yield BackupInterface.stop_auto();
  loop.quit();
}

void make_first_check()
{
  DejaDup.make_prompt_check();

  scheduler = new Scheduler();
  ready_watcher = new ReadyWatcher(no_delay);

  scheduler.backup.connect(() => {
    ready_watcher.reset_reasons();
    single_kickoff.begin();
  });

  scheduler.quit.connect(() => {
    stop_and_quit.begin();
  });

  ready_watcher.maybe_ready.connect(() => {
    if (scheduler.past_due)
      single_kickoff.begin();
  });

  ready_watcher.stop_auto.connect(() => {
    BackupInterface.stop_auto.begin();
  });
}

// Used when debugging, to force a backup
bool on_sigusr1()
{
  debug("Starting auto backup per signal request.");
  BackupInterface.start_auto.begin();
  return Source.CONTINUE;
}

void begin_monitoring()
{
  // initialize network proxy, just so it can settle by the time we check it
  DejaDup.Network.get();

  DejaDup.InstallEnv.instance().register_monitor_restart(loop);
  Unix.signal_add (Posix.Signal.USR1, on_sigusr1);

  // Delay first check to give the network and desktop environment a chance to start up.
  var delay_time = 120;
  if (no_delay)
    delay_time = 0;
  Timeout.add_seconds(delay_time, () => {make_first_check(); return Source.REMOVE;});
}

int main(string[] args)
{
  DejaDup.i18n_setup();

  // Translators: Monitor in this sense means something akin to 'watcher', not
  // a computer screen.  This program acts like a daemon that kicks off
  // backups at scheduled times.
  Environment.set_application_name(_("Backup Monitor"));

  OptionContext context = new OptionContext("");
  context.add_main_entries(OPTIONS, Config.GETTEXT_PACKAGE);
  try {
    context.parse(ref args);
  } catch (Error e) {
    printerr("%s\n\n%s", e.message, context.get_help(true, null));
    return 1;
  }

  int status;
  if (!handle_options(out status))
    return status;

  DejaDup.initialize();

  var name_flags = BusNameOwnerFlags.DO_NOT_QUEUE | BusNameOwnerFlags.ALLOW_REPLACEMENT;
  if (replace)
    name_flags |= BusNameOwnerFlags.REPLACE;
  name_flags = BusNameOwnerFlags.NONE;

  loop = new MainLoop(null, false);
  Idle.add(() => {
    // quit if we can't get the bus name or become disconnected
    Bus.own_name(BusType.SESSION, Config.APPLICATION_ID + ".Monitor",
                 name_flags,
                 ()=>{},
                 ()=>{begin_monitoring();},
                 ()=>{loop.quit();});
    return Source.REMOVE;
  });
  loop.run();

  scheduler = null;
  ready_watcher = null;
  loop = null;
  return 0;
}
