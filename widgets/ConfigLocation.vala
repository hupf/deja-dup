/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*- */
/*
    This file is part of Déjà Dup.
    © 2008–2010 Michael Terry <mike@mterry.name>

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

public class ConfigLocation : ConfigWidget
{
  static const int COL_ICON = 0;
  static const int COL_TEXT = 1;
  static const int COL_SORT = 2;
  static const int COL_UUID = 3;
  static const int COL_PAGE = 4;
  static const int COL_INDEX = 5;

  public Gtk.EventBox extras {get; private set;}
  public Gtk.SizeGroup label_sizes {get; construct;}

  public Gtk.Requisition hidden_size()
  {
    Gtk.Requisition pagereq;
    extras.size_request(out pagereq);
    pagereq.width = extras_max_width - pagereq.width + 20;
    pagereq.height = extras_max_height - pagereq.height + 20;
    return pagereq;
  }

  public ConfigLocation(Gtk.SizeGroup? sg = null)
  {
    Object(label_sizes: sg);
  }

  int index_ftp;
  int index_dav;
  int index_s3;
  int index_u1 = -2;
  int index_ssh;
  int index_smb;
  int index_vol_base;
  int index_vol_end;
  int index_vol_saved = -2;
  int index_local;

  int extras_max_width = 0;
  int extras_max_height = 0;

  bool internal_set = false;

  Gtk.ComboBox button;
  Gtk.ListStore store;
  Gtk.TreeModelSort sort_model;
  construct {
    var vbox = new Gtk.VBox(false, 6);
    add(vbox);

    // Here we have a model wrapped inside a sortable model.  This is so we
    // can keep indices around for the inner model while the outer model appears
    // nice and sorted to users.
    store = new Gtk.ListStore(6, typeof(Icon), typeof(string), typeof(string),
                              typeof(string), typeof(ConfigLocationTable),
                              typeof(int));
    sort_model = new Gtk.TreeModelSort.with_model(store);
    sort_model.set_sort_column_id(COL_SORT, Gtk.SortType.ASCENDING);
    button = new Gtk.ComboBox.with_model(sort_model);
    button.set_row_separator_func(is_separator);
    vbox.add(button);

    Gtk.TreeIter iter;
    int i = 0;

    if (label_sizes == null)
      label_sizes = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);

    extras = new Gtk.EventBox();
    extras.border_width = 0;
    extras.show();

    var backend = settings.get_string(BACKEND_KEY);

    // Insert cloud providers
    index_s3 = add_entry(i++, new ThemedIcon("deja-dup-cloud"),
                         _("Amazon S3"), 0, new ConfigLocationS3(label_sizes));

    //if (backend == "u1" || DejaDup.BackendUbuntuOne.is_available())
    //  index_u1 = add_entry(i++, new ThemedIcon("ubuntuone"),
    //                       _("Ubuntu One"), 0, new ConfigLocationU1(label_sizes));

    add_separator(i++, 1);

    // Now insert remote servers
    index_ssh = add_entry(i++, new ThemedIcon.with_default_fallbacks("folder-remote"),
                          _("SSH"), 1, new ConfigLocationSSH(label_sizes));
    index_smb = add_entry(i++, new ThemedIcon.with_default_fallbacks("folder-remote"),
                          _("Windows Share"), 1, new ConfigLocationSMB(label_sizes));
    index_ftp = add_entry(i++, new ThemedIcon.with_default_fallbacks("folder-remote"),
                          _("FTP"), 1, new ConfigLocationFTP(label_sizes));
    index_dav = add_entry(i++, new ThemedIcon.with_default_fallbacks("folder-remote"),
                          _("WebDAV"), 1, new ConfigLocationDAV(label_sizes));

    add_separator(i++, 2);

    // And a local folder option
    index_local = add_entry(i++, new ThemedIcon("folder"), _("Local Folder"),
                            3, new ConfigLocationFile(label_sizes));

    // Now insert removable drives
    index_vol_base = i;
    var mon = VolumeMonitor.get();
    mon.ref(); // bug 569418; bad things happen when VM goes away
    List<Volume> vols = mon.get_volumes();
    foreach (Volume v in vols) {
      add_entry(i++, v.get_icon(), v.get_name(), 2,
                new ConfigLocationVolume(label_sizes),
                v.get_identifier(VOLUME_IDENTIFIER_KIND_UUID));
    }
    index_vol_end = i;

    if (index_vol_base != index_vol_end)
      add_separator(i++, 3);

    // And finally a saved volume, if one exists (must be last)
    update_saved_volume();

    var pixrenderer = new Gtk.CellRendererPixbuf();
    button.pack_start(pixrenderer, false);
    button.add_attribute(pixrenderer, "gicon", COL_ICON);

    var textrenderer = new Gtk.CellRendererText();
    button.pack_start(textrenderer, true);
    button.add_attribute(textrenderer, "text", COL_TEXT);

    // End of location combo

    mnemonic_activate.connect(on_mnemonic_activate);

    button.set_active(0); // worst case, activate first entry
    set_from_config();

    handle_changed();
    button.changed.connect(handle_changed);

    watch_key(BACKEND_KEY);
    watch_key(FILE_PATH_KEY, DejaDup.get_settings(FILE_ROOT));
  }
  
  bool is_separator(Gtk.TreeModel model, Gtk.TreeIter iter)
  {
    Value text_var;
    model.get_value(iter, COL_TEXT, out text_var);
    weak string text = text_var.get_string();
    return text == null;
  }

  int add_entry(int index, Icon? icon, string label, int category,
                Gtk.Widget? page = null, string? uuid = null)
  {
    Gtk.TreeIter iter;
    store.insert_with_values(out iter, index, COL_ICON, icon, COL_TEXT, label,
                             COL_SORT, "%d%s".printf(category, label),
                             COL_UUID, uuid, COL_PAGE, page, COL_INDEX, index);

    if (page != null) {
      Gtk.Requisition pagereq;
      page.show_all();
      page.size_request(out pagereq);
      extras_max_width = int.max(extras_max_width, pagereq.width);
      extras_max_height = int.max(extras_max_height, pagereq.height);
    }

    return index;
  }

  int add_separator(int index, int category)
  {
    Gtk.TreeIter iter;
    store.insert_with_values(out iter, index, COL_SORT, "%d".printf(category),
                             COL_TEXT, null, COL_INDEX, index);
    return index;
  }

  bool on_mnemonic_activate(Gtk.Widget w, bool g)
  {
    return true;//button.mnemonic_activate(g);
  }

  bool update_saved_volume()
  {
    // And add an entry for any saved volume
    var fsettings = DejaDup.get_settings(FILE_ROOT);
    var vol_uuid = fsettings.get_string(FILE_UUID_KEY);
    if (vol_uuid != "") {
      Gtk.TreeIter iter;

      Icon vol_icon = null;
      try {
        vol_icon = Icon.new_for_string(fsettings.get_string(FILE_ICON_KEY));
      }
      catch (Error e) {warning("%s\n", e.message);}
      var vol_name = fsettings.get_string(FILE_SHORT_NAME_KEY);

      // If this is the first time, add a new entry
      if (index_vol_saved == -2) {
        index_vol_saved = add_entry(index_vol_end+1, vol_icon, vol_name, 2,
                          new ConfigLocationVolume(label_sizes), vol_uuid);

        if (index_vol_base == index_vol_end)
          add_separator(index_vol_end+2, 3); // this hadn't been added yet, so add it now
      }
      else if (store.get_iter_from_string(out iter, index_vol_saved.to_string()))
        store.set(iter, COL_ICON, vol_icon, COL_TEXT, vol_name, COL_UUID, vol_uuid);

      return true;
    }
    else
      return false;
  }

  protected override async void set_from_config()
  {
    if (internal_set)
      return;

    int index = -1;

    // Check the backend type, then GIO uri if needed
    var backend = settings.get_string(BACKEND_KEY);
    if (backend == "s3")
      index = index_s3;
    else if (backend == "u1")
      index = index_u1;
    else if (backend == "file") {
      var fsettings = DejaDup.get_settings(FILE_ROOT);

      if (fsettings.get_string(FILE_TYPE_KEY) == "volume") {
        if (update_saved_volume())
          index = index_vol_saved;
      }
      else { // normal
        var scheme = ConfigURLPart.read_uri_part(fsettings, FILE_PATH_KEY,
                                                 ConfigURLPart.Part.SCHEME);
        switch (scheme) {
        case "dav":
        case "davs": index = index_dav;   break;
        case "sftp":
        case "ssh":  index = index_ssh;   break;
        case "ftp":  index = index_ftp;   break;
        case "smb":  index = index_smb;   break;
        case "file": index = index_local; break;
        }
      }
    }

    if (index >= 0) {
      Gtk.TreeIter iter, iter0;
      if (store.get_iter_from_string(out iter, index.to_string())) {
        sort_model.convert_child_iter_to_iter(out iter0, iter);
        button.set_active_iter(iter0);
      }
    }
  }

  void handle_changed()
  {
    set_location_info();

    var current = extras.get_child();
    if (current != null)
      extras.remove(current);

    Gtk.TreeIter iter0, iter;
    Value page_var;
    if (button.get_active_iter(out iter0)) {
      sort_model.convert_iter_to_child_iter(out iter, iter0);
      store.get_value(iter, COL_PAGE, out page_var);
      ConfigLocationTable page = page_var.get_object() as ConfigLocationTable;
      if (page != null)
        extras.add(page);
    }
  }

  async void set_location_info()
  {
    Gtk.TreeIter iter0, iter;
    if (!button.get_active_iter(out iter0))
      return;
    sort_model.convert_iter_to_child_iter(out iter, iter0);

    Value index_var;
    store.get_value(iter, COL_INDEX, out index_var);
    var index = index_var.get_int();

    var prev = internal_set;
    internal_set = true;

    if (index == index_s3)
      settings.set_string(BACKEND_KEY, "s3");
    else if (index == index_u1)
      settings.set_string(BACKEND_KEY, "u1");
    else if (index == index_ssh)
      set_remote_info("sftp");
    else if (index == index_ftp)
      set_remote_info("ftp");
    else if (index == index_dav) {
      // Support not overriding davs with dav by checking current value
      var fsettings = DejaDup.get_settings(FILE_ROOT);
      var scheme = ConfigURLPart.read_uri_part(fsettings, FILE_PATH_KEY,
                                               ConfigURLPart.Part.SCHEME);
      if (scheme != "dav" && scheme != "davs")
        scheme = "dav"; // default to non-https, since we do default to encrypted backups
      set_remote_info(scheme);
    }
    else if (index == index_smb)
      set_remote_info("smb");
    else if ((index >= index_vol_base && index < index_vol_end) ||
             index == index_vol_saved)
      yield set_volume_info(index);
    else if (index == index_local)
      set_remote_info("file");
    else {
      warning("Unknown location index %i\n", index);
    }

    changed();

    internal_set = prev;
  }

  async void set_volume_info(int index)
  {
    // Grab volume from model
    Gtk.TreeIter iter;
    Value vol_var;
    if (!store.get_iter_from_string(out iter, index.to_string())) {
      warning("Invalid volume location index %i\n", index);
      return;
    }

    store.get_value(iter, COL_UUID, out vol_var);
    var uuid = vol_var.get_string();
    if (uuid == null) {
      warning("Invalid volume location index %i\n", index);
      return;
    }

    var vol = BackendFile.find_volume_by_uuid(uuid);
    if (vol == null) {
      // Not an error, it's just not plugged in right now
      return;
    }

    yield BackendFile.set_volume_info(vol);
  }

  void set_remote_info(string scheme)
  {
    var fsettings = DejaDup.get_settings(FILE_ROOT);
    fsettings.set_string(FILE_TYPE_KEY, "normal");
    ConfigURLPart.write_uri_part(fsettings, FILE_PATH_KEY,
                                 ConfigURLPart.Part.SCHEME, scheme);
    settings.set_string(BACKEND_KEY, "file");
  }
}

}

