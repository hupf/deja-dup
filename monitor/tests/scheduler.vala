/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

void run_scheduler(Scheduler scheduler, out bool backup, out bool quit)
{
  var backup_count = 0;
  var quit_count = 0;
  var backup_id = scheduler.backup.connect(() => {backup_count++;});
  var quit_id = scheduler.quit.connect(() => {quit_count++;});

  var loop = new MainLoop(null, false);
  Idle.add(() => {loop.quit(); return Source.REMOVE;});
  loop.run();

  scheduler.disconnect(backup_id);
  scheduler.disconnect(quit_id);

  // should never happen twice in a single idle loop
  assert_cmpint(backup_count, CompareOperator.LT, 2);
  assert_cmpint(quit_count, CompareOperator.LT, 2);

  backup = backup_count > 0;
  quit = quit_count > 0;
}

Source get_timer(Scheduler scheduler)
{
  var timer_id = scheduler._get_timer_id();
  assert_cmpuint(timer_id, CompareOperator.GT, 0);

  var context = MainContext.@default();
  var source = context.find_source_by_id(timer_id);

  assert_false(source.is_destroyed());
  return source;
}

// Confirm a and b are close, within seconds. Designed to deal with minor
// variances with mainloop processing etc.
void assert_timespan_close(TimeSpan a, TimeSpan b)
{
  var a_sec = a / TimeSpan.SECOND;
  var b_sec = b / TimeSpan.SECOND;
  var diff = a_sec - b_sec;
  if (diff > 2 || diff < -2)
    assert_cmpvariant(new Variant.int64(a_sec), new Variant.int64(b_sec));
}

void assert_timer_delta(Scheduler scheduler, TimeSpan expect_delta)
{
  var timer = get_timer(scheduler);
  var delta_msec = timer.get_ready_time() - timer.get_time();
  assert_timespan_close(delta_msec, expect_delta);
}

void assert_timer_next_period(Scheduler scheduler, int days)
{
  var target_date = DejaDup.most_recent_scheduled_date(TimeSpan.DAY * days);
  target_date = target_date.add(TimeSpan.DAY * days);
  var target_msec = target_date.to_unix() * TimeSpan.SECOND;
  var target_delta = target_msec - get_real_time();

  assert_timer_delta(scheduler, target_delta);
}

void assert_inactive(Scheduler scheduler)
{
  bool backup, quit;
  run_scheduler(scheduler, out backup, out quit);
  assert_false(quit);
  assert_false(backup);
  assert_false(scheduler.past_due);
}

void assert_backup(Scheduler scheduler)
{
  bool backup, quit;
  run_scheduler(scheduler, out backup, out quit);
  assert_false(quit);
  assert_true(backup);
  assert_true(scheduler.past_due);
}

void assert_quit(Scheduler scheduler)
{
  bool backup, quit;
  run_scheduler(scheduler, out backup, out quit);
  assert_true(quit);
  assert_false(backup);
  assert_false(scheduler.past_due);
  assert_cmpuint(scheduler._get_timer_id(), CompareOperator.EQ, 0);
}

void fast_forward(Scheduler scheduler)
{
  var timer = get_timer(scheduler);
  timer.set_ready_time(0);
}

//// test methods

void quit_on_start()
{
  var scheduler = new Scheduler();
  assert_quit(scheduler);
}

void backup_on_start()
{
  var settings = new Settings(Config.APPLICATION_ID);
  settings.set_boolean(DejaDup.PERIODIC_KEY, true);

  var scheduler = new Scheduler();
  assert_backup(scheduler);
}

void daily_fallback()
{
  var settings = new Settings(Config.APPLICATION_ID);
  settings.set_boolean(DejaDup.PERIODIC_KEY, true);

  var scheduler = new Scheduler();
  assert_backup(scheduler);
  assert_timer_delta(scheduler, TimeSpan.DAY);

  fast_forward(scheduler);
  assert_backup(scheduler);
  assert_timer_delta(scheduler, TimeSpan.DAY);
}

