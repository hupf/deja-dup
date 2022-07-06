/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Canonical Ltd
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class DejaDupApp : Adw.Application
{
  public DejaDup.Backend custom_backend {get; set; default = null;}
  public signal void operation_started();

  WeakRef main_window;
  WeakRef preferences_window;
  WeakRef operation;
  SimpleAction preferences_action = null;
  SimpleAction quit_action = null;

  const OptionEntry[] OPTIONS = {
    {"version", 0, 0, OptionArg.NONE, null, N_("Show version"), null},
    {"restore", 0, 0, OptionArg.NONE, null, N_("Restore given files"), null},
    {"backup", 0, 0, OptionArg.NONE, null, N_("Immediately start a backup"), null},
    {"auto", 0, OptionFlags.HIDDEN, OptionArg.NONE, null, null, null},
    {"delay", 0, OptionFlags.HIDDEN, OptionArg.STRING, null, null, null},
    {"prompt", 0, OptionFlags.HIDDEN, OptionArg.NONE, null, null, null},
    {"", 0, 0, OptionArg.FILENAME_ARRAY, null, null, null}, // remaining
    {null}
  };

  const ActionEntry[] ACTIONS = {
    {"backup", backup},
    {"backup-auto", backup_auto},
    {"backup-auto-stop", backup_auto_stop},
    {"prompt-ok", prompt_ok},
    {"prompt-cancel", prompt_cancel},
    {"delay", delay, "s"},
    {"preferences", preferences},
    {"help", help},
    {"about", about},
    {"quit", quit},
    // redundant with default activation usually, but is used by notifications
    {"show", show},
  };

  static DejaDupApp instance;

  public static DejaDupApp get_instance() {
    if (instance == null)
      instance = new DejaDupApp();
    return instance;
  }

  private DejaDupApp()
  {
    Object(
      application_id: Config.APPLICATION_ID,
      flags: ApplicationFlags.HANDLES_COMMAND_LINE |
             // HANDLES_OPEN is required to support Open calls over dbus, which
             // we use for our registered custom schemes (which support our
             // oauth2 workflow).
             ApplicationFlags.HANDLES_OPEN
    );
    add_main_option_entries(OPTIONS);
  }

  public override int handle_local_options(VariantDict options)
  {
    if (options.contains("version")) {
      print("%s %s\n", "deja-dup", Config.VERSION);
      return 0;
    }
    return -1;
  }

  public override int command_line(ApplicationCommandLine command_line)
  {
    var options = command_line.get_options_dict();

    File[] files = {};
    if (options.contains("")) {
      var variant = options.lookup_value("", VariantType.BYTESTRING_ARRAY);
      foreach (var filename in variant.get_bytestring_array())
        files += command_line.create_file_for_arg(filename);
    }

    if (options.contains("restore")) {
      if (files.length == 0) {
        command_line.printerr("%s\n", _("Please list files to restore"));
        return 1;
      }

      close_excess_modals();
      if (get_operation() != null) {
        command_line.printerr("%s\n", _("An operation is already in progress"));
        return 1;
      }

      var file_list = new List<File>();
      foreach (var file in files)
        file_list.append(file);

      restore_files(file_list);
    }
    else if (options.contains("backup")) {
      close_excess_modals();
      if (get_operation() != null) {
        command_line.printerr("%s\n", _("An operation is already in progress"));
        return 1;
      }

      backup_full(options.contains("auto"));
    }
    else if (options.contains("delay")) {
      string reason = null;
      options.lookup("delay", "s", ref reason);
      Notifications.automatic_backup_delayed(reason);
    }
    else if (options.contains("prompt")) {
      Notifications.prompt();
    }
    else if (files.length > 0) {
      // If we were called without a mode (like --restore) but with file arguments,
      // let's do our "Open" action (which is mostly used for our oauth flow).
      // That oauth flow can happen via command line in some environments like
      // snaps, whereas the dbus Open call might happen for flatpaks. Regardless
      // of how they come in, treat them the same.
      open(files, "");
    }
    else {
      activate();
    }

    return 0;
  }

  public override void activate()
  {
    base.activate();

    if (get_operation() != null) {
      get_operation().present();
    }
    else if (get_app_window() != null)
      get_app_window().present();
    else {
      // We're the first instance.  Yay!
      main_window.set(new MainWindow());
      get_app_window().application = this;
      get_app_window().present();
    }
  }

  public override void open(GLib.File[] files, string hint)
  {
    var oauth_backend = get_restore_backend() as DejaDup.BackendOAuth;

    // We might be in middle of oauth flow, and are given an expected redirect uri
    // like 'com.googleusercontent.apps.123:/oauth2redirect?code=xxx'
    if (files.length == 1 && oauth_backend != null)
    {
      var provided_uri = files[0].get_uri();
      // Normalize backend URI through gio, so it matches incoming URI format (slashes after colon, etc)
      var expected_uri = File.new_for_uri(oauth_backend.get_redirect_uri()).get_uri();
      if (provided_uri.has_prefix(expected_uri) && oauth_backend.continue_authorization(provided_uri)) {
        activate();
        return;
      }
    }

    // Got passed files, but we don't know what to do with them.
    foreach (var file in files)
      warning("Ignoring unexpected file: %s", file.get_parse_name());
  }

  MainWindow? get_app_window()
  {
    return main_window.get() as MainWindow;
  }

  AssistantOperation? get_operation()
  {
    return operation.get() as AssistantOperation;
  }

  void show()
  {
    activate();
  }

  bool exit_cleanly()
  {
    quit();
    return Source.REMOVE;
  }

  // Eventually, when we can assume that the system supports color schemes,
  // we can drop this legacy check.
  bool has_dark_gtk_theme()
  {
    // libadwaita will call this for us, but we need it now to check the
    // settings - it's safe to call this multiple times.
    Gtk.init();

    var theme_name = Gtk.Settings.get_default().gtk_theme_name.casefold();
    var dark_suffix = "-dark".casefold();
    return theme_name.has_suffix(dark_suffix); // very rough heuristic
  }

  public override void startup()
  {
    // grab this before libadwaita overrides it
    var dark_gtk_theme = has_dark_gtk_theme();

    base.startup();
    DejaDup.gui_initialize();

    add_action_entries(ACTIONS, this);
    set_accels_for_action("app.help", {"F1"});
    set_accels_for_action("app.preferences", {"<Control>comma"});
    set_accels_for_action("app.quit", {"<Control>w", "<Control>q"});
    preferences_action = lookup_action("preferences") as SimpleAction;
    quit_action = lookup_action("quit") as SimpleAction;

    notify["custom-backend"].connect(check_preferences_enabled);

    // Cleanly exit (shutting down duplicity as we go)
    Unix.signal_add(ProcessSignal.HUP, exit_cleanly);
    Unix.signal_add(ProcessSignal.INT, exit_cleanly);
    Unix.signal_add(ProcessSignal.TERM, exit_cleanly);

    var display = Gdk.Display.get_default();
    var style_manager = Adw.StyleManager.get_for_display(display);

    if (!style_manager.system_supports_color_schemes && dark_gtk_theme) {
      // We can't follow the gtk theme as it changes, but this is good
      // enough for now - start up with the right dark/light preference.
      style_manager.color_scheme = Adw.ColorScheme.PREFER_DARK;
    }

    if (DejaDup.in_demo_mode())
    {
      // Use default GNOME settings as much as possible.
      // The goal here is that we are suitable for screenshots.
      var gtksettings = Gtk.Settings.get_for_display(display);

      gtksettings.gtk_decoration_layout = ":close";
      gtksettings.gtk_font_name = "Cantarell 11";
      gtksettings.gtk_icon_theme_name = "Adwaita";
      style_manager.color_scheme = Adw.ColorScheme.FORCE_LIGHT;
    }
  }

  public override void shutdown()
  {
    if (get_operation() != null)
      get_operation().stop();
    base.shutdown();
  }

  void check_preferences_enabled()
  {
    preferences_action.set_enabled(get_operation() == null && custom_backend == null);
  }

  void operation_closed()
  {
    check_preferences_enabled();
    quit_action.set_enabled(true);
  }

  void assign_op(AssistantOperation op, bool automatic)
  {
    if (get_operation() != null) {
      warning("Trying to override operation! This shouldn't happen.");
      return;
    }

    operation.set(op);
    ((Gtk.Widget)op).destroy.connect(operation_closed);
    check_preferences_enabled();
    quit_action.set_enabled(false);
    operation_started();

    if (get_app_window() != null) {
      op.transient_for = get_app_window();
      op.modal = true;
      op.destroy_with_parent = true;
      get_app_window().present();
    }

    // We show operation window if the main window is open, because that would
    // just cause confusion to have a hidden operation window. This does steal
    // focus by surfacing a new window though...
    if (automatic && get_app_window() == null) {
      Notifications.automatic_backup_started();
    } else {
      op.present();
    }
  }

  public void delay(GLib.SimpleAction action, GLib.Variant? parameter)
  {
    string reason = null;
    parameter.get("s", ref reason);
    Notifications.automatic_backup_delayed(reason);
  }

  void preferences()
  {
    if (preferences_window.get() != null)
      return;

    var window = new PreferencesWindow();
    window.set_transient_for(get_app_window());
    window.application = this;
    window.present();
    preferences_window.set(window);
  }

  void help()
  {
    Gtk.show_uri(get_app_window(), "help:" + Config.PACKAGE, Gdk.CURRENT_TIME);
  }

  void about()
  {
    var dialog = new Gtk.AboutDialog();
    dialog.artists = {"Barbara Muraus",
                      "Jakub Steiner"};
    dialog.authors = {"Michael Terry"};
    dialog.license_type = Gtk.License.GPL_3_0;
    dialog.logo_icon_name = Config.ICON_NAME;
    dialog.modal = true;
    dialog.system_information = DebugInfo.get_debug_info();
    dialog.transient_for = get_app_window();
    dialog.translator_credits = _("translator-credits");
    dialog.version = Config.VERSION;
    dialog.website = "https://wiki.gnome.org/Apps/DejaDup";
    dialog.present();
  }

  public void backup()
  {
    if (get_operation() != null) {
      activate();
    } else {
      backup_full(false);
    }
  }

  public void backup_auto()
  {
    if (get_operation() == null) {
      backup_full(true);
    }
  }

  public void backup_auto_stop()
  {
    var backup_op = get_operation() as AssistantBackup;
    if (backup_op != null && backup_op.automatic) {
      backup_op.stop();
    }
  }

  void backup_full(bool automatic)
  {
    close_excess_modals();
    assign_op(new AssistantBackup(automatic), automatic);
  }

  public DejaDup.Backend get_restore_backend()
  {
    if (custom_backend == null)
      return DejaDup.Backend.get_default();
    else
      return custom_backend;
  }

  // Start a restore with a custom backend (e.g. first time restore)
  public void start_custom_restore()
  {
    var assist = new AssistantLocation();
    assist.transient_for = get_app_window();
    assist.present();
  }

  public void search_custom_restore(DejaDup.Backend backend)
  {
    custom_backend = backend; // code in MainWindow will notice this change
  }

  public void restore_files(List<File> file_list, string? when = null, DejaDup.FileTree? tree = null)
  {
    close_excess_modals();
    if (get_operation() != null) {
      activate();
    } else {
      assign_op(new AssistantRestore.with_files(file_list, when, tree), false);
    }
  }

  void prompt_ok()
  {
    prompt_cancel();
    activate();
  }

  void prompt_cancel()
  {
    DejaDup.update_prompt_time(true);
  }

  void close_excess_modals()
  {
    // Things like the about or preference dialogs or no-longer-active progress
    // dialogs. These should be closed if we're about to do something new like
    // a backup or restore operation.
    if (get_operation() != null && !get_operation().has_active_op()) {
      get_operation().closed();
      operation.set(null);
    }

    if (get_operation() != null || get_app_window() == null)
      return; // not safe or needed to continue closing modals

    foreach (var window in get_app_window().get_modals()) {
      window.destroy();
    }
  }
}

