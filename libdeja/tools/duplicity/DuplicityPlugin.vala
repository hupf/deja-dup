/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class DuplicityPlugin : DejaDup.ToolPlugin
{
  bool has_been_setup = false;

  construct
  {
    name = "Duplicity";
  }

  public override string[] get_dependencies()
  {
    return Config.DUPLICITY_PACKAGES.split(",");
  }

  const int REQUIRED_MAJOR = 0;
  const int REQUIRED_MINOR = 7;
  const int REQUIRED_MICRO = 14;
  void do_initial_setup () throws Error
  {
    string output;
    Process.spawn_command_line_sync("duplicity --version", out output, null, null);

    var tokens = output.split(" ");
    if (tokens == null || tokens.length < 2 )
      throw new SpawnError.FAILED(_("Could not understand duplicity version."));

    // In version 0.6.25, the output from duplicity --version changed and the
    // string "duplicity major.minor.micro" is now preceded by a deprecation
    // warning.  As a consequence, the substring "major.minor.micro" is now
    // always the penultimate token (the last one always being null).
    var version_string = tokens[tokens.length - 1].strip();

    int major, minor, micro;
    if (!DejaDup.parse_version(version_string, out major, out minor, out micro))
      throw new SpawnError.FAILED(_("Could not understand duplicity version ‘%s’.").printf(version_string));

    if (!DejaDup.meets_version(major, minor, micro, REQUIRED_MAJOR, REQUIRED_MINOR, REQUIRED_MICRO)) {
      var msg = _("Déjà Dup Backup Tool requires at least version %d.%d.%.2d of duplicity, " +
                  "but only found version %d.%d.%.2d");
      throw new SpawnError.FAILED(msg.printf(REQUIRED_MAJOR, REQUIRED_MINOR, REQUIRED_MICRO, major, minor, micro));
    }
  }

  public override DejaDup.ToolJob create_job () throws Error
  {
    if (!has_been_setup) {
      do_initial_setup();
      has_been_setup = true;
    }
    return new DuplicityJob();
  }
}
