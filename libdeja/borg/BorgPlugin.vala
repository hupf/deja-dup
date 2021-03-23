/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;


public class BorgPlugin : DejaDup.ToolPlugin
{
  bool has_been_setup = false;
  string version = null;

  construct
  {
    name = "borg";
  }

  public override string[] get_dependencies()
  {
    return Config.BORG_PACKAGES.split(",");
  }

  const int REQUIRED_MAJOR = 1;
  const int REQUIRED_MINOR = 1;
  const int REQUIRED_MICRO = 5;
  void do_initial_setup () throws Error
  {
    if (has_been_setup)
      return;

    string output, stderr;
    Process.spawn_command_line_sync("borg --version", out output, out stderr, null);

    var tokens = output.split(" ");
    if (tokens == null || tokens.length != 2)
      tokens = stderr.split(" "); // sometimes borg prints version on stderr...?
    if (tokens == null || tokens.length != 2)
      throw new SpawnError.FAILED(("Could not understand borg version."));

    this.version = tokens[1].strip();

    int major, minor, micro;
    if (!DejaDup.parse_version(version, out major, out minor, out micro))
      throw new SpawnError.FAILED(("Could not understand borg version ‘%s’.").printf(version));

    if (!DejaDup.meets_version(major, minor, micro, REQUIRED_MAJOR, REQUIRED_MINOR, REQUIRED_MICRO)) {
      var msg = ("Déjà Dup Backup Tool requires at least version %d.%d.%.2d of borg, " +
                 "but only found version %d.%d.%.2d");
      throw new SpawnError.FAILED(msg.printf(REQUIRED_MAJOR, REQUIRED_MINOR, REQUIRED_MICRO, major, minor, micro));
    }

    has_been_setup = true;
  }

  public override string get_version() throws Error
  {
    do_initial_setup();
    return this.version;
  }

  public override DejaDup.ToolJob create_job() throws Error
  {
    do_initial_setup();
    return new BorgJob();
  }

  public override bool supports_backend(DejaDup.Backend.Kind kind, out string explanation)
  {
    explanation = null;

    switch(kind) {
      case DejaDup.Backend.Kind.LOCAL:
        return true;

      default:
        explanation = (
            "This storage location is no yet supported. Please turn off the " +
            "experimental borg support if you want to use this location."
        );
        return false;
    }
  }

  public static string borg_command()
  {
    var testing_str = Environment.get_variable("DEJA_DUP_TESTING");
    if (testing_str != null && int.parse(testing_str) > 0)
      return "borg";
    else
      return Config.BORG_COMMAND;
  }
}
