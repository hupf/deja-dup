#!/usr/bin/env python3
# -*- Mode: Python; indent-tabs-mode: nil; tab-width: 4; coding: utf-8 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

import glob
import os
import stat
from contextlib import contextmanager
from time import sleep
from unittest import expectedFailure

import ddt
from dogtail.predicate import GenericPredicate
from dogtail.rawinput import keyCombo
from gi.repository import GLib

from . import BaseTest, ResticMixin


@ddt.ddt
class BackupTest(BaseTest):
    def setUp(self):
        super().setUp()

        # Set up destination
        self.destdir = self.rootdir + "/dest"
        # os.mkdir(self.destdir)
        self.set_string("backend", "local")
        self.set_string("folder", self.destdir, child="local")

    @property
    def backup_files(self):
        try:
            return list(glob.iglob(self.destdir + "/**/*", recursive=True))
        except FileNotFoundError:
            return []

    @contextmanager
    def new_files(self, makes_new=True):
        initial = self.backup_files
        yield
        if makes_new:
            assert initial != self.backup_files
        else:
            assert initial == self.backup_files

    def test_from_main_window(self):
        app = self.cmd()
        app.button("Create Your First Backup").click()
        with self.new_files():
            self.walk_initial_backup(app)

        with self.new_files():
            app.button("Back Up Now").click()
            self.walk_incremental_backup(app)

    def test_from_commandline(self):
        app = self.cmd("--backup")
        with self.new_files():
            self.walk_initial_backup(app)

        with self.new_files():
            app = self.cmd("--backup")
            self.walk_incremental_backup(app)

    def test_from_monitor(self):
        self.set_boolean("periodic", True)

        self.monitor()
        keyCombo("<Super>v")
        sleep(1)
        keyCombo("Enter")
        app = self.get_app()

        # ensure window has focus (different modes either get rid of
        # notification drawer or not...)
        app.child(name="Folders to Back Up").click()

        with self.new_files():
            self.walk_initial_backup(app)

    def test_storage_error(self):
        self.addCleanup(os.chmod, self.rootdir, stat.S_IRWXU)
        os.chmod(self.rootdir, stat.S_IRUSR | stat.S_IXUSR)
        app = self.cmd("--backup")
        with self.new_files(False):
            window = app.window("Back Up")
            window.button("Forward").click()  # folders
            window.button("Forward").click()  # storage location
            window.childNamed("Backup Failed")
            window.button("Close").click()

    def test_encrypted(self):
        app = self.cmd("--backup")
        with self.new_files():
            self.walk_initial_backup(app, password="t")

        app = self.cmd("--backup")
        # Try once with the wrong password, just for fun
        # with self.new_files(False):
        self.walk_incremental_backup(app, password="nope", wait=False)
        with self.new_files():
            self.walk_incremental_backup(app, password="t")

    @ddt.data(True, False)
    def test_resume(self, initial):
        if not initial:
            app = self.cmd("--backup")
            self.walk_initial_backup(app, password="t")

        last_backup = self.get_string("last-backup")
        last_run = self.get_string("last-run")

        self.randomize_srcdir()
        app = self.cmd("--backup")
        if initial:
            window = self.walk_initial_backup(app, password="t", wait=False)
        else:
            window = self.walk_incremental_backup(app, password="t", wait=False)

        def mid_progress():
            bar = window.findChild(
                GenericPredicate(roleName="progress bar"),
                retry=False,
                requireResult=False,
            )
            return bar and bar.value >= 0.3

        with self.new_files():
            self.wait_for(mid_progress)
            sleep(0.2)  # give time for duplicity to write a .part file
            app.button("Resume Later").click()
            self.wait_for(lambda: window.dead)

        assert last_backup == self.get_string("last-backup")
        assert last_run != self.get_string("last-run")

        app = self.cmd("--backup")
        self.walk_incremental_backup(app, password="nope", wait=False)
        window = self.walk_incremental_backup(app, password="t", wait=False)
        self.did_resume = False

        def finish_progress():
            try:
                if window.dead:
                    return True
                bar = window.findChild(
                    GenericPredicate(roleName="progress bar"),
                    retry=False,
                    requireResult=False,
                )
                if bar and bar.value >= 0.3:
                    self.did_resume = True
                elif bar and not self.did_resume:
                    assert bar.value == 0
                return False
            except GLib.GError:
                return True

        with self.new_files():
            self.wait_for(finish_progress, timeout=120)
            assert window.dead

    def test_no_passphrase_change_on_full(self):
        """
        Ensure we check passphrases between full backups
        https://bugs.launchpad.net/duplicity/+bug/918489
        """
        self.set_int("full-backup-period", 0)

        app = self.cmd("--backup")
        self.walk_initial_backup(app, password="t")

        app = self.cmd("--backup")
        self.walk_incremental_backup(app, password="nope", wait=False)
        self.walk_incremental_backup(app, password="t")

    def test_nag_check(self):
        app = self.cmd("--backup")
        self.walk_initial_backup(app, password="t", remember=True)

        # One backup just to confirm we don't need password
        app = self.cmd("--backup")
        self.walk_incremental_backup(app)

        months_ago = GLib.DateTime.new_now_utc().add_months(-2).format_iso8601()
        self.set_string("nag-check", months_ago)

        app = self.cmd("--backup")
        # Wait for prompt (a little longer to appear than normal dogtail timeouts)
        self.wait_for(
            lambda: app.findChild(
                lambda x: x.roleName == "password text"
                and x.name == "Encryption password",
                requireResult=False,
                retry=False,
            )
        )
        self.walk_incremental_backup(
            app, password="nope", title="Restore Test", wait=False
        )
        self.walk_incremental_backup(
            app, password="t", title="Restore Test", wait=False
        )
        app.button("Close").click()  # we have a confirmation screen after nag

        assert self.get_string("nag-check") != months_ago


@ddt.ddt
class ResticBackupTest(ResticMixin, BackupTest):
    @expectedFailure  # it's too fast - need a better test
    @ddt.data(True, False)
    def test_resume(self, initial):
        super().test_resume(initial)

    @expectedFailure   # verify support isn't finished yet
    def test_nag_check(self):
        super().test_nag_check()
