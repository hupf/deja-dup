# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 4 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

libdeja_tests = executable('libdeja-tests', ['unit-tests.vala'],
    dependencies: [gio_dep, secret_dep],
    link_with: [libdeja],
    include_directories: [libdeja_inc])

if dbus_run_session.found()
test(
    'libdeja',
    dbus_run_session,
    env: ['srcdir=' + meson.current_source_dir()],
    args: [libdeja_tests],
)
endif

# The network test is manual for the moment
network_test = executable('network-test', ['network.vala'],
    dependencies: [gio_dep, secret_dep],
    link_with: [libdeja],
    include_directories: [libdeja_inc])
