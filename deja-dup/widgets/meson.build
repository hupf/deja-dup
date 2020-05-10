# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 4 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

libwidgets = shared_library('widgets',
    ['Background.vala',
     'ConfigLabel.vala',
     'ConfigLabelBackupDate.vala',
     'ConfigLabelDescription.vala',
     'ConfigWidget.vala',
     'WidgetUtils.vala'],
    vala_args: common_vflags,
    c_args: common_cflags,
    dependencies: [
        gdk_x11_dep,
        gtk_dep,
        secret_dep
    ],
    link_with: [libdeja],
    include_directories: [libdeja_inc],
    install: true,
    install_dir: pkglibdir)

libwidgets_inc = include_directories('.')
