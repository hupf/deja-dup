# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 4 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

executable('deja-dup-monitor', ['monitor.vala'],
    vala_args: common_vflags,
    c_args: common_cflags,
    dependencies: [gio_dep, secret_dep],
    link_with: [libdeja],
    include_directories: [libdeja_inc],
    install: true,
    install_rpath: pkglibdir,
    install_dir: pkglibexecdir)
