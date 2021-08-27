# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 4 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

test_runner = executable('test-runner', ['runner.vala'],
    vala_args: common_vflags,
    c_args: common_cflags,
    dependencies: [gio_dep, secret_dep],
    link_with: [libdeja],
    include_directories: [libdeja_inc])

tests = [
    'bad-hostname',
    'bad-volume',
    'cancel-noop',
    'cancel',
    'clean-cache-if-full',
    'clean-cache',
    'clean-incomplete',
    'clean-tempdir',
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
    'write-error'
]

foreach t: tests
    test('script-' + t, dbus_run_session,
        env: ['top_builddir=' + meson.project_build_root(),
              'top_srcdir=' + meson.project_source_root(),
              'srcdir=' + meson.current_source_dir()],
        args: [test_runner.full_path(),
               join_paths(meson.current_source_dir(), 'scripts', t + '.test')])
endforeach

subdir('unit')
