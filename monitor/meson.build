# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 2 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

monitor = executable(
  'deja-dup-monitor',
  'BackupInterface.vala',
  'GameMode.vala',
  'monitor.vala',
  'ReadyWatcher.vala',
  'Scheduler.vala',
  dependencies: [
    gio_dep,
    secret_dep,
  ],
  include_directories: [libdeja_inc],
  install: true,
  install_dir: pkglibexecdir,
  install_rpath: pkglibdir,
  link_with: [libdeja],
)

monitor_devenv = environment({
  'DEJA_DUP_MONITOR_EXEC': monitor.full_path(),
})
monitor_devenv.prepend('PATH', meson.current_build_dir())
meson.add_devenv(monitor_devenv)

subdir('tests')
