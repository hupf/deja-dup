# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 2 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

i18n.gettext(
  meson.project_name(),
  args: ['--copyright-holder=Michael Terry'],
  preset: 'glib',
)

test(
  'po-linguas',
  find_program('./validate-linguas'),
  env: ['LC_ALL=C.UTF-8'],
  workdir: meson.current_source_dir()
)

test(
  'potfiles',
  find_program('./validate-potfiles'),
  env: ['LC_ALL=C.UTF-8'],
  workdir: meson.project_source_root(),
)
