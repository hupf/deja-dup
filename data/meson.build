# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 4 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

# GOOGLE CUSTOM SCHEME (reverse dns)

google_client_id_parts = get_option('google_client_id').split('.')
google_client_id_parts_reversed = []
foreach part : google_client_id_parts
    google_client_id_parts_reversed = [part] + google_client_id_parts_reversed
endforeach
google_reversedns = '.'.join(google_client_id_parts_reversed)


# SHARED CONFIGURATION DATA

conf_data = configuration_data()
conf_data.set('appid', application_id)
conf_data.set('bindir', bindir)
conf_data.set('gettext', meson.project_name())
conf_data.set('gsettingspath', profile == '' ? 'deja-dup' : 'deja-dup-' + profile.to_lower())
conf_data.set('icon', application_id)
conf_data.set('pkglibexecdir', pkglibexecdir)
conf_data.set('profile', profile)
conf_data.set('scheme_google', google_reversedns)
conf_data.set('scheme_microsoft', 'msal' + get_option('microsoft_client_id'))
conf_data.set('version', meson.project_version())


# ICONS

install_data(
    join_paths('icons', '@0@.svg'.format(application_id)),
    install_dir: join_paths(datadir, 'icons', 'hicolor', 'scalable', 'apps'),
)

configure_file(
    input: join_paths('icons', 'org.gnome.DejaDup-symbolic.svg'),
    output: '@0@-symbolic.svg'.format(application_id),
    copy: true,
    install_dir: join_paths(datadir, 'icons', 'hicolor', 'symbolic', 'apps'),
)


# MAN PAGE

install_man('deja-dup.1')


# GSETTINGS

gschema = configure_file(
    input: 'app.gschema.xml.in',
    output: '@0@.gschema.xml'.format(application_id),
    configuration: conf_data,
    install_dir: join_paths(datadir, 'glib-2.0', 'schemas'),
)

custom_target(
    'gschema',
    build_by_default: true,
    output: 'gschemas.compiled',
    depend_files: [gschema],
    command: [glib_compile_schemas, meson.current_build_dir()],
)

test(
    'validate-gschema',
    glib_compile_schemas,
    args: ['--strict', '--dry-run', '--schema-file', gschema],
)

meson.add_devenv({'GSETTINGS_SCHEMA_DIR': meson.current_build_dir()})


# DBUS SERVICE

configure_file(
    input: 'app.service.in',
    output: '@0@.service'.format(application_id),
    configuration: conf_data,
    install_dir: join_paths(datadir, 'dbus-1', 'services'),
)


# MONITOR DESKTOP

monitor_desktop = configure_file(
    input: 'monitor.desktop.in',
    output: '@0@.Monitor.desktop'.format(application_id),
    configuration: conf_data,
    install_dir: join_paths(etcdir, 'xdg', 'autostart'),
)

if desktop_file_validate.found()
test(
    'validate-monitor-desktop',
    desktop_file_validate,
    args: [monitor_desktop],
)
endif


# MAIN DESKTOP

deja_dup_desktop_vars = configure_file(
    input: 'app.desktop.in',
    output: '@0@.desktop.in'.format(application_id),
    configuration: conf_data,
)

deja_dup_desktop = i18n.merge_file(
    input: deja_dup_desktop_vars,
    output: '@0@.desktop'.format(application_id),
    type: 'desktop',
    po_dir: join_paths(meson.project_source_root(), 'po'),
    install: true,
    install_dir: join_paths(datadir, 'applications'))

if desktop_file_validate.found()
test(
    'validate-desktop',
    desktop_file_validate,
    args: [deja_dup_desktop],
)
endif


# METAINFO

deja_dup_metainfo_vars = configure_file(
    input: 'app.metainfo.xml.in',
    output: '@0@.metainfo.xml.in'.format(application_id),
    configuration: conf_data,
)

deja_dup_metainfo = i18n.merge_file(
    input: deja_dup_metainfo_vars,
    output: '@0@.metainfo.xml'.format(application_id),
    type: 'xml',
    po_dir: join_paths(meson.project_source_root(), 'po'),
    install: true,
    install_dir: join_paths(datadir, 'metainfo'),
)

if appstreamcli.found()
test(
    'validate-appstream',
    appstreamcli,
    args: ['validate', '--no-net', deja_dup_metainfo],
)
elif appstream_util.found()
test(
    'validate-appstream',
    appstream_util,
    args: ['validate-relax', '--nonet', deja_dup_metainfo],
)
endif


# GRESOURCES

resources_xml = configure_file(
    input: 'resources.xml',
    output: 'resources.vars.xml',
    configuration: conf_data,
)

resources = gnome.compile_resources(
    application_id,
    resources_xml,
    source_dir: ['ui', meson.current_build_dir()],
    c_name: 'resources',
)


# POST INSTALL

gnome.post_install(
    glib_compile_schemas: true,
    gtk_update_icon_cache: true,
    update_desktop_database: true,
)
