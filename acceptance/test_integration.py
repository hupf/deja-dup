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

import glob
import os

from dogtail import tree
from gi.repository import Gio, GLib, Gtk

from . import BaseTest


class IntegrationTest(BaseTest):
    def setUp(self):
        super().setUp()
        if os.environ['DD_MODE'] == 'dev':
            self.skipTest('dev mode')

    def test_translations(self):
        app = self.cmd(env='LANG=fr_FR.UTF-8')
        assert app.childNamed('Aucune sauvegarde récente.')

    def test_help(self):
        # Also test that help is translated by passing LANG
        app = self.cmd(env='LANG=fr_FR.UTF-8')
        app.childNamed('Menu').click()

        self.addCleanup(self.kill_bus, 'org.gnome.Yelp')
        app.button('Aide').click()

        yelp = tree.root.application('yelp')
        assert yelp.window('Aide à la sauvegarde')

    def test_desktop_file(self):
        # Find the file in system data dirs
        found = None
        datadirs = {d + '/applications' for d in GLib.get_system_data_dirs()}
        for datadir in datadirs:
            desktopfiles = glob.glob(datadir + '/*.desktop')
            for desktopfile in desktopfiles:
                f = open(desktopfile)
                if os.environ['DD_DESKTOP'] + '\n' in f.readlines():
                    found = Gio.DesktopAppInfo.new_from_filename(desktopfile)
                    break
            if found:
                break

        # Basic discoverability
        assert found
        assert not found.get_is_hidden()
        assert not found.get_nodisplay()

        # Test icon
        icon = found.get_icon()
        if isinstance(icon, Gio.ThemedIcon):
            name = icon.get_names()[0]
            assert Gtk.IconTheme.get_default().load_icon(name, 256, 0)
        else:
            assert icon.load(256, None)

        # Test launchability
        self.addCleanup(self.kill_bus, os.environ['DD_APPID'])
        found.launch(None, None)
        assert tree.root.application(os.environ['DD_APPID'])
