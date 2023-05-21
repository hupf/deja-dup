# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 2 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

project(
  'deja-dup',
  'vala',
  license: 'GPL-3.0-or-later',
  meson_version: '>= 0.59',
  version: '44.3',
)

gnome = import('gnome')
i18n = import('i18n')
vala = meson.get_compiler('vala')

# Install paths
prefix = get_option('prefix')
bindir = join_paths(prefix, get_option('bindir'))
datadir = join_paths(prefix, get_option('datadir'))
etcdir = get_option('sysconfdir')
libdir = join_paths(prefix, get_option('libdir'))
libexecdir = join_paths(prefix, get_option('libexecdir'))
localedir = join_paths(prefix, get_option('localedir'))
pkgdatadir = join_paths(datadir, meson.project_name())
pkglibdir = join_paths(libdir, meson.project_name())
pkglibexecdir = join_paths(libexecdir, meson.project_name())

# Dependencies
adwaita_dep = dependency('libadwaita-1', version: '>= 1.2')
gio_dep = dependency('gio-2.0', version: '>= 2.70')
gio_unix_dep = dependency('gio-unix-2.0')
gpg_error_dep = dependency('gpg-error', version: '>= 1.33')
gtk_dep = dependency('gtk4', version: '>= 4.6')
gtk_wayland_dep = dependency('gtk4-wayland', required: false)
gtk_x11_dep = dependency('gtk4-x11', required: false)
json_dep = dependency('json-glib-1.0', version: '>= 1.2')
packagekit_dep = dependency('packagekit-glib2', version: '>= 1.2', required: get_option('packagekit'))
secret_dep = dependency('libsecret-1', version: '>= 0.18.6')
soup_dep = dependency('libsoup-3.0', version: '>= 3.0')

# Programs
appstreamcli = find_program('appstreamcli', required: false)
appstream_util = find_program('appstream-util', required: false)
dbus_run_session = find_program('dbus-run-session', required: false)
desktop_file_validate = find_program('desktop-file-validate', required: false)
glib_compile_schemas = find_program('glib-compile-schemas')

# Profile support
profile = get_option('profile')
application_id = f'org.gnome.DejaDup@profile@'
if profile != ''
  message(f'Using profile @profile@.')
else
  message('Using default profile.')
endif

add_project_arguments(
  '--pkg=config',
  '--pkg=posix',
  '--target-glib=2.70',
  '--vapidir', join_paths(meson.project_source_root(), 'vapi'),
  language: 'vala',
)

add_project_arguments(
  '-DAPPLICATION_ID="@0@"'.format(application_id),
  '-DBORG_COMMAND="@0@"'.format(get_option('borg_command')),
  '-DBORG_PACKAGES="@0@"'.format(get_option('borg_pkgs')),
  '-DDUPLICITY_COMMAND="@0@"'.format(get_option('duplicity_command')),
  '-DDUPLICITY_PACKAGES="@0@"'.format(get_option('duplicity_pkgs')),
  '-DG_LOG_DOMAIN="deja-dup"',
  '-DG_LOG_USE_STRUCTURED',
  '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
  '-DGOOGLE_CLIENT_ID="@0@"'.format(get_option('google_client_id')),
  '-DGVFS_PACKAGES="@0@"'.format(get_option('gvfs_pkgs')),
  '-DICON_NAME="@0@"'.format(application_id),
  '-DLOCALE_DIR="@0@"'.format(localedir),
  '-DMICROSOFT_CLIENT_ID="@0@"'.format(get_option('microsoft_client_id')),
  '-DPACKAGE="@0@"'.format(meson.project_name()),
  '-DPKG_LIBEXEC_DIR="@0@"'.format(pkglibexecdir),
  '-DPROFILE="@0@"'.format(profile),
  '-DPYDRIVE_PACKAGES="@0@"'.format(get_option('pydrive_pkgs')),
  '-DRCLONE_COMMAND="@0@"'.format(get_option('rclone_command')),
  '-DRCLONE_PACKAGES="@0@"'.format(get_option('rclone_pkgs')),
  '-DREQUESTS_OAUTHLIB_PACKAGES="@0@"'.format(get_option('requests_oauthlib_pkgs')),
  '-DRESTIC_COMMAND="@0@"'.format(get_option('restic_command')),
  '-DRESTIC_PACKAGES="@0@"'.format(get_option('restic_pkgs')),
  '-DVERSION="@0@"'.format(meson.project_version()),
  language: 'c',
)

if gtk_wayland_dep.found()
  add_project_arguments('--define=HAS_WAYLAND', language: 'vala')
endif

if gtk_x11_dep.found()
  add_project_arguments('--define=HAS_X11', language: 'vala')
endif

if packagekit_dep.found()
  add_project_arguments('--define=HAS_PACKAGEKIT', language: 'vala')
endif

if get_option('enable_borg')
  add_project_arguments('--define=ENABLE_BORG', language: 'vala')
endif

if get_option('enable_restic')
  add_project_arguments('--define=ENABLE_RESTIC', language: 'vala')
endif

add_test_setup(
  'default',
  env: {
    'DEJA_DUP_LANGUAGE': 'en',
    'G_ENABLE_DIAGNOSTIC': '0',
    'GSETTINGS_BACKEND': 'memory',
    'GSETTINGS_SCHEMA_DIR': meson.project_build_root() + '/data',
    'LC_ALL': 'C.UTF-8',
  },
  is_default: true,
)

meson.add_devenv({
  'G_ENABLE_DIAGNOSTIC': '1',
  'G_MESSAGES_DEBUG': 'deja-dup',

  # Else we'll use the gtk backend, which won't believe we're installed
  'GNOTIFICATION_BACKEND': 'freedesktop',
  'DEJA_DUP_NOTIFICATION_ICON': meson.project_source_root() + '/data/icons/org.gnome.DejaDup-symbolic.svg',
})

subdir('data')
subdir('help')
subdir('libdeja')
subdir('monitor')
subdir('app')
subdir('po')
