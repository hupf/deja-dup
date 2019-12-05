/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

public const string S3_ROOT = "S3";
public const string S3_ID_KEY = "id";
public const string S3_BUCKET_KEY = "bucket";
public const string S3_FOLDER_KEY = "folder";

const string S3_SERVER = "s3.amazonaws.com";

public class BackendS3 : Backend
{
  public BackendS3(Settings? settings) {
    Object(settings: (settings != null ? settings : get_settings(S3_ROOT)));
  }

  public override string[] get_dependencies()
  {
    return Config.BOTO_PACKAGES.split(",");
  }

  public override void add_argv(ToolJob.Mode mode, ref List<string> argv) {
    if (mode == ToolJob.Mode.INVALID)
      argv.append("--s3-use-new-style");
  }

  string get_default_bucket() {
    return "deja-dup-auto-%s".printf(id.down());
  }

  public override bool is_native() {
    return false;
  }

  public override Icon? get_icon() {
    return new ThemedIcon("deja-dup-cloud");
  }

  public override async bool is_ready(out string when) {
    when = _("Backup will begin when a network connection becomes available.");
    return yield Network.get().can_reach ("http://%s/".printf(S3_SERVER));
  }

  public override string get_location(ref bool as_root)
  {
    var bucket = settings.get_string(S3_BUCKET_KEY);
    var default_bucket = get_default_bucket();
    if (bucket == null || bucket == "" ||
        (bucket.has_prefix("deja-dup-auto-") &&
         !bucket.has_prefix(default_bucket))) {
      bucket = default_bucket;
      settings.set_string(S3_BUCKET_KEY, bucket);
    }

    var folder = get_folder_key(settings, S3_FOLDER_KEY);
    return "s3+http://%s/%s".printf(bucket, folder);
  }

  public bool bump_bucket() {
    // OK, the bucket we tried must already exist, so let's use a different
    // one.  We'll take previous bucket name and increment it.
    var bucket = settings.get_string(S3_BUCKET_KEY);
    if (bucket == "deja-dup") {
      // Until 7.4, we exposed the bucket name and defaulted to deja-dup.
      // Since buckets are S3-global, everyone was unable to use that bucket,
      // since I (Mike Terry) owned that bucket.  If we see this setting,
      // we should default to the generic bucket name rather than assume the
      // user chose this bucket and error out.
      bucket = get_default_bucket();
      settings.set_string(S3_BUCKET_KEY, bucket);
      return true;
    }

    if (!bucket.has_prefix("deja-dup-auto-"))
      return false;

    var bits = bucket.split("-");
    if (bits == null || bits[0] == null || bits[1] == null ||
        bits[2] == null || bits[3] == null)
      return false;

    if (bits[4] == null)
      bucket += "-2";
    else {
      var num = long.parse(bits[4]);
      bits[4] = (num + 1).to_string();
      bucket = string.joinv("-", bits);
    }

    settings.set_string(S3_BUCKET_KEY, bucket);
    return true;
  }

  public override string get_location_pretty()
  {
    var folder = get_folder_key(settings, S3_FOLDER_KEY);
    if (folder == "")
      return _("Amazon S3");
    else
      // Translators: %s is a folder.
      return _("%s on Amazon S3").printf(folder);
  }

  string settings_id;
  string id;
  string secret_key;
  public override async void get_envp() throws Error
  {
    settings_id = settings.get_string(S3_ID_KEY);
    id = settings_id == null ? "" : settings_id;

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
                                                  "server", S3_SERVER,
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
      try {
        var schema = Secret.get_schema(Secret.SchemaType.COMPAT_NETWORK);
        yield Secret.password_store(schema,
                                    where,
                                    "%s@%s".printf(id, S3_SERVER),
                                    secret_key,
                                    null,
                                    "user", id,
                                    "server", S3_SERVER,
                                    "protocol", "https");
      }
      catch (Error e) {
        warning("%s\n", e.message);
      }
    }

    got_secret_key();
  }

  void ask_password() {
    var help = _("You can sign up for an Amazon S3 account <a href=\"%s\">online</a>.");
    mount_op.set("label_help", help.printf("http://aws.amazon.com/s3/"));
    mount_op.set("label_title", _("Connect to Amazon S3"));
    mount_op.set("label_username", _("_Access key ID"));
    mount_op.set("label_password", _("_Secret access key"));
    mount_op.set("label_show_password", _("S_how secret access key"));
    mount_op.set("label_remember_password", _("_Remember secret access key"));
    mount_op.reply.connect(got_password_reply);
    mount_op.ask_password("", id, "",
                          AskPasswordFlags.NEED_PASSWORD |
                          AskPasswordFlags.NEED_USERNAME |
                          AskPasswordFlags.SAVING_SUPPORTED);
  }

  void got_secret_key() {
    if (id != settings_id)
      settings.set_string(S3_ID_KEY, id);

    List<string> envp = new List<string>();
    envp.append("AWS_ACCESS_KEY_ID=%s".printf(id));
    envp.append("AWS_SECRET_ACCESS_KEY=%s".printf(secret_key));
    envp_ready(true, envp);
  }
}

} // end namespace

