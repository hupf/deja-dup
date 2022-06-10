/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

[GtkTemplate (ui = "/org/gnome/DejaDup/ConfigFolderPage.ui")]
public class ConfigFolderPage : Adw.PreferencesPage
{
#if HAS_ADWAITA_1_1
  [GtkChild]
  unowned ConfigFolderList exclude_list;
#endif

  construct {
#if HAS_ADWAITA_1_1
    exclude_list.header_suffix = new ExcludeHelpButton();
#endif
  }
}
