/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Canonical Ltd
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

// Convenience class for adding automatic backup switch to pref shells
public class PreferencesPeriodicSwitch : Gtk.Switch
{
  DejaDup.FilteredSettings settings;
  construct
  {
    settings = DejaDup.get_settings();
    settings.bind(DejaDup.PERIODIC_KEY, this, "active", SettingsBindFlags.GET);
    state_set.connect(request_background);
  }

  bool request_background(bool state)
  {
    if (state) {
      var bg = new Background();
      if (!bg.request_autostart(this)) {
        this.sensitive = !bg.permission_refused;
        this.active = false;
        return true; // don't change state, skip default handler
      }
    }

    settings.set_boolean(DejaDup.PERIODIC_KEY, state);
    return false;
  }
}

public class Preferences : Gtk.Grid
{
  DejaDupApp _app;
  public DejaDupApp app {
    get { return _app; }
    set {
      _app = value;
      _app.notify["op"].connect(() => {
        restore_button.sensitive = _app.op == null;
        backup_button.sensitive = _app.op == null;
      });
      restore_button.sensitive = _app.op == null;
      backup_button.sensitive = _app.op == null;
    }
  }

  DejaDup.ConfigLabelDescription backup_desc;
  Gtk.Button backup_button;
  DejaDup.ConfigLabelDescription restore_desc;
  Gtk.Button restore_button;
  const int PAGE_HMARGIN = 24;
  const int PAGE_VMARGIN = 12;

  Gtk.Widget make_settings_page()
  {
    var settings_page = new Gtk.Grid();
    Gtk.Stack stack = new Gtk.Stack();
    Gtk.Widget w;
    Gtk.Grid table;
    Gtk.TreeIter iter;
    int row;
    int i = 0;
    string name;
    Gtk.SizeGroup label_sizes;

    settings_page.column_spacing = 12;

    var cat_model = new Gtk.ListStore(2, typeof(string), typeof(string));
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
      string sel_name;
      if (tree.get_selection().get_selected(null, out sel_iter)) {
        cat_model.get(sel_iter, 1, out sel_name);
        stack.visible_child_name = sel_name;
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
    table.expand = true;

    row = 0;

    label_sizes = new Gtk.SizeGroup(Gtk.SizeGroupMode.HORIZONTAL);

    w = new Gtk.Image.from_icon_name(Config.ICON_NAME + "-symbolic", Gtk.IconSize.DIALOG);
    w.halign = Gtk.Align.CENTER;
    w.valign = Gtk.Align.START;
    table.attach(w, 0, row, 1, 3);
    w = new DejaDup.ConfigLabelBackupDate(DejaDup.ConfigLabelBackupDate.Kind.LAST);
    w.halign = Gtk.Align.START;
    w.valign = Gtk.Align.START;
    table.attach(w, 1, row, 2, 1);
    ++row;

    w = new DejaDup.ConfigLabelDescription(DejaDup.ConfigLabelDescription.Kind.RESTORE);
    w.halign = Gtk.Align.START;
    w.valign = Gtk.Align.START;
    restore_desc = w as DejaDup.ConfigLabelDescription;
    table.attach(w, 1, row, 2, 1);
    ++row;

    w = new Gtk.Button.with_mnemonic(_("_Restore…"));
    w.margin_top = 6;
    w.halign = Gtk.Align.START;
    w.expand = false;
    ((Gtk.Button)w).clicked.connect((b) => {app.restore();});
    restore_button = w as Gtk.Button;
    label_sizes.add_widget(w);
    table.attach(w, 1, row, 1, 1);
    ++row;

    w = new Gtk.Grid(); // spacer
    w.height_request = 24; // plus 12 pixels on either side
    table.attach(w, 0, row, 2, 1);
    ++row;

    w = new Gtk.Image.from_icon_name("document-open-recent-symbolic", Gtk.IconSize.DIALOG);
    w.halign = Gtk.Align.CENTER;
    w.valign = Gtk.Align.START;
    table.attach(w, 0, row, 1, 3);
    w = new DejaDup.ConfigLabelBackupDate(DejaDup.ConfigLabelBackupDate.Kind.NEXT);
    w.halign = Gtk.Align.START;
    w.valign = Gtk.Align.START;
    table.attach(w, 1, row, 2, 1);
    ++row;

    w = new DejaDup.ConfigLabelDescription(DejaDup.ConfigLabelDescription.Kind.BACKUP);
    w.halign = Gtk.Align.START;
    w.valign = Gtk.Align.START;
    backup_desc = w as DejaDup.ConfigLabelDescription;
    table.attach(w, 1, row, 2, 1);
    ++row;

    w = new Gtk.Button.with_mnemonic(_("_Back Up Now…"));
    w.margin_top = 6;
    w.halign = Gtk.Align.START;
    w.expand = false;
    ((Gtk.Button)w).clicked.connect((b) => {app.backup();});
    backup_button = w as Gtk.Button;
    label_sizes.add_widget(w);
    table.attach(w, 1, row, 1, 1);
    ++row;

    name = "overview";
    stack.add_named(table, name);
    cat_model.insert_with_values(out iter, i, 0, _("Overview"), 1, name);
    ++i;

    stack.show_all(); // can't switch to pages that aren't shown

    // Select first one by default
    cat_model.get_iter_first(out iter);
    tree.get_selection().select_iter(iter);

    stack.expand = true;
    settings_page.add(stack);

    settings_page.show();
    return settings_page;
  }

  Gtk.Grid new_panel()
  {
    var table = new Gtk.Grid();
    table.margin_start = PAGE_HMARGIN;
    table.margin_end = PAGE_HMARGIN;
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
