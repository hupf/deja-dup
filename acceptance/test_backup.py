#!/usr/bin/env python3
# -*- Mode: Python; indent-tabs-mode: nil; tab-width: 4; coding: utf-8 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

import os
import stat
from contextlib import contextmanager
from time import sleep

import ddt
from dogtail.predicate import GenericPredicate
from dogtail.rawinput import keyCombo
from gi.repository import GLib

from . import BaseTest


@ddt.ddt
class BackupTest(BaseTest):
    def setUp(self):
        super().setUp()

        # Set up destination
        self.destdir = self.rootdir + "/dest"
        os.mkdir(self.destdir)
        self.set_string("backend", "local")
        self.set_string("folder", self.destdir, child="local")

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

    def test_from_main_window(self):
        app = self.cmd()
        app.button("Create My First Backup").click()
        with self.new_files():
            self.walk_initial_backup(app)

        app.button("Back Up Now").click()
        with self.new_files():
            self.walk_incremental_backup(app)

    def test_from_commandline(self):
        app = self.cmd("--backup")
        with self.new_files():
            self.walk_initial_backup(app)

        app = self.cmd("--backup")
        with self.new_files():
            self.walk_incremental_backup(app)

    def test_from_monitor(self):
        self.set_boolean("periodic", True)

        self.monitor()
        keyCombo("<Super>v")
        sleep(1)
        keyCombo("Enter")
        keyCombo("<Super>v")
        app = self.get_app()

        with self.new_files():
            self.walk_initial_backup(app)

        with self.new_files():
            month_ago = GLib.DateTime.new_now_utc().add_months(-1).format_iso8601()
            self.set_string("last-backup", month_ago)
            self.wait_for(lambda: self.get_string("last-backup") != month_ago)
            self.wait_for(lambda: not self.get_bus_pid(os.environ["DD_APPID"]))

    def test_storage_error(self):
        os.chmod(self.destdir, stat.S_IRUSR | stat.S_IXUSR)
        app = self.cmd("--backup")
        with self.new_files(False):
            self.walk_initial_backup(app, error=True)

    def test_encrypted(self):
        app = self.cmd("--backup")
        with self.new_files():
            self.walk_initial_backup(app, password="t")

        app = self.cmd("--backup")
        # Try once with the wrong password, just for fun
        with self.new_files(False):
            self.walk_incremental_backup(app, password="nope", wait=False)
        with self.new_files():
            self.walk_incremental_backup(app, password="t")

    @ddt.data(True, False)
    def test_resume(self, initial):
        if not initial:
            app = self.cmd("--backup")
            self.walk_initial_backup(app, password="t")

        self.randomize_srcdir()
        app = self.cmd("--backup")
        if initial:
            window = app.window("Back Up")
            self.walk_initial_backup(app, password="t", wait=False)
        else:
            window = app.window("Backing Up…")
            self.walk_incremental_backup(app, password="t", wait=False)

        def mid_progress():
            bar = window.findChild(
                GenericPredicate(roleName="progress bar"),
                retry=False,
                requireResult=False,
            )
            return bar and bar.value > 0.6

        with self.new_files():
            self.wait_for(mid_progress)
            app.button("Resume Later").click()
            self.wait_for(lambda: window.dead)

        app = self.cmd("--backup")
        window = app.window("Backing Up…")
        self.walk_incremental_backup(app, password="nope", wait=False)
        self.walk_incremental_backup(app, password="t", wait=False)
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

        old_files = self.backup_files
        with self.new_files():
            self.wait_for(finish_progress, timeout=120)
            assert window.dead
        assert set(self.backup_files) >= set(old_files)

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
