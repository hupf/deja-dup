# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 4 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

if nautilus_dep.found()

# Done separately because nautilus-extension's .gir file is named differently
# than its .pc file, and meson doesn't handle that gracefully.
dirhandling = static_library('dirhandling',
    [join_paths(meson.source_root(), 'libdeja', 'DirHandling.vala')],
    c_args: common_cflags,
    vala_args: common_vflags,
    dependencies: [gio_dep])

shared_module('deja-dup', ['NautilusExtension.c'],
    c_args: common_cflags,
    link_with: [dirhandling],
    dependencies: [nautilus_dep],
    install: true,
    install_dir: nautilus_dep.get_pkgconfig_variable('extensiondir'))

endif
