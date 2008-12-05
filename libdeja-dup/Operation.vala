/* -*- Mode: C; indent-tabs-mode: nil; c-basic-offset: 2; tab-width: 2 -*- */
/*
    Déjà Dup
    © 2008 Michael Terry <mike@mterry.name>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

using GLib;

namespace DejaDup {

public abstract class Operation : Object
{
  public signal void done(bool success);
  public signal void raise_error(string errstr);
  public signal void action_desc_changed(string action);
  public signal bool passphrase_required();
  public signal bool backend_password_required();
  
  public Gtk.Window toplevel {get; construct;}
  
  protected Duplicity dup;
  protected Backend backend;
  string passphrase;
  construct
  {
    dup = new Duplicity(toplevel);
    backend = Backend.get_default(toplevel);
    
    // Default is to go ahead with password collection.  This will be
    // overridden by anyone else that connects to this signal.
    passphrase_required += (o) => {return true;};
    backend_password_required += (o) => {return true;};
  }
  
  public virtual void start() throws Error
  {
    if (backend == null) {
      done(false);
      return;
    }
    
    dup.done += operation_finished;
    dup.raise_error += (d, s) => {raise_error(s);};
    backend.envp_ready += continue_with_envp;
    backend.need_password += (b) => {
      bool can_ask_now = backend_password_required();
      if (can_ask_now)
        backend.ask_password();
    };
    
    // Get encryption passphrase if needed
    var client = GConf.Client.get_default();
    if (client.get_bool(ENCRYPT_KEY))
      get_passphrase(); // will call continue_with_passphrase when ready
    else
      continue_with_passphrase();
  }
  
  public void cancel()
  {
    dup.cancel();
  }
  
  void continue_with_passphrase() throws Error
  {
    backend.get_envp();
  }
  
  void continue_with_envp(DejaDup.Backend b, bool success, List<string>? envp) {
    if (!success) {
      done(false);
      return;
    }
    
    try {
      var client = GConf.Client.get_default();
      if (client.get_bool(ENCRYPT_KEY))
        envp.append("PASSPHRASE=%s".printf(passphrase));
      
      List<string> argv = make_argv();
      if (argv == null) {
        done(false);
        return;
      }
      
      backend.add_argv(ref argv);
      
      dup.start(argv, envp);
    }
    catch (Error e) {
      printerr("%s\n", e.message);
      done(false);
      return;
    }
  }
  
  protected virtual void operation_finished(Duplicity dup, bool success, bool cancelled)
  {
    done(success);
  }
  
  protected abstract List<string>? make_argv() throws Error;
  
  void found_passphrase(GnomeKeyring.Result result, string? str)
  {
    if (result == GnomeKeyring.Result.OK)
      passphrase = str;
    
    try {
      if (passphrase != null)
        continue_with_passphrase();
      else {
        bool can_ask_now = passphrase_required();
        if (can_ask_now)
          ask_passphrase();
        // else wait for consumer of Operation to call ask_passphrase
      }
    }
    catch (Error e) {
      printerr("%s\n", e.message);
    }
  }
  
  void get_passphrase()
  {
    // First, try user's keyring
    GnomeKeyring.find_password(PASSPHRASE_SCHEMA,
                               found_passphrase, null,
                               "owner", Config.PACKAGE,
                               "type", "passphrase");
  }
  
  public void ask_passphrase() throws Error
  {
    // Ask user
    var dlg = new Gnome.PasswordDialog(_("Encryption Password"),
                                       _("Enter the password used to encrypt your backup files."),
                                       "", "", false);
    dlg.transient_parent = toplevel;
    dlg.show_remember = true;
    dlg.show_username = false;
    if (!dlg.run_and_block()) {
      done(false);
      return;
    }
    
    passphrase = dlg.get_password();
    
    // Save it
    var remember = dlg.get_remember();
    if (remember != Gnome.PasswordDialogRemember.NOTHING) {
      string where = remember == Gnome.PasswordDialogRemember.SESSION ?
                                 "session" : GnomeKeyring.DEFAULT;
      GnomeKeyring.store_password(PASSPHRASE_SCHEMA,
                                  where,
                                  _("Déjà Dup backup passphrase"),
                                  passphrase, null, null,
                                  "owner", Config.PACKAGE,
                                  "type", "passphrase");
    }
    
    continue_with_passphrase();
  }
  
  public void ask_backend_password() throws Error
  {
    backend.ask_password();
  }
}

} // end namespace

