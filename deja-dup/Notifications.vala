/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class Notifications : Object
{
  public static void automatic_backup_started()
  {
    send_status(_("Starting scheduled backup"), null, NotificationPriority.LOW);
  }

  public static void automatic_backup_delayed(string reason)
  {
    send_status(_("Scheduled backup delayed"), reason);
  }

  public static void backup_finished(Gtk.Window win, bool success,
                                     bool cancelled, string? detail)
  {
    if (!window_is_active(win) && success && !cancelled) {
      string title = _("Backup completed");
      var priority = NotificationPriority.LOW;

      string body = null;
      if (detail != null) {
        title = _("Backup finished");
        body = _("But not all files were successfully backed up.");
        priority = NotificationPriority.NORMAL;
      }

      send_status(title, body, priority);
    }
    else if (!window_is_active(win) && !success && !cancelled) {
      send_status(_("Backup failed"));
    }
    else {
      // We're done with this backup, no need to still talk about it
      withdraw_status();
    }
  }

  public static void restore_finished(Gtk.Window win, bool success,
                                      bool cancelled, string? detail)
  {
    if (!window_is_active(win) && !success && !cancelled)
      send_status(_("Restore failed"));
  }

  public static void operation_blocked(Gtk.Window win, string title,
                                       string? body = null)
  {
    if (!window_is_active(win))
      send_status(title, body);
  }

  public static void attention_needed(Gtk.Window win, string title,
                                      string? body = null)
  {
    if (!window_is_active(win))
      send_status(title, body, NotificationPriority.HIGH);
  }

  public static void prompt()
  {
    DejaDup.update_prompt_time();

    var note = make_note(_("Keep your files safe by backing up regularly"),
                         _("Important documents, data, and settings can be " +
                           "protected by storing them in a backup. In the " +
                           "case of a disaster, you would be able to recover " +
                           "them from that backup."));
    note.set_default_action("app.prompt-ok");
    note.add_button(_("Don’t Show Again"), "app.prompt-cancel");
    note.add_button(_("Open Backups"), "app.prompt-ok");

    Application.get_default().send_notification("prompt", note);
  }

  public static void close_all()
  {
    withdraw_status();
    Application.get_default().withdraw_notification("prompt");
  }

  static Notification make_note(string title, string? body)
  {
    var note = new Notification(title);
    if (body != null)
      note.set_body(body);

    // Allow overriding themed icon, because the notification daemon can't
    // always find it (e.g. snaps or local dev)
    var icon_env = Environment.get_variable("DEJA_DUP_NOTIFICATION_ICON");
    if (icon_env != null)
      note.set_icon(new FileIcon(File.new_for_path(icon_env)));
    else
      note.set_icon(new ThemedIcon(Config.ICON_NAME));

    // Set default action, otherwise the freedesktop notification backend
    // will ignore clicking on the body of a notification.
    note.set_default_action("app.show");

    return note;
  }

  static void send_status(string title, string? body = null,
    NotificationPriority priority = NotificationPriority.NORMAL)
  {
    var note = make_note(title, body);
    note.set_priority(priority);
    Application.get_default().send_notification("backup-status", note);
  }

  static void withdraw_status()
  {
    Application.get_default().withdraw_notification("backup-status");
  }

  static bool window_is_active(Gtk.Window win)
  {
    return win.is_active && win.visible;
  }
}
