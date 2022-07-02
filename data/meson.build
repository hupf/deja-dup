# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 2 -*-
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

conf_data = configuration_data({
  'appid': application_id,
  'bindir': bindir,
  'gettext': meson.project_name(),
  'gsettingspath': profile == '' ? 'deja-dup' : 'deja-dup-' + profile.to_lower(),
  'icon': application_id,
  'pkglibexecdir': pkglibexecdir,
  'profile': profile,
  'scheme_google': google_reversedns,
  'scheme_microsoft': 'msal' + get_option('microsoft_client_id'),
  'version': meson.project_version(),
})


# ICONS

install_data(
  join_paths('icons', f'@application_id@.svg'),
  install_dir: join_paths(datadir, 'icons', 'hicolor', 'scalable', 'apps'),
)

configure_file(
  copy: true,
  input: join_paths('icons', 'org.gnome.DejaDup-symbolic.svg'),
  install_dir: join_paths(datadir, 'icons', 'hicolor', 'symbolic', 'apps'),
  output: f'@application_id@-symbolic.svg',
)


# MAN PAGE

install_man('deja-dup.1')


# GSETTINGS

gschema = configure_file(
  configuration: conf_data,
  input: 'app.gschema.xml.in',
  install_dir: join_paths(datadir, 'glib-2.0', 'schemas'),
  output: f'@application_id@.gschema.xml',
)

custom_target(
  'gschema',
  build_by_default: true,
  command: [glib_compile_schemas, meson.current_build_dir()],
  depend_files: [gschema],
  output: 'gschemas.compiled',
)

test(
  'validate-gschema',
  glib_compile_schemas,
  args: ['--strict', '--dry-run', '--schema-file', gschema],
)

meson.add_devenv({'GSETTINGS_SCHEMA_DIR': meson.current_build_dir()})


# DBUS SERVICE

configure_file(
  configuration: conf_data,
  input: 'app.service.in',
  install_dir: join_paths(datadir, 'dbus-1', 'services'),
  output: f'@application_id@.service',
)


# MONITOR DESKTOP

monitor_desktop = configure_file(
  configuration: conf_data,
  input: 'monitor.desktop.in',
  install_dir: join_paths(etcdir, 'xdg', 'autostart'),
  output: f'@application_id@.Monitor.desktop',
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
  configuration: conf_data,
  input: 'app.desktop.in',
  output: f'@application_id@.desktop.in',
)

deja_dup_desktop = i18n.merge_file(
  input: deja_dup_desktop_vars,
  install: true,
  install_dir: join_paths(datadir, 'applications'),
  output: f'@application_id@.desktop',
  po_dir: join_paths(meson.project_source_root(), 'po'),
  type: 'desktop',
)

if desktop_file_validate.found()
  test(
    'validate-desktop',
    desktop_file_validate,
    args: [deja_dup_desktop],
  )
endif


# METAINFO

deja_dup_metainfo_vars = configure_file(
  configuration: conf_data,
  input: 'app.metainfo.xml.in',
  output: f'@application_id@.metainfo.xml.in',
)

deja_dup_metainfo = i18n.merge_file(
  input: deja_dup_metainfo_vars,
  install: true,
  install_dir: join_paths(datadir, 'metainfo'),
  output: f'@application_id@.metainfo.xml',
  po_dir: join_paths(meson.project_source_root(), 'po'),
  type: 'xml',
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
  configuration: conf_data,
  input: 'resources.xml',
  output: 'resources.vars.xml',
)

resources = gnome.compile_resources(
  application_id,
  resources_xml,
  c_name: 'resources',
  source_dir: ['ui', meson.current_build_dir()],
)


# POST INSTALL

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)
