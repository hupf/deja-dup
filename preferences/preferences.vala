/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*- */
/*
    This file is part of Déjà Dup.
    © 2008,2009 Michael Terry <mike@mterry.name>

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

class DejaDupPreferences : Object
{
  static bool show_version = false;
  static const OptionEntry[] options = {
    {"version", 0, 0, OptionArg.NONE, ref show_version, N_("Show version"), null},
    {null}
  };
  
  static bool handle_console_options(out int status)
  {
    status = 0;
    
    if (show_version) {
      print("%s %s\n", _("Déjà Dup Preferences"), Config.VERSION);
      return false;
    }
    
    return true;
  }
  
  static PreferencesDialog pref_window;
  
  public static int main(string [] args)
  {
    Intl.textdomain(Config.GETTEXT_PACKAGE);
    Intl.bindtextdomain(Config.GETTEXT_PACKAGE, Config.LOCALE_DIR);
    Intl.bind_textdomain_codeset(Config.GETTEXT_PACKAGE, "UTF-8");
    
    Environment.set_application_name(_("Déjà Dup Preferences"));
    
    OptionContext context = new OptionContext("");
    context.add_main_entries(options, Config.GETTEXT_PACKAGE);
    context.add_group(Gtk.get_option_group(false)); // allow console use
    try {
      context.parse(ref args);
    } catch (Error e) {
      printerr("%s\n\n%s", e.message, context.get_help(true, null));
      return 1;
    }
    
    int status;
    if (!handle_console_options(out status))
      return status;
    
    DejaDup.initialize();
    
    // We don't have a solid domain for Déjà Dup...  But we're GNOME-ish
    var app = new Gtk.Application("org.gnome.DejaDup.Preferences", ref args);
    
    if (!app.is_remote) {
      // We're first instance.  Yay!
      Gtk.IconTheme.get_default().append_search_path(Config.THEME_DIR);
      Gtk.Window.set_default_icon_name(Config.PACKAGE);
      
      pref_window = new PreferencesDialog();
      pref_window.show_all();
      
      app.add_window(pref_window);
      app.run();
    }
    
    return 0;
  }
}

