/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Canonical Ltd
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

extern unowned Resource resources_get_resource();

public class DejaDupApp : Gtk.Application
{
  Gtk.ApplicationWindow main_window = null;
  Gtk.MenuButton menu_button = null;
  SimpleAction quit_action = null;
  public AssistantOperation operation {get; private set; default = null;}

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
    {"restore", restore},
    {"op-show", op_show},
    {"prompt-ok", prompt_ok},
    {"prompt-cancel", prompt_cancel},
    {"delay", delay, "s"},
    {"preferences", preferences},
    {"help", help},
    {"menu", menu},
    {"about", about},
    {"quit", quit},
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

      List<File> file_list = new List<File>();
      if (filenames.length > 0) {
        int i = 0;
        while (filenames[i] != null)
          file_list.append(command_line.create_file_for_arg(filenames[i++]));
      }

      restore_full(file_list);
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
      send_delay_notification(reason);
    }
    else if (options.contains("prompt")) {
      prompt(this);
    } else {
      activate();
    }

    return 0;
  }

  public override void activate()
  {
    base.activate();

    if (operation != null)
      operation.present_with_time(Gtk.get_current_event_time());
    else if (main_window != null)
      main_window.present_with_time(Gtk.get_current_event_time());
    else {
      // We're first instance.  Yay!

      var window = new MainWindow(this);
      main_window = window.app_window;
      menu_button = window.menu_button;
      main_window.destroy.connect(() => {
        this.main_window = null;
        this.menu_button = null;
      });
      main_window.show_all();
    }
  }

  bool exit_cleanly()
  {
    quit();
    return Source.REMOVE;
  }

  public override void startup()
  {
    base.startup();

    /* First, check duplicity version info */
    if (!DejaDup.gui_initialize(null)) {
      quit();
      return;
    }

    add_action_entries(ACTIONS, this);
    set_accels_for_action("app.help", {"F1"});
    set_accels_for_action("app.menu", {"F10"});
    set_accels_for_action("app.quit", {"<Primary>q"});
    quit_action = lookup_action("quit") as SimpleAction;

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

  void assign_op(AssistantOperation op)
  {
    if (operation != null) {
      warning("Trying to override operation! This shouldn't happen.");
      return;
    }

    operation = op;
    operation.destroy.connect(clear_op);
    quit_action.set_enabled(false);

    if (main_window != null) {
      operation.transient_for = main_window;
      operation.modal = true;
      operation.destroy_with_parent = true;
      operation.type_hint = Gdk.WindowTypeHint.DIALOG;
      main_window.present_with_time(Gtk.get_current_event_time());
    }

    operation.show_all();
    operation.present_with_time(Gtk.get_current_event_time());

    Gdk.notify_startup_complete();
  }

  public void delay(GLib.SimpleAction action, GLib.Variant? parameter)
  {
    string reason = null;
    parameter.get("s", ref reason);
    send_delay_notification(reason);
  }

  void send_delay_notification(string reason)
  {
    var note = new Notification(_("Scheduled backup delayed"));
    note.set_body(reason);
    note.set_icon(new ThemedIcon(Config.ICON_NAME));
    send_notification("backup-status", note);
  }

  void preferences()
  {
    unowned List<Gtk.Window> list = get_windows();
    PreferencesWindow.show(list == null ? null : list.data);
  }

  void help()
  {
    unowned List<Gtk.Window> list = get_windows();
    DejaDup.show_uri(list == null ? null : list.data,
                     "help:" + Config.PACKAGE);
  }

  void menu()
  {
    if (menu_button != null)
      menu_button.clicked();
  }

  void about()
  {
    unowned List<Gtk.Window> list = get_windows();
    Gtk.show_about_dialog(list == null ? null : list.data,
                          "license-type", Gtk.License.GPL_3_0,
                          "logo-icon-name", Config.ICON_NAME,
                          "translator-credits", _("translator-credits"),
                          "version", Config.VERSION,
                          "website", "https://wiki.gnome.org/Apps/DejaDup");
  }

  public void backup()
  {
    if (operation != null) {
      op_show();
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
    var backop = new AssistantBackup(automatic);
    assign_op(backop);
    // showing or not is handled by AssistantBackup
  }

  public void restore()
  {
    if (operation != null) {
      op_show();
    } else {
      restore_full(null);
    }
  }

  public void restore_files(List<File> file_list, string? when = null)
  {
    if (operation != null) {
      op_show();
    } else {
      restore_full(file_list, when);
    }
  }

  void restore_full(List<File>? file_list, string? when = null)
  {
    assign_op(new AssistantRestore.with_files(file_list, when));
  }

  void op_show()
  {
    // Show operation window if it exists, else just activate
    if (operation != null)
      operation.force_visible(true);
    else
      activate();
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

  resources_get_resource()._register();

  Hdy.init(ref args);

  return DejaDupApp.get_instance().run(args);
}
