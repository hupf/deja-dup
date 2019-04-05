# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 4 -*-
#
# This file is part of Déjà Dup.
# For copyright information, see AUTHORS.
#
# Déjà Dup is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Déjà Dup is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Déjà Dup.  If not, see <http://www.gnu.org/licenses/>.

project('deja-dup', ['vala', 'c'],
    version: '39.1',
    license: 'GPLv3+',
    default_options: [
        'warning_level=1',
        'buildtype=debugoptimized',
    ],
    meson_version: '>= 0.38')

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
gio_dep = dependency('gio-2.0', version: '>= 2.46')
gio_unix_dep = dependency('gio-unix-2.0')
goa_dep = dependency('goa-1.0', version: '>= 3.8.0')
gtk_dep = dependency('gtk+-3.0', version: '>= 3.22')
json_dep = dependency('json-glib-1.0', version: '>= 1.2')
nautilus_dep = dependency('libnautilus-extension', required: false)
packagekit_dep = dependency('packagekit-glib2', version: '>=0.6.5', required: false)
secret_dep = dependency('libsecret-1', version: '>= 0.18.6')
soup_dep = dependency('libsoup-2.4', version: '>= 2.48')

# libgpg-error doesn't ship a pkg-config file
gpgerror_libs = run_command('gpg-error-config', '--libs').stdout().strip()
gpgerror_dep = declare_dependency(link_args: gpgerror_libs.split())

# Programs
appstream_util = find_program('appstream-util')
dbus_run_session = find_program('dbus-run-session')
desktop_file_validate = find_program('desktop-file-validate')
glib_compile_schemas = find_program('glib-compile-schemas')
msgfmt = find_program('msgfmt')

# Profile support
profile = get_option('profile')
application_id = 'org.gnome.DejaDup@0@'.format(profile)
if profile != ''
    message('Using profile @0@.'.format(profile))
    name_suffix = ' (@0@)'.format(profile)
else
    message('Using default profile.')
    name_suffix = ''
endif

common_vflags = [
    '--pkg=config',
    '--pkg=posix',
    '--target-glib=2.46',
    '--vapidir', vapidir,
]
common_cflags = [
    '-w',
    '-DGOA_API_IS_SUBJECT_TO_CHANGE',
    '-DGOA_BACKEND_API_IS_SUBJECT_TO_CHANGE',
    '-DI_KNOW_THE_PACKAGEKIT_GLIB2_API_IS_SUBJECT_TO_CHANGE',
    '-DDUPLICITY_PACKAGES="@0@"'.format(get_option('duplicity_pkgs')),
    '-DGVFS_PACKAGES="@0@"'.format(get_option('gvfs_pkgs')),
    '-DBOTO_PACKAGES="@0@"'.format(get_option('boto_pkgs')),
    '-DCLOUDFILES_PACKAGES="@0@"'.format(get_option('cloudfiles_pkgs')),
    '-DPYDRIVE_PACKAGES="@0@"'.format(get_option('pydrive_pkgs')),
    '-DSWIFTCLIENT_PACKAGES="@0@"'.format(get_option('swiftclient_pkgs')),
    '-DGOOGLE_CLIENT_ID="@0@"'.format(get_option('google_client_id')),
    '-DPACKAGE="@0@"'.format(meson.project_name()),
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    '-DVERSION="@0@"'.format(meson.project_version()),
    '-DPROFILE="@0@"'.format(profile),
    '-DNAME_SUFFIX="@0@"'.format(name_suffix),
    '-DAPPLICATION_ID="@0@"'.format(application_id),
    '-DICON_NAME="@0@"'.format(application_id),
    '-DLOCALE_DIR="@0@"'.format(localedir),
    '-DTHEME_DIR="@0@"'.format(join_paths(datadir, 'icons')),
    '-DPKG_LIBEXEC_DIR="@0@"'.format(pkglibexecdir)]

if packagekit_dep.found()
common_vflags += ['--define=HAS_PACKAGEKIT']
endif

subdir('data')
subdir('help')
subdir('libdeja')
subdir('deja-dup')
subdir('po')
