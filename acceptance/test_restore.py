#!/usr/bin/env python3
# -*- Mode: Python; indent-tabs-mode: nil; tab-width: 4; coding: utf-8 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

import os
import shutil

from dogtail.predicate import GenericPredicate
from gi.repository import GLib

from . import BaseTest


class RestoreTest(BaseTest):
    __test__ = False

    def setUp(self):
        super().setUp()
        self.folder = self.get_config('default', 'folder',
                                      fallback='deja-dup-test', required=False)

    def walk_backup(self, app):
        window = app.window('Back Up')
        window.button('Forward').click()  # folders
        window.button('Forward').click()  # storage location

        # Prepare for either initial backup or incremental
        def ready():
            try:
                return window.dead or window.findChild(
                    GenericPredicate(name='Forward'),
                    retry=False, requireResult=False
                )
            except GLib.GError:
                return True
        self.wait_for(ready, timeout=120)
        if window.dead:
            return

        window.child(roleName='radio button',
                     name='Allow restoring without a password').click()
        window.button('Forward').click()
        self.wait_for(lambda: window.dead, timeout=60)

    def walk_restore(self, app, password=None, error=False):
        window = app.window('Restore From Where?')

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

        app.button('Create My First Backup').click()
        self.walk_backup(app)

        self.set_string('last-backup', '')  # to go back to welcome screen
        app.button('Restore From a Previous Backup').click()
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
