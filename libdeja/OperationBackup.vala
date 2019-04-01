/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class DejaDup.OperationBackup : Operation
{
  File metadir;

  public OperationBackup(Backend backend) {
    Object(mode: ToolJob.Mode.BACKUP, backend: backend);
  }

  public async override void start()
  {
    DejaDup.update_last_run_timestamp(DejaDup.LAST_RUN_KEY);
    yield base.start();
  }

  internal async override void operation_finished(bool success, bool cancelled, string? detail)
  {
    /* If successfully completed, update time of last backup and run base operation_finished */
    if (success && !cancelled)
      DejaDup.update_last_run_timestamp(DejaDup.LAST_BACKUP_KEY);

    if (metadir != null)
      new RecursiveDelete(metadir).start();

    if (success && !cancelled) {
      var verify = new OperationVerify(backend, job.tag);
      yield chain_op(verify, _("Verifying backup…"), detail);
    } else {
      yield base.operation_finished(success, cancelled, detail);
    }
  }

  protected override void send_action_file_changed(File file, bool actual)
  {
    // Intercept action_file_changed signals and ignore them if they are
    // metadata file, the user doesn't need to see them.
    if (!file.has_prefix(metadir))
      base.send_action_file_changed(file, actual);
  }

  protected override List<string>? make_argv()
  {
    var settings = get_settings();
    var include_list = settings.get_file_list(INCLUDE_LIST_KEY);
    var exclude_list = settings.get_file_list(EXCLUDE_LIST_KEY);

    // Exclude directories no one wants to backup
    add_always_excluded_dirs(ref job.excludes, ref job.exclude_regexps);

    foreach (File s in exclude_list)
      job.excludes.prepend(s);
    foreach (File s in include_list)
      job.includes.prepend(s);

    // Insert deja-dup meta info directory
    try {
      metadir = get_metadir();
      fill_metadir();
      job.includes_priority.prepend(metadir);
    }
    catch (Error e) {
      warning("%s\n", e.message);
    }

    job.local = File.new_for_path(InstallEnv.instance().get_read_root());

    return null;
  }

  void add_always_excluded_dirs(ref List<File> files, ref List<string> regexps)
  {
    var cache_dir = Environment.get_user_cache_dir();
    var home_dir = Environment.get_home_dir();

    // User doesn't care about cache
    if (cache_dir != null) {
      var cache = File.new_for_path(cache_dir);
      files.prepend(cache);

      // Always also exclude ~/.cache because we may be running confined with
      // a custom cache path, but we still want to exclude the user's normal
      // cache folder. No way to know if they have an unusual path for that,
      // though. So we just guess at the default path.
      if (home_dir != null) {
        var home = File.new_for_path(home_dir);
        var home_cache = home.get_child(".cache");
        if (!cache.equal(home_cache)) {
          files.prepend(home_cache);
        }
      }

      // We also add our special cache dir because if the user still especially
      // includes the cache dir, we still won't backup our own metadata.
      files.prepend(cache.get_child(Config.PACKAGE));
    }

    // Likewise, user doesn't care about cache-like directories in $HOME.
    // In an ideal world, all of these would be under ~/.cache.  But for
    // historical reasons or for those apps that are both popular enough to
    // warrant special attention, we add some useful exclusions here.
    // When changing this list, remember to update the help documentation too.
    if (home_dir != null) {
      var home = File.new_for_path(home_dir);
      files.prepend(home.resolve_relative_path(".adobe/Flash_Player/AssetCache"));
      files.prepend(home.resolve_relative_path(".ccache"));
      files.prepend(home.resolve_relative_path(".gvfs"));
      files.prepend(home.resolve_relative_path(".Private")); // encrypted copies of stuff in $HOME
      files.prepend(home.resolve_relative_path(".recent-applications.xbel"));
      files.prepend(home.resolve_relative_path(".recently-used.xbel"));
      files.prepend(home.resolve_relative_path(".steam/root"));
      files.prepend(home.resolve_relative_path(".thumbnails"));
      files.prepend(home.resolve_relative_path(".xsession-errors"));
      regexps.prepend(Path.build_filename(home_dir, ".var/app/*/cache")); // flatpak
      regexps.prepend(Path.build_filename(home_dir, "snap/*/*/.cache"));
    }

    // Skip all of our temporary directories
    foreach (var tempdir in DejaDup.get_tempdirs())
      files.prepend(File.new_for_path(tempdir));

    // Skip transient directories
    files.prepend(File.new_for_path("/dev"));
    files.prepend(File.new_for_path("/proc"));
    files.prepend(File.new_for_path("/run"));
    files.prepend(File.new_for_path("/sys"));
  }

  void fill_metadir() throws Error
  {
    if (metadir == null)
      return;

    // Delete old dir, if any, and replace it
    new RecursiveDelete(metadir).start();
    metadir.make_directory_with_parents(null);

    // Put a file in there that is one part always constant, and one part
    // always different, for basic sanity checking.  This way, it will be
    // included in every backup, but we can still check its contents for
    // corruption.  We'll stuff seconds-since-epoch in it.
    var now = new DateTime.now_utc();
    var msg = "This folder can be safely deleted.\n%s".printf(now.format("%s"));
    FileUtils.set_contents(Path.build_filename(metadir.get_path(), "README"), msg);
  }
}