int main(string[] args)
{
  DejaDup.i18n_setup();

  // Translators: The name is a play on the French phrase "déjà vu" meaning
  // "already seen", but with the "vu" replaced with "dup".  "Dup" in this
  // context is itself a reference to both the underlying command line tool
  // "duplicity" and the act of duplicating data for backup.  As a whole, the
  // phrase "Déjà Dup" may not be very translatable.
  var appname = _("Déjà Dup Backups");

  Environment.set_application_name(appname);
  Environment.set_prgname(Config.APPLICATION_ID);
  Gtk.Window.set_default_icon_name(Config.ICON_NAME);

  // FIXME: there must be a better way than this?
  typeof(Browser).ensure();
  typeof(ConfigAutoBackup).ensure();
  typeof(ConfigAutoBackupRow).ensure();
  typeof(ConfigDelete).ensure();
  typeof(ConfigFolderList).ensure();
  typeof(ConfigFolderPage).ensure();
  typeof(ConfigLocationCombo).ensure();
  typeof(ConfigLocationCombo.Item).ensure();
  typeof(ConfigLocationGroup).ensure();
  typeof(ConfigPeriodRow).ensure();
  typeof(ConfigRestic).ensure();
  typeof(ConfigServerEntry).ensure();
  typeof(ExcludeHelpButton).ensure();
  typeof(FolderChooserButton).ensure();
  typeof(MainHeaderBar).ensure();
  typeof(OverviewPage).ensure();
  typeof(RecentBackupRow).ensure();
  typeof(ServerHintPopover).ensure();
  typeof(TimeCombo).ensure();
  typeof(TimeCombo.Item).ensure();
  typeof(TooltipBox).ensure();
  typeof(WelcomePage).ensure();

  return DejaDupApp.get_instance().run(args);
}
