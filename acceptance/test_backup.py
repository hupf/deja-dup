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

import os
import stat
from contextlib import contextmanager

import ddt
from dogtail.predicate import GenericPredicate
from gi.repository import GLib

from . import BaseTest


@ddt.ddt
class BackupTest(BaseTest):
    def setUp(self):
        super().setUp()

        # Set up destination
        self.destdir = self.rootdir + '/dest'
        os.mkdir(self.destdir)
        self.set_string('backend', 'local')
        self.set_string('folder', self.destdir, child='local')

    @property
    def backup_files(self):
        return os.listdir(self.destdir)

    @contextmanager
    def new_files(self, makes_new=True):
        initial = self.backup_files
        yield
        if makes_new:
            assert initial != self.backup_files
        else:
            assert initial == self.backup_files

    def test_from_preferences(self):
        app = self.cmd()
        app.button('Back Up Now…').click()
        with self.new_files():
            self.walk_initial_backup(app)

        app.button('Back Up Now…').click()
        with self.new_files():
            self.walk_incremental_backup(app)

    def test_from_commandline(self):
        app = self.cmd('--backup')
        with self.new_files():
            self.walk_initial_backup(app)

        app = self.cmd('--backup')
        with self.new_files():
            self.walk_incremental_backup(app)

    def test_from_monitor(self):
        self.set_boolean('periodic', True)

        app = self.monitor()
        with self.new_files():
            self.walk_initial_backup(app)

        with self.new_files():
            self.set_string('last-run', '')
            self.set_string('last-backup', '')
            self.wait_for(lambda: self.get_string('last-backup'))
            self.wait_for(lambda: not self.get_bus_pid(os.environ['DD_APPID']))

    def test_storage_error(self):
        os.chmod(self.destdir, stat.S_IRUSR | stat.S_IXUSR)
        app = self.cmd('--backup')
        with self.new_files(False):
            self.walk_initial_backup(app, error=True)

    def test_encrypted(self):
        app = self.cmd('--backup')
        with self.new_files():
            self.walk_initial_backup(app, password='t')

        app = self.cmd('--backup')
        # Try once with the wrong password, just for fun
        with self.new_files(False):
            self.walk_incremental_backup(app, password='nope', wait=False)
        with self.new_files():
            self.walk_incremental_backup(app, password='t')

    @ddt.data(True, False)
    def test_resume(self, initial):
        if not initial:
            app = self.cmd('--backup')
            self.walk_initial_backup(app, password='t')

        self.randomize_srcdir()
        app = self.cmd('--backup')
        window = app.window('Back Up')
        if initial:
            self.walk_initial_backup(app, password='t', wait=False)
        else:
            self.walk_incremental_backup(app, password='t', wait=False)
        def mid_progress():
            bar = window.findChild(
                GenericPredicate(roleName='progress bar'),
                retry=False, requireResult=False
            )
            return bar and bar.value > 0.6
        with self.new_files():
            self.wait_for(mid_progress)
            app.button('Resume Later').click()
            self.wait_for(lambda: window.dead)

        app = self.cmd('--backup')
        window = app.window('Back Up')
        if initial:
            # This flow is a little janky. So we can't 100% detect that there
            # is a resumable backup sitting on backend. So we still give the
            # first-time-backup password prompt. And then accept whatever the
            # password is, to use when we call duplicity.
            # Then... duplicity tries to decrypt metadata and can't, so we
            # prompt to confirm password. Then when re-doing the backup with
            # the right password, we do the first-time-backup password screen
            # again. While annoying, at least we avoid duplicity bugs around
            # password changes midstream.
            if os.environ.get('DD_DEBIAN_DUPLICITY') != '1':
                # Debian has a bug preventing us from fixing bad passwords here
                # https://bugs.debian.org/944512
                # So don't bother testing it in this case, until they fix that
                self.walk_initial_backup(app, password='nope', wait=False)
                self.walk_incremental_backup(app, password='t', wait=False)
            else:
                self.walk_initial_backup(app, password='t', wait=False)
        else:
            if os.environ.get('DD_DEBIAN_DUPLICITY') != '1':
                self.walk_incremental_backup(app, password='nope', wait=False)
                self.walk_incremental_backup(app, password='t', wait=False)
            else:
                self.walk_incremental_backup(app, password='t', wait=False)
        self.did_resume = False
        def finish_progress():
            try:
                if window.dead:
                    return True
                bar = window.findChild(
                    GenericPredicate(roleName='progress bar'),
                    retry=False, requireResult=False
                )
                if bar and bar.value >= 0.3:
                    self.did_resume = True
                elif bar and not self.did_resume:
                    assert bar.value == 0
                return False
            except GLib.GError:
                return True
        old_files = self.backup_files
        with self.new_files():
            self.wait_for(finish_progress, timeout=60)
            assert window.dead
        assert set(self.backup_files) >= set(old_files)

    def test_no_passphrase_change_on_full(self):
        """
        Ensure we check passphrases between full backups
        https://bugs.launchpad.net/duplicity/+bug/918489
        """
        self.set_int('full-backup-period', 0)

        app = self.cmd('--backup')
        self.walk_initial_backup(app, password='t')

        app = self.cmd('--backup')
        self.walk_incremental_backup(app, password='nope', wait=False)
        self.walk_incremental_backup(app, password='t')
