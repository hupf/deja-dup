/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Canonical Ltd
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public const string REMOTE_ROOT = "Remote";
public const string REMOTE_URI_KEY = "uri";
public const string REMOTE_FOLDER_KEY = "folder";

public class BackendRemote : BackendFile
{
  public BackendRemote(Settings? settings) {
    Object(kind: Kind.GVFS,
           settings: (settings != null ? settings : get_settings(REMOTE_ROOT)));
  }

  public virtual string get_folder()
  {
    return get_folder_key(settings, REMOTE_FOLDER_KEY, true);
  }

  // Get mountable root
  protected override File? get_root_from_settings()
  {
    var uri = settings.get_string(REMOTE_URI_KEY);
    return File.parse_name(uri);
  }

  // Get full URI to backup folder
  internal override File? get_file_from_settings()
  {
    var root = get_root_from_settings();
    var folder = get_folder();

    // So ideally the user just put the server address ("sftp://example.org" or
    // "dav://example.org/remote.php/webdav/").  And then we add the folder on
    // top of whatever that location gives as the default location -- which
    // might be the user's home directory or whatever.
    //
    // However... the user might put more in the server address field (and we
    // ourselves might have migrated an old gsettings key into the address
    // field that had the full path as part of it). So if it looks like the
    // URI has more than the mount root in it, we add that together with the
    // folder value to make a new path from the mount root (not the default
    // location root).

    try {
      var mount = root.find_enclosing_mount(null);
      var mount_root = mount.get_root();

      // I've had inconsistent results from gvfs.  On davs://, sometimes
      // equal() isn't correct, but has_prefix() is.  On sftp://, sometimes
      // equal() is correct, but has_prefix() isn't.  We test both, hopefully
      // they both won't be wrong.  The point of this check is that we *should*
      // use default_location(), but won't if the user has added extra bits to
      // the URI for us.  Once GNOME bug 786217 is fixed for a while, we can
      // simply check if there is a relative path between the two.
      if (root.equal(mount_root) || !root.has_prefix(mount_root))
        root = mount.get_default_location();
    }
    catch (IOError.NOT_MOUNTED e) {
      // ignore
    }
    catch (Error e) {
      warning("%s", e.message);
    }

    return root.resolve_relative_path(folder);
  }

  public override bool is_native() {
    return false;
  }

  // Check if we should give nicer message
  string get_unready_message(File root, Error e)
  {
    // SMB likes to give back a very generic error when the host is not
    // available ("Invalid argument").  Try to work around that here.
    // TODO: file upstream bug.
    if (root.get_uri_scheme() == "smb")
    {
      // Presumably when this issue first appeared, the following old_check
      // approach caught it. These days, we get a more appropriate INVALID_ARGUMENT
      // error back (appropriate, because that's the message string we get:
      // "invalid argument"). I'll leave this old check in place, because it
      // seems harmless. But at some point, I suppose we ought to remove it.
      // New check works on at least gvfs 1.47.91 and presumably somewhat earlier.
      var old_check = Posix.errno == Posix.EAGAIN &&
                      e.matches(IOError.quark(), 0);
      if (e.matches(IOError.quark(), IOError.INVALID_ARGUMENT) || old_check) {
        return _("The network server is not available");
      }
    }

    return e.message;
  }

  public override async bool is_ready(out string reason, out string message)
  {
    var root = get_root_from_settings();
    reason = "remote-mounted";
    message = null;
    try {
      // Test if we can mount successfully (this is better than simply
      // testing if network is reachable, since ssh configs and all sorts of
      // things might be taken into account by GIO but not by a simple
      // network test). If we do end up mounting it, that's fine.  This is
      // only called right before attempting an operation.
      return yield root.mount_enclosing_volume(MountMountFlags.NONE, mount_op, null);
    }
    catch (IOError.ALREADY_MOUNTED e) {
      // We're mounted! Great. However, the remote server might have become
      // unavailable since being mounted before. Maybe we've walked to a cafe.
      // So let's just do simple query to confirm it's reachable.
      try {
        yield root.query_info_async(FileAttribute.STANDARD_NAME,
                                    FileQueryInfoFlags.NONE,
                                    Priority.DEFAULT, null);
        return true;
      }
      catch (Error e) {
        message = get_unready_message(root, e);
        return false;
      }
    }
    catch (IOError.FAILED_HANDLED e) {
      // Needed user input, so we know we can reach server
      return true;
    }
    catch (Error e) {
      message = get_unready_message(root, e);
      return false;
    }
  }

  public override Icon? get_icon()
  {
    try {
      return Icon.new_for_string("network-server");
    }
    catch (Error e) {
      warning("%s", e.message);
      return null;
    }
  }

  public override async bool mount() throws Error
  {
    if (!Network.get().connected) {
      pause_op(_("Storage location not available"),
               _("Waiting for a network connection…"));
      var loop = new MainLoop(null, false);
      var sigid = Network.get().notify["connected"].connect(() => {
        if (Network.get().connected)
          loop.quit();
      });
      loop.run();
      Network.get().disconnect(sigid);
      pause_op(null, null);
    }

    var root = get_root_from_settings();
    if (root == null)
      throw new IOError.FAILED("%s", _("Could not mount storage location."));

    if (root.get_uri() == "") {
      throw new IOError.FAILED("%s", _(
        "The server’s network location needs to be specified in the storage location preferences."
      ));
    }
    if (root.get_uri_scheme() == null) {
      throw new IOError.FAILED("%s", _(
        "The server’s network location ‘%s’ does not look like a network location."
      ).printf(root.get_uri()));
    }

    if (root.get_uri_scheme() == "smb" && root.get_uri().split("/").length < 5) {
      // Special sanity check for some edge cases like smb:// where if the user
      // just puts in smb://server/ as the root, GIO thinks it's a valid root,
      // but the share never ends up mounted.
      throw new IOError.FAILED("%s", _("Samba network locations must include both a hostname and a share name."));
    }

    try {
      yield root.mount_enclosing_volume(MountMountFlags.NONE, mount_op, null);
    } catch (IOError.ALREADY_MOUNTED e) {
      return false;
    } catch (IOError.FAILED_HANDLED e) {
      // needed mount_op but none provided
      needed_mount_op();
      return false;
    } catch (Error e) {
      // try once more with same response in case we timed out while waiting for user
      mount_op.@set("retry_mode", true);
      yield root.mount_enclosing_volume(MountMountFlags.NONE, mount_op, null);
    } finally {
      if (mount_op != null)
        mount_op.@set("retry_mode", false);
    }

    return true;
  }
}

} // end namespace
