# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 4 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

monitor = executable('deja-dup-monitor',
    [
        'BackupInterface.vala',
        'GameMode.vala',
        'monitor.vala',
        'ReadyWatcher.vala',
        'Scheduler.vala',
    ],
    vala_args: common_vflags,
    c_args: common_cflags,
    dependencies: [gio_dep, secret_dep],
    link_with: [libdeja],
    include_directories: [libdeja_inc],
    install: true,
    install_rpath: pkglibdir,
    install_dir: pkglibexecdir,
)

monitor_devenv = environment()
monitor_devenv.set('DEJA_DUP_MONITOR_EXEC', monitor.full_path())
monitor_devenv.prepend('PATH', meson.current_build_dir())
meson.add_devenv(monitor_devenv)

subdir('tests')
