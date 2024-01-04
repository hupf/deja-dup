/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

void parse_one_dir (string to_parse, string? result)
{
  if (result != null)
    assert(DejaDup.parse_dir(to_parse).equal(File.new_for_path(result)));
}

void parse_dir()
{
  parse_one_dir("", Environment.get_home_dir());
  parse_one_dir("$HOME", Environment.get_home_dir());
  parse_one_dir("$TRASH", DejaDup.InstallEnv.instance().get_trash_dir());
  parse_one_dir("$DESKTOP", Environment.get_user_special_dir(UserDirectory.DESKTOP));
  parse_one_dir("$DOCUMENTS", Environment.get_user_special_dir(UserDirectory.DOCUMENTS));
  parse_one_dir("$DOWNLOAD", Environment.get_user_special_dir(UserDirectory.DOWNLOAD));
  parse_one_dir("$MUSIC", Environment.get_user_special_dir(UserDirectory.MUSIC));
  parse_one_dir("$PICTURES", Environment.get_user_special_dir(UserDirectory.PICTURES));
  parse_one_dir("$PUBLIC_SHARE", Environment.get_user_special_dir(UserDirectory.PUBLIC_SHARE));
  parse_one_dir("$TEMPLATES", Environment.get_user_special_dir(UserDirectory.TEMPLATES));
  parse_one_dir("/backup/$USER", Path.build_filename("/backup", Environment.get_user_name()));
  parse_one_dir("backup/$USER", Path.build_filename(Environment.get_home_dir(), "backup", Environment.get_user_name()));
  parse_one_dir("$VIDEOS", Environment.get_user_special_dir(UserDirectory.VIDEOS));
  parse_one_dir("VIDEOS", Path.build_filename(Environment.get_home_dir(), "VIDEOS"));
  parse_one_dir("/VIDEOS", "/VIDEOS");
  parse_one_dir("file:///VIDEOS", "/VIDEOS");
  assert(DejaDup.parse_dir("file:VIDEOS").equal(File.parse_name("file:VIDEOS")));
}

void parse_one_version(string str, int maj, int min, int mic)
{
  int pmaj, pmin, pmic;
  assert(DejaDup.parse_version(str, out pmaj, out pmin, out pmic));
  assert(pmaj == maj);
  assert(pmin == min);
  assert(pmic == mic);
}

void parse_bad_version(string str)
{
  int pmaj, pmin, pmic;
  assert(!DejaDup.parse_version(str, out pmaj, out pmin, out pmic));
  assert(pmaj == 0);
  assert(pmin == 0);
  assert(pmic == 0);
}

void parse_version()
{
  parse_bad_version("");
  parse_one_version("a", 0, 0, 0);
  parse_one_version("1", 1, 0, 0);
  parse_one_version("1.2", 1, 2, 0);
  parse_one_version("1.2.3", 1, 2, 3);
  parse_one_version("1.2.3.4", 1, 2, 3);
  parse_one_version("1.2.3a4", 1, 2, 3);
  parse_one_version("1.2a3.4", 1, 2, 4);
  parse_one_version("1.2 3.4", 1, 2, 4);
  parse_one_version("1.2-3.4", 1, 2, 4);
}

void prompt()
{
  var settings = DejaDup.get_settings();

  settings.set_string(DejaDup.PROMPT_CHECK_KEY, "");
  DejaDup.update_prompt_time(true);
  assert(settings.get_string(DejaDup.PROMPT_CHECK_KEY) == "disabled");

  assert(DejaDup.make_prompt_check() == false);
  assert(settings.get_string(DejaDup.PROMPT_CHECK_KEY) == "disabled");
  DejaDup.update_prompt_time(); // shouldn't change anything
  assert(settings.get_string(DejaDup.PROMPT_CHECK_KEY) == "disabled");

  settings.set_string(DejaDup.PROMPT_CHECK_KEY, "");
  assert(DejaDup.make_prompt_check() == false);
  var time_now = settings.get_string(DejaDup.PROMPT_CHECK_KEY);
  assert(time_now != "");
  assert(DejaDup.make_prompt_check() == false);
  assert(settings.get_string(DejaDup.PROMPT_CHECK_KEY) == time_now);

  var cur_time = new DateTime.now_local();
  cur_time = cur_time.add_seconds(-1 * DejaDup.get_prompt_delay());
  cur_time = cur_time.add_hours(1);
  settings.set_string(DejaDup.PROMPT_CHECK_KEY, cur_time.format("%Y-%m-%dT%H:%M:%S%z"));
  assert(DejaDup.make_prompt_check() == false);

  cur_time = cur_time.add_hours(-2);
  settings.set_string(DejaDup.PROMPT_CHECK_KEY, cur_time.format("%Y-%m-%dT%H:%M:%S%z"));
  assert(DejaDup.make_prompt_check() == true);
}

string get_srcdir()
{
  var srcdir = Environment.get_variable("srcdir");
  if (srcdir == null)
    srcdir = ".";
  return srcdir;
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

  Environment.set_variable("PATH",
                           get_srcdir() + "/../mock:" +
                             Environment.get_variable("PATH"),
                           true);

  var unit = new TestSuite("libdeja");
  unit.add(new TestCase("parse-dir", setup, parse_dir, teardown));
  unit.add(new TestCase("parse-version", setup, parse_version, teardown));
  unit.add(new TestCase("prompt", setup, prompt, teardown));
  TestSuite.get_root().add_suite((owned)unit);

  return Test.run();
}
