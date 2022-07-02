# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 2 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

test_runner = executable(
  'test-runner',
  'runner.vala',
  build_by_default: false,
  dependencies: [
    gio_dep,
    secret_dep,
  ],
  include_directories: [libdeja_inc],
  link_with: [libdeja],
)

tests = [
  'bad-hostname',
  'bad-volume',
  'cancel-noop',
  'cancel',
  'clean-cache-if-full',
  'clean-cache',
  'clean-incomplete',
  'clean-tempdir',
  'custom-tool-setup-bad',
  'custom-tool-setup-fails',
  'custom-tool-setup-teardown',
  'custom-tool-wrapper',
  'custom-tool-wrapper-bad',
  'delete-just-right',
  'delete-never',
  'delete-too-few',
  'delete-too-old',
  'disk-full2',
  'disk-full',
  'disk-small',
  'encrypt-ask',
  'encrypt-detect',
  'excludes',
  'instance-error',
  'mkdir',
  'nag',
  'no-space',
  'old-version',
  'permission',
  'read-error',
  'restore-full',
  'restore-specific',
  'special-chars',
  'stop',
  'symlink-direct',
  'symlink-exclude2',
  'symlink-exclude',
  'symlink-follow2',
  'symlink-follow',
  'symlink-loop',
  'symlink-recursive',
  'symlink-subdir',
  'symlink-trickshot',
  'threshold-full',
  'threshold-inc',
  'verify',
  'write-error',
]

if dbus_run_session.found()
  foreach t: tests
    test(
      'script-' + t,
      dbus_run_session,
      args: [test_runner, join_paths(meson.current_source_dir(), 'scripts', t + '.test')],
      env: ['srcdir=' + meson.current_source_dir()],
    )
  endforeach
endif

subdir('unit')
