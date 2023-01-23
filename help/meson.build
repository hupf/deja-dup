# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 2 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

gnome.yelp(
  meson.project_name(),
  sources: [
    'contribute.page',
    'index.page',
    'prefs.page',
    'restore-full.page',
    'restore-revert.page',
    'restore-worst-case.page',
    'support.page',
  ],
  media: ['figures/DejaDup.svg']
)

test(
  'help-linguas',
  find_program('./validate-linguas'),
  env: ['LC_ALL=C.UTF-8'],
  workdir: meson.current_source_dir(),
)
