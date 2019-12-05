# -*- Mode: Meson; indent-tabs-mode: nil; tab-width: 4 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

i18n.gettext(
    meson.project_name(),
    preset: 'glib',
    args: ['--copyright-holder=Michael Terry'],
)

validate_po_linguas = find_program('./validate-linguas')
test('po-linguas', validate_po_linguas,
    env: ['LC_ALL=C.UTF-8'],
    workdir: meson.current_source_dir())
