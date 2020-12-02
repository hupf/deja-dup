# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 4 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

conf_data = configuration_data()
conf_data.set('appid', application_id)
conf_data.set('bindir', bindir)
conf_data.set('gettext', meson.project_name())
conf_data.set('gsettingspath', profile == '' ? 'deja-dup' : 'deja-dup-' + profile.to_lower())
conf_data.set('icon', application_id)
conf_data.set('pkglibexecdir', pkglibexecdir)
conf_data.set('profile', profile)
conf_data.set('version', meson.project_version())

install_data(join_paths('icons', '@0@.svg'.format(application_id)),
    install_dir: join_paths(datadir, 'icons', 'hicolor', 'scalable', 'apps'))

configure_file(input: join_paths('icons', 'org.gnome.DejaDup-symbolic.svg'),
    output: '@0@-symbolic.svg'.format(application_id),
    copy: true,
    install_dir: join_paths(datadir, 'icons', 'hicolor', 'symbolic', 'apps'))

install_man('deja-dup.1')

gschema = configure_file(input: 'org.gnome.DejaDup.gschema.xml.in',
    output: '@0@.gschema.xml'.format(application_id),
    configuration: conf_data,
    install_dir: join_paths(datadir, 'glib-2.0', 'schemas'))

test('validate-gschema', glib_compile_schemas,
    args: ['--strict', '--dry-run', '--schema-file', gschema])

configure_file(input: 'org.gnome.DejaDup.service.in',
    output: '@0@.service'.format(application_id),
    configuration: conf_data,
    install_dir: join_paths(datadir, 'dbus-1', 'services'))

monitor_desktop = configure_file(input: 'org.gnome.DejaDup.Monitor.desktop.in',
    output: '@0@.Monitor.desktop'.format(application_id),
    configuration: conf_data,
    install_dir: join_paths(etcdir, 'xdg', 'autostart'))

test('validate-monitor-desktop', desktop_file_validate,
    args: [monitor_desktop])

vars = configure_file(input: 'org.gnome.DejaDup.desktop.in',
    output: 'org.gnome.DejaDup.vars.desktop.in',
    configuration: conf_data)
deja_dup_desktop = custom_target('org.gnome.DejaDup.desktop',
    input: vars,
    output: '@0@.desktop'.format(application_id),
    # List keywords due to https://savannah.gnu.org/support/?108887
    command: [msgfmt, '--desktop', '--keyword=Name', '--keyword=Comment', '--keyword=Keywords', '--template', '@INPUT@', '-d', podir, '-o', '@OUTPUT@'],
    install: true,
    install_dir: join_paths(datadir, 'applications'))

test('validate-desktop', desktop_file_validate,
    args: [deja_dup_desktop.full_path()])

vars = configure_file(input: 'org.gnome.DejaDup.appdata.xml.in',
    output: 'org.gnome.DejaDup.vars.appdata.xml.in',
    configuration: conf_data)
deja_dup_appdata = custom_target('org.gnome.DejaDup.appdata.xml',
    input: vars,
    output: '@0@.appdata.xml'.format(application_id),
    command: [msgfmt, '--xml', '--template', '@INPUT@', '-d', podir, '-o', '@OUTPUT@'],
    install: true,
    install_dir: join_paths(datadir, 'metainfo'))

test('validate-appstream', appstream_util,
    args: ['--nonet', 'validate-relax', deja_dup_appdata.full_path()])

resources_xml = configure_file(input: 'resources.xml',
    output: 'resources.vars.xml',
    configuration: conf_data)
resources = gnome.compile_resources(application_id, resources_xml,
    source_dir: ['ui'],
    c_name: 'resources')

meson.add_install_script('post-install.sh', datadir)
message('''You may need to recompile your gsettings schemas or regenerate
         your icon cache after installation.''')
