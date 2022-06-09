/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

// This class handles the details of telling us when we should try to back up.
// It will send a signal when it is time for a scheduled backup.
//
// In the happy path, a backup will be started and when it finishes, the
// LAST_BACKUP_KEY will be set, causing this class to recalculate the next
// backup and it will send a signal then. Rince and repeat.
//
// In the error case, maybe the storage location wasn't available. Or the
// backup got interrupted. Or the network connection is metered.
//
// Whatever the case, this Scheduler class will actually schedule a fresh
// backup signal every day, until LAST_BACKUP_KEY is set. This way, if anything
// goes wrong at all, we at least will try once a day.
//
// We may try more often, as the monitor will likely check backup conditions
// frequently as various triggers happen. But this class's signals are the
// minimum promised - even if the monitor process never tries on its own, we
// will prompt it to try once a day.

using GLib;

class Scheduler : Object
{
  public signal void backup(); // a backup should be attempted
  public signal void quit(); // monitor should quit, auto backups are off

  // Better to look for the backup() signal than to monitor changes to these props
  public bool past_due {get; protected set;}
  public int days_late {get; protected set;} // zero if < 24 hours due

  ///////////
  uint timeout_id = 0;
  DejaDup.FilteredSettings settings = null;

  construct
  {
    settings = DejaDup.get_settings();
    settings.changed.connect(settings_changed);

    timeout_id = Idle.add(() => {
      timeout_id = 0;
      prepare_next_run();
      return Source.REMOVE;
    });

    // silences a valac warning about not using this method (it's used in tests)
    _get_timer_id();
  }

  ~Scheduler()
  {
    if (timeout_id > 0) {
      Source.remove(timeout_id);
      timeout_id = 0;
    }
  }

  TimeSpan time_until(DateTime date)
  {
    return date.difference(new DateTime.now_local());
  }

  bool time_until_next_run(out TimeSpan time)
  {
    time = 0;

    var next_date = DejaDup.next_run_date();
    if (next_date == null)
      return false;

    time = time_until(next_date);
    return true;
  }

  void settings_changed(string key)
  {
    if (key == DejaDup.LAST_BACKUP_KEY ||
        key == DejaDup.PERIODIC_KEY ||
        key == DejaDup.PERIODIC_PERIOD_KEY)
      prepare_next_run();
  }

  void prepare_next_run()
  {
    if (timeout_id > 0) {
      Source.remove(timeout_id);
      timeout_id = 0;
    }

    TimeSpan wait_time;
    var enabled = time_until_next_run(out wait_time);

    if (!enabled || wait_time > 0) {
      past_due = false;
      days_late = 0;
    }
    // else it will be set to true in initiate_backup - don't set it true now
    // to avoid badly timed triggers for notify["past-due"]

    if (!enabled) {
      // automatic backups are disabled - just quit
      debug("Automatic backups disabled. Stopping monitor.");
      quit();
      return;
    }

    prepare_run(wait_time);
  }

  void prepare_tomorrow()
  {
    var now = new DateTime.now_local();
    var tomorrow = now.add(DejaDup.get_day());
    var time = time_until(tomorrow);
    prepare_run(time);
  }

  void prepare_run(TimeSpan wait_time)
  {
    // Stop previous run timeout
    if (timeout_id > 0) {
      Source.remove(timeout_id);
      timeout_id = 0;
    }

    TimeSpan secs = wait_time / TimeSpan.SECOND + 1;
    if (wait_time > 0 && secs > 0) {
      debug("Waiting %ld seconds until next backup.", (long)secs);
      timeout_id = Timeout.add_seconds((uint)secs, () => {
        timeout_id = 0;
        initiate_backup();
        return Source.REMOVE;
      });
    }
    else {
      debug("Late by %ld seconds. Backing up now.", (long)(secs * -1));
      initiate_backup();
    }
  }

  void initiate_backup()
  {
    // First, schedule another backup in a day. See comment at top of file for why
    prepare_tomorrow();

    days_late = 0;
    TimeSpan wait_time;
    if (time_until_next_run(out wait_time))
      days_late = (int)(-wait_time / DejaDup.get_day());

    past_due = true;
    backup();
  }

  // For testing purposes only
  public uint _get_timer_id() { return timeout_id; }
}
