/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

// Most strings in this window are *not* translated, since they are for
// developers, not the user.

public class DebugInfo : BuilderWidget
{
  public Gtk.Window parent {get; construct;}
  DejaDup.LogObscurer obscurer;

  public DebugInfo(Gtk.Window? parent)
  {
    Object(parent: parent, builder: new Builder("debug"));
  }

  construct {
    adopt_name("debug-window");

    obscurer = new DejaDup.LogObscurer();

    var window = builder.get_object("debug-window") as Gtk.Window;
    window.transient_for = parent;

    var debug_info = builder.get_object("debug-info") as Gtk.Label;
    debug_info.label = get_debug_info();

    var copy_button = builder.get_object("copy-button") as Gtk.Button;
    copy_button.clicked.connect(copy_to_clipboard);
  }

  public void run()
  {
    var window = builder.get_object("debug-window") as Gtk.Dialog;
    window.run();
  }

  void copy_to_clipboard(Gtk.Button button)
  {
    var debug_info = builder.get_object("debug-info") as Gtk.Label;
    var text = "```\n%s\n```".printf(debug_info.label);

    var clipboard = Gtk.Clipboard.get_default(button.get_display());
    clipboard.set_text(text, -1);
  }

  string get_debug_info()
  {
    var text = "System Details:\n%s".printf(get_system_info());

    var gsettings = get_gsettings(Config.APPLICATION_ID);
    if (gsettings != null)
      text += "\nGSettings:\n%s".printf(gsettings);

    var dup_logger = DejaDup.DuplicityLogger.from_cache_log();
    if (dup_logger != null) {
      dup_logger.read_sync();
      var log = dup_logger.get_obscured_tail(obscurer);
      text += "\nLatest Duplicity Log:\n%s".printf(log);
    }

    return text.chomp();
  }

  string get_system_info()
  {
    var version = Config.VERSION;
    var install_env_name = DejaDup.InstallEnv.instance().get_name();
    if (install_env_name != null)
      version += " (%s)".printf(install_env_name);

    var text = "";
    text += "OS=%s\n".printf(Environment.get_os_info(OsInfoKey.PRETTY_NAME));
    text += "Desktop=%s\n".printf(Environment.get_variable("XDG_SESSION_DESKTOP"));
    text += "Locale=%s\n".printf(Intl.setlocale(LocaleCategory.MESSAGES, null));
    text += "Home=%s\n".printf(obscurer.replace_path(Environment.get_home_dir()));
    text += "Version=%s\n".printf(version);
    text += DejaDup.InstallEnv.instance().get_debug_info();

    return text;
  }

  string? get_gsettings(string? schema = null)
  {
    var settings = new Settings(schema);
    var has_content = false;

    // Start with schema header
    string text = "[%s]\n".printf(settings.schema_id);

    // Fill in user-set keys
    foreach (var key in settings.settings_schema.list_keys()) {
      var val = settings.get_user_value(key);
      if (val != null) {
        var val_str = val.print(false);

        if (key == "folder" || key == "name") {
          val_str = "'%s'".printf(obscurer.replace_path(val.get_string()));
        }
        else if (key == "include-list" || key == "exclude-list") {
          var inner = string.joinv("', '", obscurer.replace_paths(val.dup_strv()));
          val_str = "['%s']".printf(inner);
        }
        else if (key == "uri") {
          val_str = "'%s'".printf(obscurer.replace_uri(val.get_string()));
        }

        text += "%s=%s\n".printf(key, val_str);
        has_content = true;
      }
    }

    // And iterate children
    foreach (var child in settings.list_children()) {
      var child_text = get_gsettings(settings.get_child(child).schema_id);
      if (child_text != null) {
        text += "\n%s".printf(child_text);
        has_content = true;
      }
    }

    if (has_content)
      return text;
    else
      return null;
  }
}
