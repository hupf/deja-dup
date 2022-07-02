# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 2 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

scheduler_test = executable(
  'scheduler-test',
  'scheduler.vala',
  meson.project_source_root() + '/monitor/Scheduler.vala',
  build_by_default: false,
  dependencies: [
    gio_dep,
    secret_dep,
  ],
  include_directories: [libdeja_inc],
  link_with: [libdeja],
)

test(
  'scheduler',
  scheduler_test,
)
