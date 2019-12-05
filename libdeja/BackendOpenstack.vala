/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public const string OPENSTACK_ROOT = "OpenStack";
public const string OPENSTACK_USERNAME_KEY = "username";
public const string OPENSTACK_CONTAINER_KEY = "container";
public const string OPENSTACK_TENANT_KEY = "tenant";
public const string OPENSTACK_AUTHURL_KEY = "authurl";

public class BackendOpenstack : Backend
{
  public BackendOpenstack(Settings? settings) {
    Object(settings: (settings != null ? settings : get_settings(OPENSTACK_ROOT)));
  }

  public override string[] get_dependencies()
  {
    return Config.SWIFTCLIENT_PACKAGES.split(",");
  }

  public override bool is_native() {
    return false;
  }

  public override Icon? get_icon() {
    return new ThemedIcon("deja-dup-cloud");
  }

  public override async bool is_ready(out string when) {
    var authurl = get_folder_key(settings, OPENSTACK_AUTHURL_KEY);
    when = _("Backup will begin when a network connection becomes available.");
    return yield Network.get().can_reach (authurl);
  }

  public override string get_location(ref bool as_root)
  {
    var container = get_folder_key(settings, OPENSTACK_CONTAINER_KEY);
    if (container == "") {
      container = Environment.get_host_name();
      settings.set_string(OPENSTACK_CONTAINER_KEY, container);
    }
    return "swift://%s".printf(container);
  }

  public override string get_location_pretty()
  {
    var container = settings.get_string(OPENSTACK_CONTAINER_KEY);
    if (container == "")
      return _("OpenStack Swift");
    else
      // Translators: %s is a folder.
      return _("%s on OpenStack Swift").printf(container);
  }

  string settings_id;
  string id;
  string secret_key;
  public override async void get_envp() throws Error
  {
    settings_id = settings.get_string(OPENSTACK_USERNAME_KEY);
    id = settings_id == null ? "" : settings_id;

    var authurl = settings.get_string(OPENSTACK_AUTHURL_KEY);

    if (id != "" && secret_key != null) {
      // We've already been run before and got the key
      got_secret_key();
      return;
    }

    if (id != "") {
      // First, try user's keyring
      try {
        var schema = Secret.get_schema(Secret.SchemaType.COMPAT_NETWORK);
        secret_key = yield Secret.password_lookup(schema,
                                                  null,
                                                  "user", id,
                                                  "server", authurl,
                                                  "protocol", "https");
        if (secret_key != null) {
          got_secret_key();
          return;
        }
      }
      catch (Error e) {
        // fall through to ask_password below
      }
    }

    // Didn't find it, so ask user
    ask_password();
  }

  async void got_password_reply(MountOperation mount_op, MountOperationResult result)
  {
    if (result != MountOperationResult.HANDLED) {
      envp_ready(false, new List<string>(), _("Permission denied"));
      return;
    }

    id = mount_op.username;
    secret_key = mount_op.password;

    // Save it
    var remember = mount_op.password_save;
    if (remember != PasswordSave.NEVER) {
      string where = (remember == PasswordSave.FOR_SESSION) ?
                     Secret.COLLECTION_SESSION : Secret.COLLECTION_DEFAULT;

      var authurl = get_folder_key(settings, OPENSTACK_AUTHURL_KEY);
      var tenant = get_folder_key(settings, OPENSTACK_TENANT_KEY);

      try {
        var schema = Secret.get_schema(Secret.SchemaType.COMPAT_NETWORK);
        yield Secret.password_store(schema,
                                    where,
                                    "%s:%s@%s".printf(tenant, id, authurl),
                                    secret_key,
                                    null,
                                    "user", id,
                                    "server", authurl,
                                    "protocol", "https");
      }
      catch (Error e) {
        warning("%s\n", e.message);
      }
    }

    got_secret_key();
  }

  void ask_password() {
    mount_op.reply.connect(got_password_reply);
    mount_op.ask_password("", id, "",
                          AskPasswordFlags.NEED_PASSWORD |
                          AskPasswordFlags.NEED_USERNAME |
                          AskPasswordFlags.SAVING_SUPPORTED);
  }

  void got_secret_key() {
    if (id != settings_id)
      settings.set_string(OPENSTACK_USERNAME_KEY, id);

    var tenant_name = settings.get_string(OPENSTACK_TENANT_KEY);
    var authurl = settings.get_string(OPENSTACK_AUTHURL_KEY);

    List<string> envp = new List<string>();
    envp.append("SWIFT_TENANTNAME=%s".printf(tenant_name));
    envp.append("SWIFT_AUTHURL=%s".printf(authurl));
    envp.append("SWIFT_USERNAME=%s".printf(id));
    envp.append("SWIFT_PASSWORD=%s".printf(secret_key));
    envp_ready(true, envp);
  }
}

} // end namespace

