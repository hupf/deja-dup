#!/usr/bin/env python3
# -*- Mode: Python; indent-tabs-mode: nil; tab-width: 4; coding: utf-8 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

import os
import shutil
from datetime import datetime

from dogtail.predicate import GenericPredicate
from gi.repository import GLib

from . import BaseTest, ResticMixin


class RestoreTest(BaseTest):
    __test__ = False

    def setUp(self):
        super().setUp()
        self.folder = self.get_config(
            "default", "folder", fallback="deja-dup-test", required=False
        )
        self.filename = self.srcdir + "/[t](e?s*)' t.\"txt"
        self.contents = datetime.now().isoformat()
        open(self.filename, "w").write(self.contents)

    def walk_backup(self, app):
        window = app.window("Back Up")
        window.button("Forward").click()  # folders
        window.button("Forward").click()  # storage location

        window.child(roleName="text", label="Encryption password").text = "test-restore"

        # Confirm password if we are doing an initial backup
        confirm = window.findChild(
            GenericPredicate(roleName="text", label="Confirm password"),
            retry=False,
            requireResult=False,
        )
        if confirm:
            confirm.text = "test-restore"

        window.button("Forward").click()
        self.wait_for(lambda: window.dead, timeout=300)

    def walk_restore(self, app):
        shutil.rmtree(self.srcdir)

        window = app.window("Restore From Where?")
        window.button("Search").click()  # from where
        search = app.child(roleName="push button", name="Search")

        # Switched to restore pane. Enter password if using restic, which
        # unlike duplicity, does not keep unencrypted metadata locally cached.
        if self.restic:
            self.enter_browser_password(app, "test-restore")

        # Now select all.
        self.wait_for(lambda: search.sensitive)
        app.childNamed("Main Menu").click()
        app.childNamed("Select All").click()

        # And start restore
        app.button("Restore").click()
        window = app.window("Restore to Where?")
        window.button("Restore").click()  # to where

        window.child(roleName="text", label="Encryption password").text = "test-restore"
        window.button("Forward").click()

        title = "Restore Finished"
        self.wait_for(
            lambda: window.findChild(
                GenericPredicate(name=title), retry=False, requireResult=False
            ),
            timeout=60,
        )
        window.button("Close").click()

        test_file = open(self.filename, "r")
        assert test_file.read(None) == self.contents

    def test_simple_cycle(self):
        app = self.cmd()

        app.button("Create Your First Backup").click()
        self.walk_backup(app)

        self.set_string("last-run", "")  # to go back to welcome screen
        app.button("Restore From a Previous Backup").click()
        self.walk_restore(app)


class LocalRestoreTest(RestoreTest):
    __test__ = True

    def setUp(self):
        super().setUp()
        self.set_string("backend", "local")
        self.set_string("folder", self.rootdir + "/dest", child="local")


class ResticLocalRestoreTest(ResticMixin, LocalRestoreTest):
    def setUp(self):
        super().setUp()
        self.set_string("folder", self.rootdir + "/dest-restic", child="local")


class GoogleRestoreTest(RestoreTest):
    __test__ = True

    def setUp(self):
        super().setUp()
        if not int(self.get_config("google", "enabled", fallback="0")):
            self.skipTest("Google not enabled")
        self.set_string("backend", "google")
        self.set_string("folder", self.folder, child="google")


class ResticGoogleRestoreTest(ResticMixin, GoogleRestoreTest):
    def setUp(self):
        super().setUp()
        self.set_string("folder", self.folder + "-restic", child="google")


class MicrosoftRestoreTest(RestoreTest):
    __test__ = True

    def setUp(self):
        super().setUp()
        if not int(self.get_config("microsoft", "enabled", fallback="0")):
            self.skipTest("Microsoft not enabled")
        self.set_string("backend", "microsoft")
        self.set_string("folder", self.folder, child="microsoft")


class ResticMicrosoftRestoreTest(ResticMixin, MicrosoftRestoreTest):
    def setUp(self):
        super().setUp()
        self.set_string("folder", self.folder + "-restic", child="microsoft")


class RemoteRestoreTest(RestoreTest):
    __test__ = True

    def setUp(self):
        super().setUp()
        uri = self.get_config("remote", "uri")
        self.set_string("backend", "remote")
        self.set_string("uri", uri, child="remote")
        self.set_string("folder", self.folder, child="remote")


class ResticRemoteRestoreTest(ResticMixin, RemoteRestoreTest):
    def setUp(self):
        super().setUp()
        self.set_string("folder", self.folder + "-restic", child="remote")
