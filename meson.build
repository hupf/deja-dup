# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 4 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

project('deja-dup', ['vala', 'c'],
    version: '41.2',
    license: 'GPL-3.0-or-later',
    meson_version: '>= 0.47')

gnome = import('gnome')
i18n = import('i18n')
 
# Source paths
podir = join_paths(meson.current_source_dir(), 'po')
vapidir = join_paths(meson.current_source_dir(), 'vapi')

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
gdk_x11_dep = dependency('gdk-x11-3.0', required: false)
gio_dep = dependency('gio-2.0', version: '>= 2.64')
gio_unix_dep = dependency('gio-unix-2.0')
gtk_dep = dependency('gtk+-3.0', version: '>= 3.22')
handy_dep = dependency('libhandy-0.0', version: '>= 0.0.10')
json_dep = dependency('json-glib-1.0', version: '>= 1.2')
packagekit_dep = dependency('packagekit-glib2', version: '>=0.6.5', required: false)
secret_dep = dependency('libsecret-1', version: '>= 0.18.6')
soup_dep = dependency('libsoup-2.4', version: '>= 2.48')

# libgpg-error doesn't ship a pkg-config file
gpgerror_libs = run_command('gpg-error-config', '--libs').stdout().strip()
gpgerror_dep = declare_dependency(link_args: gpgerror_libs.split())

# Programs
appstream_util = find_program('appstream-util', required: false)
dbus_run_session = find_program('dbus-run-session', required: false)
desktop_file_validate = find_program('desktop-file-validate', required: false)
glib_compile_schemas = find_program('glib-compile-schemas')
msgfmt = find_program('msgfmt')

# Profile support
profile = get_option('profile')
application_id = 'org.gnome.DejaDup@0@'.format(profile)
if profile != ''
    message('Using profile @0@.'.format(profile))
else
    message('Using default profile.')
endif

common_vflags = [
    '--pkg=config',
    '--pkg=posix',
    '--target-glib=2.64',
    '--vapidir', vapidir,
]
common_cflags = [
    '-DHANDY_USE_UNSTABLE_API',
    '-DI_KNOW_THE_PACKAGEKIT_GLIB2_API_IS_SUBJECT_TO_CHANGE',
    '-DDUPLICITY_PACKAGES="@0@"'.format(get_option('duplicity_pkgs')),
    '-DGVFS_PACKAGES="@0@"'.format(get_option('gvfs_pkgs')),
    '-DPYDRIVE_PACKAGES="@0@"'.format(get_option('pydrive_pkgs')),
    '-DGOOGLE_CLIENT_ID="@0@"'.format(get_option('google_client_id')),
    '-DPACKAGE="@0@"'.format(meson.project_name()),
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    '-DVERSION="@0@"'.format(meson.project_version()),
    '-DPROFILE="@0@"'.format(profile),
    '-DAPPLICATION_ID="@0@"'.format(application_id),
    '-DICON_NAME="@0@"'.format(application_id),
    '-DLOCALE_DIR="@0@"'.format(localedir),
    '-DPKG_LIBEXEC_DIR="@0@"'.format(pkglibexecdir)]

if gdk_x11_dep.found()
common_vflags += ['--define=HAS_X11']
endif

if packagekit_dep.found()
common_vflags += ['--define=HAS_PACKAGEKIT']
endif

subdir('data')
subdir('help')
subdir('libdeja')
subdir('monitor')
subdir('deja-dup')
subdir('po')
