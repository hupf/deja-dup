/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*- */
/*
    This file is part of Déjà Dup.
    © 2008,2009,2010,2011 Michael Terry <mike@mterry.name>

    Déjà Dup is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Déjà Dup is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Déjà Dup.  If not, see <http://www.gnu.org/licenses/>.
*/

using GLib;

namespace DejaDup {

public const string INCLUDE_LIST_KEY = "include-list";
public const string EXCLUDE_LIST_KEY = "exclude-list";
public const string BACKEND_KEY = "backend";
public const string ROOT_PROMPT_KEY = "root-prompt";
public const string WELCOMED_KEY = "welcomed";
public const string ENCRYPT_KEY = "encrypt";
public const string LAST_RUN_KEY = "last-run";
public const string LAST_BACKUP_KEY = "last-backup";
public const string LAST_RESTORE_KEY = "last-restore";
public const string PERIODIC_KEY = "periodic";
public const string PERIODIC_PERIOD_KEY = "periodic-period";
public const string DELETE_AFTER_KEY = "delete-after";

public errordomain BackupError {
  BAD_CONFIG,
  ALREADY_RUNNING
}

public enum TimestampType {
  NONE,
  BACKUP,
  RESTORE
}

public void update_last_run_timestamp(TimestampType type) throws Error
{
  TimeVal cur_time = TimeVal();
  cur_time.get_current_time();
  var cur_time_str = cur_time.to_iso8601();
  
  var settings = get_settings();
  settings.set_string(LAST_RUN_KEY, cur_time_str);
  if (type == TimestampType.BACKUP)
    settings.set_string(LAST_BACKUP_KEY, cur_time_str);
  else if (type == TimestampType.RESTORE)
    settings.set_string(LAST_RESTORE_KEY, cur_time_str);
}

public void run_deja_dup(string args, AppLaunchContext? ctx = null,
                         List<File>? files = null)
{
  var cmd = "'%s' %s".printf(Path.build_filename(Config.PKG_LIBEXEC_DIR, "deja-dup"), args);
  var flags = AppInfoCreateFlags.SUPPORTS_STARTUP_NOTIFICATION |
              AppInfoCreateFlags.SUPPORTS_URIS;
  try {
    var app = AppInfo.create_from_commandline(cmd, _("Déjà Dup"), flags);
    app.launch(files, ctx);
  }
  catch (Error e) {
    warning("%s\n", e.message);
  }
}

Date most_recent_scheduled_date(int period)
{
  // Compare days between epoch and current days.  Mod by period to find
  // scheduled dates.

  Date epoch = Date();
  epoch.set_dmy(1, 1, 1970);

  Date cur_date = today();

  int between = epoch.days_between(cur_date);
  int mod = between % period;

  cur_date.subtract_days(mod);
  return cur_date;
}

public Date today()
{
  TimeVal cur_time = TimeVal();
  cur_time.get_current_time();
  Date cur_date = Date();
  cur_date.set_time_val(cur_time);
  return cur_date;
}

public string last_run_date(TimestampType type)
{
  var settings = DejaDup.get_settings();
  string last_run_string = null;
  if (type == TimestampType.BACKUP)
    last_run_string = settings.get_string(DejaDup.LAST_BACKUP_KEY);
  else if (type == TimestampType.RESTORE)
    last_run_string = settings.get_string(DejaDup.LAST_RESTORE_KEY);
  if (last_run_string == null || last_run_string == "")
    last_run_string = settings.get_string(DejaDup.LAST_RUN_KEY);
  return last_run_string;
}

public Date next_run_date()
{
  var settings = DejaDup.get_settings();
  var periodic = settings.get_boolean(DejaDup.PERIODIC_KEY);
  var period_days = settings.get_int(DejaDup.PERIODIC_PERIOD_KEY);

  var last_run_string = last_run_date(TimestampType.BACKUP);

  if (!periodic)
    return Date();
  if (last_run_string == "")
    return today();
  if (period_days <= 0)
    period_days = 1;

  Date last_run = Date();
  TimeVal last_run_tval = TimeVal();
  if (!last_run_tval.from_iso8601(last_run_string))
    return today();

  last_run.set_time_val(last_run_tval);
  if (!last_run.valid())
    return today();

  Date last_scheduled = most_recent_scheduled_date(period_days);

  if (last_scheduled.compare(last_run) <= 0)
    last_scheduled.add_days(period_days);

  return last_scheduled;
}

public string get_trash_path()
{
  return Path.build_filename(Environment.get_user_data_dir(), "Trash");
}

public string get_folder_key(SimpleSettings settings, string key)
{
  string folder = settings.get_string(key);
  if (folder.contains("$HOSTNAME")) {
    folder = folder.replace("$HOSTNAME", Environment.get_host_name());
    settings.set_string(key, folder);
  }
  if (folder.has_prefix("/"))
    folder = folder.substring(1);
  return folder;
}

public File? parse_dir(string dir)
{
  string s = dir;
  if (s == "$HOME")
    s = Environment.get_home_dir();
  else if (s == "$DESKTOP")
    s = Environment.get_user_special_dir(UserDirectory.DESKTOP);
  else if (s == "$DOCUMENTS")
    s = Environment.get_user_special_dir(UserDirectory.DOCUMENTS);
  else if (s == "$DOWNLOAD")
    s = Environment.get_user_special_dir(UserDirectory.DOWNLOAD);
  else if (s == "$MUSIC")
    s = Environment.get_user_special_dir(UserDirectory.MUSIC);
  else if (s == "$PICTURES")
    s = Environment.get_user_special_dir(UserDirectory.PICTURES);
  else if (s == "$PUBLIC_SHARE")
    s = Environment.get_user_special_dir(UserDirectory.PUBLIC_SHARE);
  else if (s == "$TEMPLATES")
    s = Environment.get_user_special_dir(UserDirectory.TEMPLATES);
  else if (s == "$TRASH")
    s = get_trash_path();
  else if (s == "$VIDEOS")
    s = Environment.get_user_special_dir(UserDirectory.VIDEOS);
  else if (Uri.parse_scheme(s) == null && !Path.is_absolute(s))
    s = Path.build_filename(Environment.get_home_dir(), s);
  else
    return File.parse_name(s);

  if (s != null)
    return File.new_for_path(s);
  else
    return null;
}

public File[] parse_dir_list(string*[] dirs)
{
  File[] rv = new File[0];
  
  foreach (string s in dirs) {
    var f = parse_dir(s);
    if (f != null)
      rv += f;
  }
  
  return rv;
}

bool settings_read_only = false;
HashTable<string, SimpleSettings> settings_table = null;
public void set_settings_read_only(bool ro)
{
  settings_read_only = ro;
  if (settings_read_only) {
    // When read only, we also need to make sure everyone shares the same
    // settings object.  Otherwise, they will not notice the changes other
    // parts of the code make.
    settings_table = new HashTable<string, SimpleSettings>.full(str_hash,
                                                                str_equal,
                                                                g_free,
                                                                g_object_unref);
  }
  else {
    settings_table = null;
  }
}

public SimpleSettings get_settings(string? subdir = null)
{
  string schema = "org.gnome.DejaDup";
  if (subdir != null && subdir != "")
    schema += "." + subdir;
  SimpleSettings rv;
  if (settings_read_only) {
    rv = settings_table.lookup(schema);
    if (rv == null) {
      rv = new SimpleSettings(schema, true);
      rv.delay(); // never to be apply()'d again
      settings_table.insert(schema, rv);
    }
  }
  else {
    rv = new SimpleSettings(schema, false);
  }
  return rv;
}

const string SSH_USERNAME_KEY = "username";
const string SSH_SERVER_KEY = "server";
const string SSH_PORT_KEY = "port";
const string SSH_DIRECTORY_KEY = "directory";

// Once, we didn't use GIO, but had a special SSH backend for duplicity that
// would tell duplicity to use its own SSH handling.  We convert those gsettings
// values to the new ones here.
void convert_ssh_to_file()
{
  var settings = get_settings();
  var backend = settings.get_string(BACKEND_KEY);
  if (backend == "ssh") {
    settings.set_string(BACKEND_KEY, "file");
    var ssh_settings = get_settings("SSH");
    var server = ssh_settings.get_string(SSH_SERVER_KEY);
    if (server != null && server != "") {
      var username = ssh_settings.get_string(SSH_USERNAME_KEY);
      var port = ssh_settings.get_int(SSH_PORT_KEY);
      var directory = ssh_settings.get_string(SSH_DIRECTORY_KEY);
      
      var gio_uri = "ssh://";
      if (username != null && username != "")
        gio_uri += username + "@";
      gio_uri += server;
      if (port > 0 && port != 22)
        gio_uri += ":" + port.to_string();
      if (directory == null || directory == "")
        gio_uri += "/";
      else if (directory[0] != '/')
        gio_uri += "/" + directory;
      else
        gio_uri += directory;
      
      var file_settings = get_settings(FILE_ROOT);
      file_settings.set_string(FILE_PATH_KEY, gio_uri);
    }
  }
}

void convert_s3_folder_to_hostname()
{
  // So historically, the default S3 folder was '/'.  But in keeping with other
  // cloud backends, the desire to use a hostname in the default folder would
  // make one want to change that default.  But since the user might not have
  // actually changed the default, we don't want to upgrade the folder default
  // in such a case.  So we check here if the user has ever backed up before
  // and if not (or not using S3), then we update the field.
  var settings = get_settings();
  var s3_settings = get_settings(S3_ROOT);
  if ((s3_settings.get_string(S3_FOLDER_KEY) == "" ||
       s3_settings.get_string(S3_FOLDER_KEY) == "/") &&
      (Backend.get_default_type() != "s3" ||
       settings.get_string(LAST_RUN_KEY) == "")) {
    s3_settings.set_string(S3_FOLDER_KEY, "$HOSTNAME");
  }
}

public void initialize()
{
  convert_ssh_to_file();
  convert_s3_folder_to_hostname();
}

public void i18n_setup()
{
  var localedir = Environment.get_variable("DEJA_DUP_LOCALEDIR");
  if (localedir == null || localedir == "")
    localedir = Config.LOCALE_DIR;
  var language = Environment.get_variable("DEJA_DUP_LANGUAGE");
  if (language != null && language != "")
    Environment.set_variable("LANGUAGE", language, true);
  Intl.textdomain(Config.GETTEXT_PACKAGE);
  Intl.bindtextdomain(Config.GETTEXT_PACKAGE, localedir);
  Intl.bind_textdomain_codeset(Config.GETTEXT_PACKAGE, "UTF-8");
}

public string get_file_desc(File file)
{
  // First try to get the DESCRIPTION.  Else get the DISPLAY_NAME
  try {
    var info = file.query_info(FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME + "," +
                               FILE_ATTRIBUTE_STANDARD_DESCRIPTION,
                               FileQueryInfoFlags.NONE, null);
    if (info.has_attribute(FILE_ATTRIBUTE_STANDARD_DESCRIPTION))
      return info.get_attribute_string(FILE_ATTRIBUTE_STANDARD_DESCRIPTION);
    else if (info.has_attribute(FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME))
      return info.get_attribute_string(FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME);
  }
  catch (Error e) {}

  var desc = Path.get_basename(file.get_parse_name());
  if (!file.is_native()) {
    var uri = DejaDupDecodedUri.decode_uri(file.get_uri());
    if (uri.host != null && uri.host != "")
      desc = _("%1$s on %2$s").printf(desc, uri.host);
  }
  return desc;
}

public string get_location_desc()
{
  try {
    var desc = Backend.get_default().get_location_pretty();
    if (desc != null && desc != "")
      return desc;
  }
  catch (Error e) {}

  return _("Unknown");
}

public int get_full_backup_threshold()
{
  int threshold = 7 * 6; // default to 6 weeks
  // So, there are a few factors affecting how often to make a fresh full
  // backup:
  // 1) The longer we wait, the more we're filling up the backend with 
  //    iterations on the same crap.
  // 2) The longer we wait, there's a higher risk that some bit will flip
  //    and the whole backup is toast.
  // 3) The longer we wait, the less annoying we are, since full backups 
  //    take a long time.
  // So we try to do them at reasonable times.  But almost nobody should be
  // going longer than 6 months without a full backup.  Further, we want
  // to try to keep at least 2 full backups around, so also don't allow a
  // longer full threshold than half the delete age.
  // 
  // 'daily' gets 2 weeks: 1 * 12 => 2 * 7
  // 'weekly' gets 3 months: 7 * 12
  // 'biweekly' gets 6 months: 14 * 12
  // 'monthly' gets 6 months: 28 * 12 => 24 * 7
  var max = 24 * 7; // 6 months
  var min = 4 * 7; // 4 weeks
  var scale = 12;
  var min_fulls = 2;
  
  var settings = get_settings();
  var delete_age = settings.get_int(DELETE_AFTER_KEY);
  if (delete_age > 0)
    max = int.min(delete_age/min_fulls, max);
  
  var periodic = settings.get_boolean(PERIODIC_KEY);
  if (periodic) {
    var period = settings.get_int(PERIODIC_PERIOD_KEY);
    threshold = period * scale;
    threshold.clamp(min, max);
  }
  else
    threshold = max;
  
  return threshold;
}

public Date get_full_backup_threshold_date()
{
  TimeVal now = TimeVal();
  now.get_current_time();
  
  Date date = Date();
  date.set_time_val(now);
  
  var days = get_full_backup_threshold();
  date.subtract_days(days);
  
  return date;
}

} // end namespace

