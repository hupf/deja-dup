# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 4 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

gnome.yelp(meson.project_name(),
    sources: ['backup-auto.page',
              'backup-first.page',
              'contribute.page',
              'credits.page',
              'index.page',
              'license.page',
              'prefs.page',
              'restore-full.page',
              'restore-lost.page',
              'restore-revert.page',
              'restore-worst-case.page',
              'support.page'],
    symlink_media: true)

validate_help_linguas = find_program('./validate-linguas')
test('help-linguas', validate_help_linguas,
    env: ['LC_ALL=C.UTF-8'],
    workdir: meson.current_source_dir())
