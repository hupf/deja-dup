# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 4 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

subdir('widgets')

deja_dup = executable('deja-dup',
    ['main.vala',
     'Assistant.vala',
     'AssistantBackup.vala',
     'AssistantOperation.vala',
     'AssistantRestore.vala',
     'AssistantRestoreMissing.vala',
     'MountOperationAssistant.vala',
     'Preferences.vala',
     'Prompt.vala',
     'StatusIcon.vala'] +
     resources,
    vala_args: common_vflags,
    c_args: common_cflags,
    dependencies: [
        gio_unix_dep,
        goa_dep,
        gtk_dep,
        packagekit_dep,
        secret_dep,
    ],
    link_with: [libdeja, libwidgets],
    include_directories: [libdeja_inc, libwidgets_inc],
    install: true,
    install_rpath: pkglibdir)

subdir('monitor')
subdir('nautilus')
