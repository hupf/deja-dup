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
  HashTable<string, string> replacements;

  public DebugInfo(Gtk.Window? parent)
  {
    Object(parent: parent, builder: new Builder("debug"));
  }

  construct {
    adopt_name("debug-window");

    replacements = new HashTable<string, string>(str_hash, str_equal);

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
    var text = "```\n%s```".printf(debug_info.label);

    var clipboard = Gtk.Clipboard.get_default(button.get_display());
    clipboard.set_text(text, -1);
  }

  string random_str(string input)
  {
    var str = "";
    for (int i = 0; i < input.length; i++) {
      var sub = input[i];
      if (sub.isalnum())
        sub = (char)Random.int_range((int)'a', (int)'z');
      str = "%s%c".printf(str, sub);
    }
    return str;
  }

  string replace_path(string path)
  {
    var pieces = path.split("/");
    for (int i = 0; i < pieces.length; i++) {
      var piece = pieces[i];
      if (piece == "home" || piece == "" || piece[0] == '$')
        continue;

      var replacement = replacements.lookup(piece);
      if (replacement == null) {
        replacement = random_str(piece);
        replacements.insert(piece, replacement);
      }
      pieces[i] = replacement;
    }

    return string.joinv("/", pieces);
  }

  string[] replace_paths(string[] paths)
  {
    for (int i = 0; i < paths.length; i++) {
      paths[i] = replace_path(paths[i]);
    }
    return paths;
  }

  string replace_uri(string uri)
  {
    var scheme = Uri.parse_scheme(uri);
    if (scheme == null)
      return replace_path(uri);

    return scheme + replace_path(uri.substring(scheme.length));
  }

  string get_debug_info()
  {
    var text = "System Details:\n%s".printf(get_system_info());

    var gsettings = get_gsettings(Config.APPLICATION_ID);
    if (gsettings != null)
      text += "\nGSettings:\n%s".printf(gsettings);

    return text;
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
    text += "Home=%s\n".printf(replace_path(Environment.get_home_dir()));
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
          val_str = "'%s'".printf(replace_path(val.get_string()));
        }
        else if (key == "include-list" || key == "exclude-list") {
          var inner = string.joinv("', '", replace_paths(val.dup_strv()));
          val_str = "['%s']".printf(inner);
        }
        else if (key == "uri") {
          val_str = "'%s'".printf(replace_uri(val.get_string()));
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
