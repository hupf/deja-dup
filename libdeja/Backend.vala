/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public abstract class DejaDup.Backend : Object
{
  public enum Kind {
    UNKNOWN,
    LOCAL,
    GVFS,
    GOOGLE,
  }
  public Kind kind {get; construct; default=Kind.UNKNOWN;}

  public Settings settings {get; construct;}

  public signal void envp_ready(bool success, List<string>? envp, string? error = null);
  public signal void pause_op(string? header, string? msg);

  // This signal might be too specific to the one backend that uses it (Google).
  // Subject to change as we experiment with more oauth backends.
  public signal void show_oauth_consent_page(string? message, string? url);

  public MountOperation mount_op {get; set;}
  public signal void needed_mount_op(); // if user interaction was required, but not provided

  public abstract bool is_native(); // must be callable when nothing is mounted, nothing is prepared
  public virtual Icon? get_icon() {return null;}

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

  public virtual void add_excludes(ref List<File> exludes) {}

  public static Backend get_for_key(string key, Settings? settings = null)
  {
    if (key == "auto")
      return new BackendAuto();
    else if (key == "google")
      return new BackendGoogle(settings);
    else if (key == "drive")
      return new BackendDrive(settings);
    else if (key == "remote")
      return new BackendRemote(settings);
    else if (key == "local")
      return new BackendLocal(settings);
    else
      return new BackendUnsupported(key);
  }

  public static string get_key_name(Settings settings)
  {
    return settings.get_string(BACKEND_KEY);
  }

  public static Backend get_default()
  {
    return get_for_key(get_default_key());
  }

  public static string get_default_key()
  {
    return get_key_name(get_settings());
  }
}
