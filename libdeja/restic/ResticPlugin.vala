/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class ResticPlugin : DejaDup.ToolPlugin
{
  bool has_been_setup = false;
  string version = null;

  construct
  {
    name = "restic";

    // Restic requires a password as a matter of policy:
    // https://github.com/restic/restic/issues/1018
    requires_encryption = true;
  }

  public override string[] get_dependencies()
  {
    return string.join(",", Config.RESTIC_PACKAGES, Config.RCLONE_PACKAGES).split(",");
  }

  const int REQUIRED_MAJOR = 0;
  const int REQUIRED_MINOR = 14;
  const int REQUIRED_MICRO = 0;
  void do_initial_setup () throws Error
  {
    if (has_been_setup)
      return;

    string output;
    Process.spawn_sync(null, {restic_command(), "version"}, null,
                       SpawnFlags.SEARCH_PATH, null, out output);

    var tokens = output.split(" ");
    if (tokens == null || tokens.length < 2)
      throw new SpawnError.FAILED(_("Could not understand restic version."));

    // sample output: "restic 0.12.0 compiled with go1.15.8 on linux/amd64"
    this.version = tokens[1].strip();

    int major, minor, micro;
    if (!DejaDup.parse_version(version, out major, out minor, out micro))
      throw new SpawnError.FAILED(_("Could not understand restic version ‘%s’.").printf(version));

    if (!DejaDup.meets_version(major, minor, micro, REQUIRED_MAJOR, REQUIRED_MINOR, REQUIRED_MICRO)) {
      var msg = _("Backups requires at least version %d.%d.%d of restic, " +
                  "but only found version %d.%d.%d");
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
    return new ResticJob();
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
      case DejaDup.Backend.Kind.GVFS: // via fuse
      case DejaDup.Backend.Kind.GOOGLE: // via rclone
      case DejaDup.Backend.Kind.MICROSOFT: // via rclone
        return true;

      default:
        explanation = _("This storage location is not yet supported.");
        return false;
    }
  }

  public static string restic_command()
  {
    var testing_str = Environment.get_variable("DEJA_DUP_TESTING");
    if (testing_str != null && int.parse(testing_str) > 0)
      return "restic";
    else
      return Config.RESTIC_COMMAND;
  }
}
