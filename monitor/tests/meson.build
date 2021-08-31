# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 4 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

scheduler_test = executable('scheduler-test',
    ['scheduler.vala', meson.project_source_root() + '/monitor/Scheduler.vala'],
    vala_args: common_vflags,
    c_args: common_cflags,
    dependencies: [gio_dep, secret_dep],
    link_with: [libdeja],
    include_directories: [libdeja_inc])
test('scheduler', scheduler_test)

