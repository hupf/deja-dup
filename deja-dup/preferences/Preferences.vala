/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*- */
/*
    This file is part of Déjà Dup.
    For copyright information, see AUTHORS.

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

// Convenience class for adding automatic backup switch to pref shells
public class PreferencesPeriodicSwitch : Gtk.Switch
{
  construct
  {
    var settings = DejaDup.get_settings();
    settings.bind(DejaDup.PERIODIC_KEY, this, "active", SettingsBindFlags.DEFAULT);
  }
}

public class Preferences : Gtk.Grid
{
  public bool show_auto_switch {get; construct;}

  Gtk.Widget backup_button;
  Gtk.Widget restore_button;
  uint bus_watch_id = 0;
  static const int PAGE_HMARGIN = 24;
  static const int PAGE_VMARGIN = 12;

  public Preferences(bool show_auto_switch)
  {
    Object(show_auto_switch: show_auto_switch);
  }

  ~Preferences() {
    if (bus_watch_id > 0) {
      Bus.unwatch_name(bus_watch_id);
      bus_watch_id = 0;
    }
  }

  Gtk.Widget make_settings_page()
  {
    var settings_page = new Gtk.Grid();
    Gtk.Notebook notebook = new Gtk.Notebook();
    Gtk.Widget w;
    Gtk.Label label;
    Gtk.Grid table;
    Gtk.TreeIter iter;
    int i = 0;
    int row;
    Gtk.SizeGroup label_sizes;

    var settings = DejaDup.get_settings();

    settings_page.column_spacing = 12;

    var cat_model = new Gtk.ListStore(2, typeof(string), typeof(int));
    var tree = new Gtk.TreeView.with_model(cat_model);
    var accessible = tree.get_accessible();
    if (accessible != null) {
      accessible.set_name("Categories");
      accessible.set_description(_("Categories"));
    }
    tree.headers_visible = false;
    tree.set_size_request(150, -1);
    var renderer = new Gtk.CellRendererText();
    renderer.xpad = 6;
    renderer.ypad = 6;
    tree.insert_column_with_attributes(-1, null, renderer,
                                       "text", 0);
    tree.get_selection().set_mode(Gtk.SelectionMode.SINGLE);
    tree.get_selection().changed.connect(() => {
      Gtk.TreeIter sel_iter;
      int page;
      if (tree.get_selection().get_selected(null, out sel_iter)) {
        cat_model.get(sel_iter, 1, out page);
        notebook.page = page;
      }
    });

    var scrollwin = new Gtk.ScrolledWindow(null, null);
    scrollwin.hscrollbar_policy = Gtk.PolicyType.NEVER;
    scrollwin.vscrollbar_policy = Gtk.PolicyType.NEVER;
    scrollwin.shadow_type = Gtk.ShadowType.IN;
    scrollwin.add(tree);
    settings_page.add(scrollwin);

    table = new_panel();
    table.orientation = Gtk.Orientation.VERTICAL;
    table.row_spacing = 6;
    table.column_spacing = 12;
    table.column_homogeneous = true;
    table.expand = true;

    row = 0;

    if (show_auto_switch) {
      var align = new Gtk.Alignment(0.0f, 0.5f, 0.0f, 0.0f);
      var @switch = new Gtk.Switch();
      settings.bind(DejaDup.PERIODIC_KEY, @switch, "active", SettingsBindFlags.DEFAULT);
      align.add(@switch);
      label = new Gtk.Label.with_mnemonic(_("_Automatic backup"));
      label.mnemonic_widget = @switch;
      label.xalign = 1.0f;
      var switch_grid = new Gtk.Grid();
      switch_grid.column_spacing = 12;
      switch_grid.halign = Gtk.Align.CENTER;
      switch_grid.attach(label, 0, 0, 1, 1);
      switch_grid.attach(align, 1, 0, 1, 1);
      table.attach(switch_grid, 0, row, 2, 1);
      ++row;
    }

    var bdate_label = new Gtk.Label("<span size=\"x-large\">%s</span>".printf(_("Last")));
    bdate_label.vexpand = true;
    bdate_label.valign = Gtk.Align.END;
    bdate_label.use_markup = true;
    bdate_label.xalign = 0.5f;
    var ndate_label = new Gtk.Label("<span size=\"x-large\">%s</span>".printf(_("Next")));
    ndate_label.vexpand = true;
    ndate_label.valign = Gtk.Align.END;
    ndate_label.use_markup = true;
    ndate_label.xalign = 0.5f;
    table.attach(bdate_label, 0, row, 1, 1);
    table.attach(ndate_label, 1, row, 1, 1);
    ++row;

    var bdate = new DejaDup.ConfigLabelBackupDate(DejaDup.ConfigLabelBackupDate.Kind.LAST);
    bdate.bind_property("sensitive", bdate_label, "sensitive", BindingFlags.SYNC_CREATE);
    var ndate = new DejaDup.ConfigLabelBackupDate(DejaDup.ConfigLabelBackupDate.Kind.NEXT);
    ndate.bind_property("sensitive", ndate_label, "sensitive", BindingFlags.SYNC_CREATE);
    table.attach(bdate, 0, row, 1, 1);
    table.attach(ndate, 1, row, 1, 1);
    ++row;

    w = new Gtk.Grid(); // spacer
    w.height_request = 24; // plus 6 pixels on either side
    table.attach(w, 0, row, 2, 1);
    ++row;

    label_sizes = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
    w = new Gtk.Button.with_mnemonic(_("_Restore…"));
    w.vexpand = true;
    w.valign = Gtk.Align.START;
    w.halign = Gtk.Align.CENTER;
    (w as Gtk.Button).clicked.connect((b) => {
      run_deja_dup("--restore", b.get_display().get_app_launch_context());
    });
    restore_button = w;
    label_sizes.add_widget(w);
    table.attach(w, 0, row, 1, 1);
    w = new Gtk.Button.with_mnemonic(_("Back Up…"));
    w.vexpand = true;
    w.valign = Gtk.Align.START;
    w.halign = Gtk.Align.CENTER;
    (w as Gtk.Button).clicked.connect((b) => {
      run_deja_dup("--backup", b.get_display().get_app_launch_context());
    });
    backup_button = w;
    label_sizes.add_widget(w);
    table.attach(w, 1, row, 1, 1);
    ++row;

    bus_watch_id = Bus.watch_name(BusType.SESSION, "org.gnome.DejaDup.Operation",
                                  BusNameWatcherFlags.NONE,
                                  () => {restore_button.sensitive = false;
                                         backup_button.sensitive = false;},
                                  () => {restore_button.sensitive = true;
                                         backup_button.sensitive = true;});

    notebook.append_page(table, null);
    cat_model.insert_with_values(out iter, i, 0, _("Overview"), 1, i);
    ++i;

    // Reset page
    table = new_panel();

    w = new DejaDup.ConfigList(DejaDup.INCLUDE_LIST_KEY);
    w.expand = true;
    table.add(w);

    notebook.append_page(table, null);
    cat_model.insert_with_values(out iter, i, 0, _("Folders to save"), 1, i);
    ++i;

    // Reset page
    table = new_panel();

    w = new DejaDup.ConfigList(DejaDup.EXCLUDE_LIST_KEY);
    w.expand = true;
    table.add(w);

    notebook.append_page(table, null);
    cat_model.insert_with_values(out iter, i, 0, _("Folders to ignore"), 1, i);
    ++i;

    // Reset page
    table = new_panel();
    table.row_spacing = 6;
    table.column_spacing = 12;
    row = 0;

    label_sizes = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);
    var location = new DejaDup.ConfigLocation(label_sizes);
    label = new Gtk.Label(_("_Storage location"));
    label.set("mnemonic-widget", location,
              "use-underline", true,
              "xalign", 1.0f);
    label_sizes.add_widget(label);

    table.attach(label, 0, row, 1, 1);
    table.attach(location, 1, row, 1, 1);
    location.set("hexpand", true);
    ++row;

    location.extras.set("hexpand", true);
    table.attach(location.extras, 0, row, 2, 1);
    ++row;

    notebook.append_page(table, null);
    // Translators: storage as in "where to store the backup"
    cat_model.insert_with_values(out iter, i, 0, _("Storage location"), 1, i);
    ++i;

    // Now make sure to reserve the excess space that the hidden bits of
    // ConfigLocation will need.
    Gtk.Requisition req, hidden;
    table.show_all();
    table.get_preferred_size(null, out req);
    hidden = location.hidden_size();
    req.width = req.width + hidden.width;
    req.height = req.height + hidden.height;
    table.set_size_request(req.width, req.height);

    // Reset page
    table = new_panel();
    table.row_spacing = 6;
    table.column_spacing = 12;
    table.halign = Gtk.Align.CENTER;
    row = 0;

    if (show_auto_switch) {
      var align = new Gtk.Alignment(0.0f, 0.5f, 0.0f, 0.0f);
      var @switch = new Gtk.Switch();
      settings.bind(DejaDup.PERIODIC_KEY, @switch, "active", SettingsBindFlags.DEFAULT);
      align.add(@switch);
      label = new Gtk.Label.with_mnemonic(_("_Automatic backup"));
      label.mnemonic_widget = @switch;
      label.xalign = 1.0f;
      table.attach(label, 0, row, 1, 1);
      table.attach(align, 1, row, 1, 1);
      ++row;
    }

    w = new DejaDup.ConfigPeriod(DejaDup.PERIODIC_PERIOD_KEY);
    w.hexpand = true;
    settings.bind(DejaDup.PERIODIC_KEY, w, "sensitive", SettingsBindFlags.GET);
    // translators: as in "Every day"
    label = new Gtk.Label.with_mnemonic(_("_Every"));
    label.mnemonic_widget = w;
    label.xalign = 1.0f;
    settings.bind(DejaDup.PERIODIC_KEY, label, "sensitive", SettingsBindFlags.GET);
    table.attach(label, 0, row, 1, 1);
    table.attach(w, 1, row, 1, 1);
    ++row;

    w = new DejaDup.ConfigDelete(DejaDup.DELETE_AFTER_KEY);
    w.hexpand = true;
    label = new Gtk.Label.with_mnemonic(C_("verb", "_Keep"));
    label.mnemonic_widget = w;
    label.xalign = 1.0f;
    table.attach(label, 0, row, 1, 1);
    table.attach(w, 1, row, 1, 1);
    ++row;

    label = new Gtk.Label(_("Old backups will be deleted earlier if the storage location is low on space."));
    var attrs = new Pango.AttrList();
    attrs.insert(Pango.attr_style_new(Pango.Style.ITALIC));
    label.set_attributes(attrs);
    label.wrap = true;
    label.max_width_chars = 25;
    table.attach(label, 1, row, 1, 1);
    ++row;

    notebook.append_page(table, null);
    cat_model.insert_with_values(out iter, i, 0, _("Scheduling"), 1, i);
    ++i;

    // Select first one by default
    cat_model.get_iter_first(out iter);
    tree.get_selection().select_iter(iter);

    notebook.show_tabs = false;
    notebook.show_border = false;
    notebook.expand = true;
    settings_page.add(notebook);

    settings_page.show();
    return settings_page;
  }

  Gtk.Grid new_panel()
  {
    var table = new Gtk.Grid();
    table.margin_left = PAGE_HMARGIN;
    table.margin_right = PAGE_HMARGIN;
    table.margin_top = PAGE_VMARGIN;
    table.margin_bottom = PAGE_VMARGIN;
    return table;
  }

  construct {
    add(make_settings_page());
    set_size_request(-1, 400);
  }
}

}
