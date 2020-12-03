/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Canonical Ltd
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class DejaDupApp : Gtk.Application
{
  WeakRef main_window;
  SimpleAction quit_action = null;
  public AssistantOperation operation {get; private set; default = null;}
  public DejaDup.Backend custom_backend {get; set; default = null;}

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
    {"prompt-ok", prompt_ok},
    {"prompt-cancel", prompt_cancel},
    {"delay", delay, "s"},
    {"preferences", preferences},
    {"help", help},
    {"menu", menu},
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
    Object(application_id: Config.APPLICATION_ID,
           flags: ApplicationFlags.HANDLES_COMMAND_LINE);
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

    string[] filenames = {};
    if (options.contains("")) {
      var variant = options.lookup_value("", VariantType.BYTESTRING_ARRAY);
      filenames = variant.get_bytestring_array();
    }

    if (options.contains("restore")) {
      if (operation != null) {
        command_line.printerr("%s\n", _("An operation is already in progress"));
        return 1;
      }

      if (filenames.length == 0) {
        command_line.printerr("%s\n", _("Please list files to restore"));
        return 1;
      }

      var file_list = new List<File>();
      int i = 0;
      while (filenames[i] != null)
        file_list.append(command_line.create_file_for_arg(filenames[i++]));

      restore_files(file_list);
    }
    else if (options.contains("backup")) {
      if (operation != null) {
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
    } else {
      activate();
    }

    return 0;
  }

  public override void activate()
  {
    base.activate();

    if (operation != null) {
      operation.present();
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

  Gtk.ApplicationWindow? get_app_window()
  {
    return main_window.get() as Gtk.ApplicationWindow;
  }

  unowned MainHeaderBar? get_header()
  {
    var win = main_window.get() as MainWindow;
    if (win == null)
      return null;
    return win.get_titlebar() as MainHeaderBar;
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

  public override void startup()
  {
    base.startup();

    Hdy.init();
    DejaDup.gui_initialize();

    add_action_entries(ACTIONS, this);
    set_accels_for_action("app.help", {"F1"});
    set_accels_for_action("app.menu", {"F10"});
    set_accels_for_action("app.quit", {"<Control>q"});
    quit_action = lookup_action("quit") as SimpleAction;

    notify["custom-backend"].connect(() => {
      var prefs_action = lookup_action("preferences") as SimpleAction;
      prefs_action.set_enabled(custom_backend == null);
    });

    // Cleanly exit (shutting down duplicity as we go)
    Unix.signal_add(ProcessSignal.HUP, exit_cleanly);
    Unix.signal_add(ProcessSignal.INT, exit_cleanly);
    Unix.signal_add(ProcessSignal.TERM, exit_cleanly);
  }

  public override void shutdown()
  {
    if (operation != null)
      operation.stop();
    base.shutdown();
  }

  void clear_op()
  {
    operation = null;
    quit_action.set_enabled(true);
  }

  void assign_op(AssistantOperation op, bool automatic)
  {
    if (operation != null) {
      warning("Trying to override operation! This shouldn't happen.");
      return;
    }

    operation = op;
    ((Gtk.Widget)operation).destroy.connect(clear_op);
    quit_action.set_enabled(false);

    if (get_app_window() != null) {
      operation.transient_for = get_app_window();
      operation.modal = true;
      operation.destroy_with_parent = true;
      get_app_window().present();
    }

    // We show operation window if the main window is open, because that would
    // just cause confusion to have a hidden operation window. This does steal
    // focus by surfacing a new window though...
    if (automatic && get_app_window() == null) {
      Notifications.automatic_backup_started();
    } else {
      operation.present();
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
    var window = new PreferencesWindow();
    window.set_transient_for(get_app_window());
    window.application = this;
    window.present();
  }

  void help()
  {
    Gtk.show_uri(get_app_window(), "help:" + Config.PACKAGE, Gdk.CURRENT_TIME);
  }

  void menu()
  {
    if (get_header() == null)
      return;
    get_header().open_menu();
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
    if (operation != null) {
      activate();
    } else {
      backup_full(false);
    }
  }

  public void backup_auto()
  {
    if (operation == null) {
      backup_full(true);
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
    if (operation != null) {
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
    if (operation != null && !operation.has_active_op()) {
      operation.destroy();
      clear_op();
    }

    if (operation != null || get_app_window() == null)
      return; // not safe or needed to continue closing modals

    foreach (var window in Gtk.Window.list_toplevels()) {
      if (window.transient_for == get_app_window() && window.modal && window.visible) {
        window.destroy();
      }
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
  typeof(ConfigDelete).ensure();
  typeof(ConfigFolderList).ensure();
  typeof(ConfigFolderPage).ensure();
  typeof(ConfigLocationGrid).ensure();
  typeof(ConfigPeriod).ensure();
  typeof(ConfigServerEntry).ensure();
  typeof(ConfigStatusLabel).ensure();
  typeof(MainHeaderBar).ensure();

  return DejaDupApp.get_instance().run(args);
}
