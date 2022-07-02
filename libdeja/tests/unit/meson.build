# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 2 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

libdeja_tests = executable(
  'libdeja-tests',
  'unit-tests.vala',
  build_by_default: false,
  dependencies: [
    gio_dep,
    secret_dep,
  ],
  include_directories: [libdeja_inc],
  link_with: [libdeja],
)

if dbus_run_session.found()
  test(
    'libdeja',
    dbus_run_session,
    args: [libdeja_tests],
    env: ['srcdir=' + meson.current_source_dir()],
  )
endif

# The network test is manual for the moment
network_test = executable(
  'network-test',
  'network.vala',
  build_by_default: false,
  dependencies: [
    gio_dep,
    secret_dep,
  ],
  include_directories: [libdeja_inc],
  link_with: [libdeja],
)