void notices_periodic_changes()
{
  var settings = new Settings(Config.APPLICATION_ID);
  settings.set_boolean(DejaDup.PERIODIC_KEY, true);

  var scheduler = new Scheduler();
  assert_backup(scheduler);

  Idle.add(() => {settings.set_boolean(DejaDup.PERIODIC_KEY, false); return Source.REMOVE;});
  assert_quit(scheduler);

  Idle.add(() => {settings.set_boolean(DejaDup.PERIODIC_KEY, true); return Source.REMOVE;});
  assert_backup(scheduler);
}

void notices_period_changes()
{
  var now = new DateTime.now_utc();
  var settings = new Settings(Config.APPLICATION_ID);
  settings.set_string(DejaDup.LAST_BACKUP_KEY, now.format_iso8601());
  settings.set_boolean(DejaDup.PERIODIC_KEY, true);
  settings.set_int(DejaDup.PERIODIC_PERIOD_KEY, 4);

  var scheduler = new Scheduler();
  assert_inactive(scheduler);
  assert_timer_next_period(scheduler, 4);

  settings.set_int(DejaDup.PERIODIC_PERIOD_KEY, 9);
  assert_timer_next_period(scheduler, 9);

  settings.set_int(DejaDup.PERIODIC_PERIOD_KEY, 0);
  assert_timer_next_period(scheduler, 1);
}

void period_change_overdue()
{
  var settings = new Settings(Config.APPLICATION_ID);
  settings.set_boolean(DejaDup.PERIODIC_KEY, true);

  var recent_backup = new DateTime.now_utc().add(-2 * TimeSpan.DAY);
  settings.set_string(DejaDup.LAST_BACKUP_KEY, recent_backup.format_iso8601());

  // We want to find a period that will avoid landing within the last two days,
  // so we can simulate the backup from two days ago satisfying our period.
  var period = 5;
  while (true) {
    var period_boundary = DejaDup.most_recent_scheduled_date(TimeSpan.DAY * period);
    if (period_boundary.compare(recent_backup) < 0)
      break;
    period++;
  }
  settings.set_int(DejaDup.PERIODIC_PERIOD_KEY, period);

  var scheduler = new Scheduler();
  assert_inactive(scheduler);
  assert_timer_next_period(scheduler, period);

  Idle.add(() => {settings.set_int(DejaDup.PERIODIC_PERIOD_KEY, 1); return Source.REMOVE;});
  assert_backup(scheduler);
}

void notices_last_backup_changes()
{
  var settings = new Settings(Config.APPLICATION_ID);
  settings.set_boolean(DejaDup.PERIODIC_KEY, true);
  settings.set_int(DejaDup.PERIODIC_PERIOD_KEY, 20);

  var scheduler = new Scheduler();
  assert_backup(scheduler);
  assert_timer_delta(scheduler, TimeSpan.DAY);

  var now = new DateTime.now_utc();
  settings.set_string(DejaDup.LAST_BACKUP_KEY, now.format_iso8601());
  assert_timer_next_period(scheduler, 20);
}

void setup()
{
}

void reset_keys(Settings settings)
{
  var source = SettingsSchemaSource.get_default();
  var schema = source.lookup(settings.schema_id, true);

  foreach (string key in schema.list_keys())
    settings.reset(key);

  foreach (string child in schema.list_children())
    reset_keys(settings.get_child(child));
}

void teardown()
{
  reset_keys(new Settings(Config.APPLICATION_ID));
}

int main(string[] args)
{
  Test.init(ref args);

  var unit = new TestSuite("scheduler");
  unit.add(new TestCase("quit-on-start", setup, quit_on_start, teardown));
  unit.add(new TestCase("backup-on-start", setup, backup_on_start, teardown));
  unit.add(new TestCase("daily-fallback", setup, daily_fallback, teardown));
  unit.add(new TestCase("periodic-changes", setup, notices_periodic_changes, teardown));
  unit.add(new TestCase("period-changes", setup, notices_period_changes, teardown));
  unit.add(new TestCase("period-overdue", setup, period_change_overdue, teardown));
  unit.add(new TestCase("backup-changes", setup, notices_last_backup_changes, teardown));
  TestSuite.get_root().add_suite((owned)unit);

  return Test.run();
}
