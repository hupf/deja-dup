/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

// This class does three main things, all centered around "readiness".
// "Readiness" is whether we could/should start a backup now. For example,
// the network is up and unmetered. We're not in low power mode. The external
// drive is plugged in. That sort of thing.
//
// 1) Watching for possible readiness changes
//
// This class watches all the various possible tiggers that might change our
// "ready" state and signals that something changed.
//
// This class is intentionally a little dumb. It doesn't know what the policy
// is, whether we are even scheduled for a backup right now, what storage
// location is even configured, etc. It just messages if any possible trigger
// for any storage location or possible backup changed. Then the policy
// driver (the main monitor process) will decide what to do.
//
// 2) Actually checking readiness
//
// This class also holds the `is_ready` method, which the main monitor process
// may use as part of deciding what to do - but we don't call it ourselves
// prematurely, because it has side effects (like mounting) that we only want
// to initiate if it's time for a backup.
//
// 3) Keeping track of "not yet ready" reasons
//
// In a given "waiting to become ready" cycle (which in practice is a day, as
// that is how long Scheduler will wait on its own to backup again), we keep
// track of the various reasons we weren't ready yet. We do this because we
// don't want to keep nagging the user to plug in their external drive.
//
// And we also want to make sure that if a new not-yet-ready reason appears,
// that we do actually bug the user about it. For example, if we say "we need
// to be connected to the internet please" and they do, but it's a metered
// connection - we need to tell the user about _that_ now (while not bothering
// them about connecting to internet for the rest of the day).

using GLib;

class ReadyWatcher : Object
{
  public signal void maybe_ready(string why); // it's *conceivable* ready status changed

  // sent if we become so unready, we should stop any auto backup (for example,
  // low power mode)
  public signal void stop_auto();

  public bool no_delay {get; set;} // used when manually testing, to avoid timers

  public ReadyWatcher(bool no_delay)
  {
    Object(no_delay: no_delay);
  }

  public async bool is_ready(int days_late, out string message)
  {
    message = null;

    string reason, reason_message;
    var ready = yield is_ready_with_reason(days_late, out reason, out reason_message);

    if (!ready && reason != null && !unready_reasons.contains(reason))
    {
      unready_reasons.add(reason);

      // See the comment above `is_ready_with_reason` for why we split like this
      var parts = reason.split(".");
      if (parts.length > 1) // only support one period for now, can expand as needed
        unready_reasons.add(parts[0]);

      message = reason_message;
    }

    if (!ready && reason != null)
      debug("Backup is not ready yet: %s", reason);

    return ready;
  }

  public void reset_reasons()
  {
    unready_reasons = new GenericSet<string>(str_hash, str_equal);
  }

  ///////////
  uint netcheck_id = 0;
  GenericSet<string> unready_reasons = null;
  GameMode gamemode = null;
  PowerProfileMonitor power_monitor = null;

  construct
  {
    reset_reasons();

    DejaDup.Network.get().notify["connected"].connect(network_changed);
    DejaDup.Network.get().notify["metered"].connect(network_changed);

    var mon = DejaDup.get_volume_monitor();
    mon.volume_added.connect(volume_added);

    gamemode = new GameMode();
    gamemode.notify["enabled"].connect(gamemode_changed);

    power_monitor = PowerProfileMonitor.dup_default();
    power_monitor.notify["power-saver-enabled"].connect(power_saver_changed);
  }

  ~ReadyWatcher()
  {
    if (netcheck_id > 0) {
      Source.remove(netcheck_id);
      netcheck_id = 0;
    }
  }

  // The format for reasons is mostly an opaque string, but we do also split
  // on periods and store those reason strings as well. This is so that
  // when "network-connection" and "network-connection.metered" are both in
  // play, we don't first show the more specific version ("need an unmetered
  // connection") then later show the more generic version ("need a
  // connection") when they disconnect the network. They were already told
  // that. But we do want the other direction -- if we've shown them the
  // generic version, there is still value in letting them know that actually,
  // we need an unmetered connection.
  async bool is_ready_with_reason(int days_late, out string reason, out string message)
  {
    if (gamemode.enabled) {
      reason = "gamemode";
      message = null;
      return false;
    }

    if (power_monitor.power_saver_enabled) {
      // Don't message about this immediately - battery status will fix itself
      // in time, and is almost certainly more important to the user than a new
      // backup. We don't need to nag them about changing power saver status
      // just for us. Unless it's been over a day... maybe they accidentally
      // left low power mode on after manually switching to it? Then we should
      // let them know about the issue so they can correct it and/or be aware we
      // delay backups when saving power.
      if (days_late < 1) {
        reason = "power-saver";
        message = null;
      } else {
        reason = "power-saver.overdue";
        message = _("Backup will begin when power saver mode is no longer active.");
      }
      return false;
    }

    var backend = DejaDup.Backend.get_default();
    var network = DejaDup.Network.get();
    if (!backend.is_native() && !network.connected) {
      reason = "network-connection";
      message = _("Backup will begin when a network connection becomes available.");
      return false;
    }
    else if (!backend.is_native() && network.metered) {
      reason = "network-connection.metered";
      message = _("Backup will begin when an unmetered network connection becomes available.");
      return false;
    }

    return yield backend.is_ready(out reason, out message);
  }

  void volume_added()
  {
    maybe_ready("volume added");
  }

  void gamemode_changed()
  {
    if (gamemode.enabled)
      stop_auto();
    maybe_ready("gamemode changed");
  }

  void power_saver_changed()
  {
    if (power_monitor.power_saver_enabled)
      stop_auto();
    maybe_ready("power saver changed");
  }

  void network_changed()
  {
    // Wait a bit so that (a) user isn't bombarded by notifications as soon as
    // they connect and (b) if this is a transient connection (or a bug as with
    // LP bug 805140) we don't error out too soon.
    if (netcheck_id > 0)
      Source.remove(netcheck_id);

    debug("Network status changed, starting timeout.");
    var delay_time = 120;
    if (no_delay)
      delay_time = 0;
    netcheck_id = Timeout.add_seconds(delay_time, () => {
      netcheck_id = 0;
      maybe_ready("network status changed");
      return Source.REMOVE;
    });
  }
}
