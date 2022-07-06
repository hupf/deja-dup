# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 2 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

# Before 0.56.1, these vala bindings were kept in the main gtk4 vapi
gtk_target_deps = []
if vala.version().version_compare('>= 0.56.1')
  gtk_target_deps = [gtk_wayland_dep, gtk_x11_dep]
endif


deja_dup = executable(
  'deja-dup',
  'Assistant.vala',
  'AssistantBackup.vala',
  'AssistantLocation.vala',
  'AssistantOperation.vala',
  'AssistantRestore.vala',
  'Background.vala',
  'Browser.vala',
  'ConfigAutoBackup.vala',
  'ConfigAutoBackupRow.vala',
  'ConfigComboRow.vala',
  'ConfigDeleteRow.vala',
  'ConfigFolderList.vala',
  'ConfigFolderPage.vala',
  'ConfigFolderRow.vala',
  'ConfigLocationCombo.vala',
  'ConfigLocationGroup.vala',
  'ConfigPeriodRow.vala',
  'ConfigRestic.vala',
  'ConfigServerEntry.vala',
  'ConfigSwitch.vala',
  'DebugInfo.vala',
  'DynamicPreferencesGroup.vala',
  'ExcludeHelpButton.vala',
  'FileStore.vala',
  'FolderChooserButton.vala',
  'main.vala',
  'MainHeaderBar.vala',
  'MainWindow.vala',
  'MountOperationAssistant.vala',
  'Notifications.vala',
  'OverviewPage.vala',
  'PassphraseDialog.vala',
  'PreferencesWindow.vala',
  'RecentBackupRow.vala',
  'RestoreFileTester.vala',
  'ServerHintPopover.vala',
  'SwitchRow.vala',
  'TimeCombo.vala',
  'TooltipBox.vala',
  'WelcomePage.vala',
  'WidgetUtils.vala',
  resources,
  dependencies: [
    adwaita_dep,
    gio_unix_dep,
    gtk_dep,
    gtk_target_deps,
    packagekit_dep,
    secret_dep,
  ],
  include_directories: [libdeja_inc],
  install: true,
  install_rpath: pkglibdir,
  link_with: [libdeja],
  vala_args: [
    '--gresourcesdir=@0@/data/ui'.format(meson.project_source_root()),
  ],
)
