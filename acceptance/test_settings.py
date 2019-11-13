#!/usr/bin/env python3
# -*- Mode: Python; indent-tabs-mode: nil; tab-width: 4; coding: utf-8 -*-
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

from gi.repository import GLib

from . import BaseTest


class PreferencesTest(BaseTest):
    def setUp(self):
        super().setUp()
        self.app = self.cmd()

    def test_scheduling(self):
        self.app.child(name='Scheduling').click()

        # Periodic to settings
        periodic = self.app.child(label='Automatic backup')
        periodic_header = self.app.child(name='Automatic backup')
        self.assertFalse(periodic.checked)
        self.assertFalse(periodic_header.checked)
        periodic.click()
        self.assertTrue(self.get_boolean('periodic'))

        # Periodic from settings
        self.assertTrue(periodic.checked)
        self.assertTrue(periodic_header.checked)
        self.set_boolean('periodic', False)
        self.assertFalse(self.refresh(periodic).checked)
        self.assertFalse(self.refresh(periodic_header).checked)
        self.set_boolean('periodic', True)
        self.assertTrue(self.refresh(periodic).checked)
        self.assertTrue(self.refresh(periodic_header).checked)

        # Period to settings
        period = self.app.child(label='Every').child(roleName='combo box')
        period.click()
        period.child(roleName='menu item', name='Day').click()
        self.assertEqual(self.get_int('periodic-period'), 1)

        period.click()
        period.child(roleName='menu item', name='Week').click()
        self.assertEqual(self.get_int('periodic-period'), 7)

        # Period from settings
        self.set_int('periodic-period', 10)
        self.assertEqual(self.refresh(period).combovalue, '10 days')

        # Delete After to settings
        delete = self.app.child(label='Keep').child(roleName='combo box')
        delete.click()
        delete.child(roleName='menu item', name='At least a year').click()
        self.assertEqual(self.get_int('delete-after'), 365)

        delete.click()
        delete.child(roleName='menu item', name='Forever').click()
        self.assertEqual(self.get_int('delete-after'), 0)

        # Delete After from settings
        self.set_int('delete-after', 12)
        self.assertEqual(self.refresh(delete).combovalue, 'At least 12 days')

    def table_names(self, table):
        table = self.refresh(table)
        objs = table.findChildren(lambda x: x.roleName == 'table cell')
        return [x.name for x in objs]

    def assert_inclusion_table(self, category, widget, key):
        self.app.child(name=category).click()
        table = self.app.child(name=widget)

        user = GLib.get_user_name()
        home = GLib.get_home_dir()
        homename = home.rsplit('/', 1)[-1]

        # Test display names
        self.set_strv(key, [
            '$DESKTOP',
            '$DOCUMENTS/path',
            '$DOWNLOAD',
            '$MUSIC/path',
            '$PICTURES',
            '$PUBLIC_SHARE',
            '$TEMPLATES/path',
            '$VIDEOS',
            '$HOME',
            '$TRASH',
            'relative/$USER/path',
            '/absolute/$USER/path',
        ])
        self.assertListEqual(self.table_names(table), [
            '~/Desktop',
            '~/Documents/path',
            '~/Downloads',
            '~/Music/path',
            '~/Pictures',
            'Home ({})'.format(homename),
            '~/Templates/path',
            '~/Videos',
            'Home ({})'.format(homename),
            'Trash',
            '~/relative/{}/path'.format(user),
            '/absolute/{}/path'.format(user),
        ])

        # Remove most
        rows = table.findChildren(lambda x: x.roleName == 'table cell')[1:]
        for row in rows:
            row.select()
        remove = self.app.child(name='Remove')
        remove.click()
        self.assertListEqual(self.table_names(table), ['~/Desktop'])
        self.assertEqual(self.get_strv(key), [home + '/Desktop'])

        # Add one
        add = self.app.child(name='Add')
        add.click()
        dlg = self.app.child(roleName='file chooser')
        dlg.child(name='Documents').click()
        dlg.child(name='Add').click()
        self.assertListEqual(self.table_names(table), ['~/Desktop', '~/Documents'])
        self.assertEqual(self.get_strv(key), [home + '/Desktop', home + '/Documents'])

    def test_includes(self):
        self.assert_inclusion_table('Folders to save', 'IncludeList',
                                    'include-list')

    def test_excludes(self):
        self.assert_inclusion_table('Folders to ignore', 'ExcludeList',
                                    'exclude-list')
