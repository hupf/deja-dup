/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class DuplicityPlugin : DejaDup.ToolPlugin
{
  bool has_been_setup = false;
  string version = null;
  bool supports_microsoft = false;

  construct
  {
    name = "duplicity";
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
    if (has_been_setup)
      return;

    string output;
    Process.spawn_sync(null, {duplicity_command(), "--version"}, null,
                       SpawnFlags.SEARCH_PATH, null, out output);

    var tokens = output.split(" ");
    if (tokens == null || tokens.length < 2)
      throw new SpawnError.FAILED(_("Could not understand duplicity version."));

    // In version 0.6.25, the output from duplicity --version changed and the
    // string "duplicity major.minor.micro" is now preceded by a deprecation
    // warning.  As a consequence, the substring "major.minor.micro" is now
    // always the penultimate token (the last one always being null).
    this.version = tokens[tokens.length - 1].strip();

    int major, minor, micro;
    if (!DejaDup.parse_version(version, out major, out minor, out micro))
      throw new SpawnError.FAILED(_("Could not understand duplicity version ‘%s’.").printf(version));

    if (!DejaDup.meets_version(major, minor, micro, REQUIRED_MAJOR, REQUIRED_MINOR, REQUIRED_MICRO)) {
      var msg = _("Backups requires at least version %d.%d.%.2d of duplicity, " +
                  "but only found version %d.%d.%.2d");
      throw new SpawnError.FAILED(msg.printf(REQUIRED_MAJOR, REQUIRED_MINOR, REQUIRED_MICRO, major, minor, micro));
    }

    // 0.8.18 first landed support for OAUTH2_REFRESH_TOKEN, but then it got accidentally reverted.
    supports_microsoft = DejaDup.equals_version(major, minor, micro, 0, 8, 18) ||
                         DejaDup.meets_version(major, minor, micro, 0, 8, 21);

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
    return new DuplicityJob();
  }

  public override bool supports_backend(DejaDup.Backend.Kind kind, out string explanation)
  {
    explanation = null;

    try {
      do_initial_setup();
    } catch (Error e) {
      explanation = e.message;
      return false;
    }

    switch(kind) {
      case DejaDup.Backend.Kind.LOCAL:
      case DejaDup.Backend.Kind.GVFS:
      case DejaDup.Backend.Kind.GOOGLE:
        return true;

      case DejaDup.Backend.Kind.MICROSOFT:
        return supports_microsoft;

      default:
        explanation = _(
            "This storage location is no longer supported. You can still use " +
            "duplicity directly to back up or restore your files."
        );
        return false;
    }
  }

  public static string duplicity_command()
  {
    var testing_str = Environment.get_variable("DEJA_DUP_TESTING");
    if (testing_str != null && int.parse(testing_str) > 0)
      return "duplicity";
    else
      return Config.DUPLICITY_COMMAND;
  }
}
