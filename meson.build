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
    version: '34.4',
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
datadir = join_paths(get_option('prefix'), get_option('datadir'))
etcdir = get_option('sysconfdir')
libdir = join_paths(get_option('prefix'), get_option('libdir'))
libexecdir = join_paths(get_option('prefix'), get_option('libexecdir'))
localedir = join_paths(get_option('prefix'), get_option('localedir'))
pkgdatadir = join_paths(datadir, meson.project_name())
pkglibdir = join_paths(libdir, meson.project_name())
pkglibexecdir = join_paths(libexecdir, meson.project_name())
toolsdir = join_paths(pkglibexecdir, 'tools')

# Dependencies
gio_dep = dependency('gio-2.0')
gio_unix_dep = dependency('gio-unix-2.0')
gtk_dep = dependency('gtk+-3.0', version: '>= 3.10')
nautilus_dep = dependency('libnautilus-extension', required: false)
notify_dep = dependency('libnotify', version: '>= 0.7')
packagekit_dep = dependency('packagekit-glib2')
peas_dep = dependency('libpeas-1.0')
secret_dep = dependency('libsecret-1')

# Programs
appstream_util = find_program('appstream-util')
dbus_run_session = find_program('dbus-run-session')
desktop_file_validate = find_program('desktop-file-validate')
glib_compile_schemas = find_program('glib-compile-schemas')
msgfmt = find_program('msgfmt')

common_vflags = [
    '--pkg=config',
    '--pkg=posix',
    '--target-glib=2.34',
    '--vapidir', vapidir]
common_cflags = [
    '-w',
    '-DI_KNOW_THE_PACKAGEKIT_GLIB2_API_IS_SUBJECT_TO_CHANGE',
    '-DPACKAGE="@0@"'.format(meson.project_name()),
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    '-DVERSION="@0@"'.format(meson.project_version()),
    '-DLOCALE_DIR="@0@"'.format(localedir),
    '-DTHEME_DIR="@0@"'.format(join_paths(datadir, 'icons')),
    '-DPKG_LIBEXEC_DIR="@0@"'.format(pkglibexecdir)]

subdir('data')
subdir('libdeja')
subdir('deja-dup')
subdir('po')