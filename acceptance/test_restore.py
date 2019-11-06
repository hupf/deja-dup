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

import configparser
import os
import shutil

from dogtail.predicate import GenericPredicate
from gi.repository import GLib

from . import BaseTest


class RestoreTest(BaseTest):
    __test__ = False

    def setUp(self):
        super().setUp()

        basedir = os.path.realpath(os.path.dirname(__file__))
        configname = os.path.join(basedir, "config.ini")

        if os.path.exists(configname):
            self.config = configparser.ConfigParser()
            self.config.read(configname)
        else:
            self.config = None

        self.folder = self.get_config('default', 'folder',
                                      fallback='deja-dup-test', required=False)

    def get_config(self, section, option, fallback=None, required=True):
        if not self.config:
            if required:
                self.skipTest('No acceptance.ini found')
            return fallback
        return self.config.get(section, option, fallback=fallback)

    def walk_backup(self, app):
        window = app.window('Back Up')

        # Prepare for either initial backup or incremental
        def ready():
            try:
                return window.dead or window.findChild(
                    GenericPredicate(name='Forward'),
                    retry=False, requireResult=False
                )
            except GLib.GError:
                return True
        self.wait_for(ready, timeout=60)
        if window.dead:
            return

        window.child(roleName='radio button',
                     name='Allow restoring without a password').click()
        window.button('Forward').click()
        self.wait_for(lambda: window.dead, timeout=60)

    def walk_restore(self, app, password=None, error=False):
        window = app.window('Restore')

        shutil.rmtree(self.srcdir)

        window.button('Forward').click() # from where
        window.button('Forward').click() # when
        window.button('Forward').click() # to where
        window.button('Restore').click() # summary

        if password:
            window.child(roleName='text', label='Encryption password').text = password
            window.button('Forward').click()

        window.childNamed('Restoring…')

        title = 'Restore Failed' if error else 'Restore Finished'
        self.wait_for(
            lambda: window.findChild(GenericPredicate(name=title),
                                     retry=False, requireResult=False),
            timeout=60,
        )
        window.button('Close').click()

        test_file = open(self.srcdir + '/test.txt', 'r')
        assert test_file.read(None) == 'hello'

    def test_simple_cycle(self):
        app = self.cmd()

        app.button('Back Up Now…').click()
        self.walk_backup(app)

        app.button('Restore…').click()
        self.walk_restore(app)


class LocalRestoreTest(RestoreTest):
    __test__ = True

    def setUp(self):
        super().setUp()
        self.set_string('backend', 'local')
        self.set_string('folder', self.rootdir + '/dest', child='local')


class GoogleRestoreTest(RestoreTest):
    __test__ = True

    def setUp(self):
        super().setUp()
        if not int(self.get_config('google', 'enabled', fallback='0')):
            self.skipTest('Google not enabled')
        self.set_string('backend', 'google')
        self.set_string('folder', self.folder, child='google')


class RemoteRestoreTest(RestoreTest):
    __test__ = True

    def setUp(self):
        super().setUp()
        uri = self.get_config('remote', 'uri')
        self.set_string('backend', 'remote')
        self.set_string('uri', uri, child='remote')
        self.set_string('folder', self.folder, child='remote')
