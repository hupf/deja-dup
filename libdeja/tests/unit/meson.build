# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 4 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

unit_tests = executable('unit-tests', ['unit-tests.vala'],
    vala_args: common_vflags,
    c_args: common_cflags,
    dependencies: [gio_dep, goa_dep, secret_dep],
    link_with: [libdeja],
    include_directories: [libdeja_inc])

test('unit-tests', dbus_run_session,
    env: ['top_builddir=' + meson.build_root(),
          'top_srcdir=' + meson.source_root(),
          'srcdir=' + meson.current_source_dir()],
    args: [unit_tests.full_path()])

# The network test is manual for the moment
network_test = executable('network-test', ['network.vala'],
    vala_args: common_vflags,
    c_args: common_cflags,
    dependencies: [gio_dep, goa_dep, secret_dep],
    link_with: [libdeja],
    include_directories: [libdeja_inc])
