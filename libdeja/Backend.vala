/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public abstract class Backend : Object
{
  public Settings settings {get; construct;}

  public signal void envp_ready(bool success, List<string>? envp, string? error = null);
  public signal void pause_op(string? header, string? msg);

  // This signal might be too specific to the one backend that uses it (Google).
  // Subject to change as we experiment with more oauth backends.
  public signal void show_oauth_consent_page(string? message, string? url);

  public MountOperation mount_op {get; set;}

  public abstract bool is_native(); // must be callable when nothing is mounted, nothing is prepared
  public virtual Icon? get_icon() {return null;}

  public abstract string get_location(ref bool as_root); // URI for duplicity
  public abstract string get_location_pretty(); // short description for user

  // list of what-provides hints
  public virtual string[] get_dependencies() {return {};}

  public virtual async bool is_ready(out string when) {when = null; return true;} // must be callable when nothing is mounted, nothing is prepared

  public virtual async void get_envp() throws Error {
    envp_ready(true, new List<string>());
  }

  public virtual async void cleanup() {}

  // Only called during backup
  public const uint64 INFINITE_SPACE = uint64.MAX;
  public virtual async uint64 get_space(bool free = true) {return INFINITE_SPACE;}

  // Arguments needed only when the particular mode is active
  // If mode == INVALID, arguments needed any time the backup is referenced.
  public virtual void add_argv(ToolJob.Mode mode, ref List<string> argv) {}

  public static Backend get_for_type(string backend_name, Settings? settings = null)
  {
    if (backend_name == "auto")
      return new BackendAuto();
    else if (backend_name == "google")
      return new BackendGoogle(settings);
    else if (backend_name == "drive")
      return new BackendDrive(settings);
    else if (backend_name == "remote")
      return new BackendRemote(settings);
    else if (backend_name == "local")
      return new BackendLocal(settings);
    else
      return new BackendUnsupported();
  }

  public static string get_type_name(Settings settings)
  {
    var backend = settings.get_string(BACKEND_KEY);

    if (backend != "auto" &&
        backend != "drive" &&
        backend != "file" &&
        backend != "gcs" &&
        backend != "goa" &&
        backend != "google" &&
        backend != "local" &&
        backend != "openstack" &&
        backend != "rackspace" &&
        backend != "remote" &&
        backend != "s3" &&
        backend != "u1")
      backend = "auto"; // default to auto if string is not known

    return backend;
  }

  public static Backend get_default()
  {
    return get_for_type(get_default_type());
  }

  public static string get_default_type()
  {
    return get_type_name(get_settings());
  }
}

} // end namespace

