#!/usr/bin/env python3
# -*- Mode: Python; indent-tabs-mode: nil; tab-width: 4; coding: utf-8 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

import os
import shutil
import stat

from dogtail.predicate import GenericPredicate
from dogtail.rawinput import holdKey, keyCombo, pressKey, releaseKey, typeText
from gi.repository import GLib

from . import BaseTest, ResticMixin


class BrowserTest(BaseTest):
    def setUp(self):
        super().setUp()
        self.set_string("backend", "local")
        self.set_string("last-backup", "2000-01-01")  # to skip welcome screen
        self.set_string("last-run", "2000-01-01")

        shutil.rmtree(self.rootdir, ignore_errors=True)
        self.srcdir = "/tmp/deja-dup"
        shutil.rmtree(self.srcdir, ignore_errors=True)

        self.restoredir = self.rootdir + "/restore"
        self.password = None
        self.app = self.cmd()

    def use_backup_dir(self, path):
        basedir = os.path.realpath(os.path.join(os.path.dirname(__file__)))
        srcfiles = basedir + "/" + path

        backupdir = "/tmp/deja-dup.backup"
        shutil.rmtree(backupdir, ignore_errors=True)
        shutil.copytree(srcfiles, backupdir, ignore=shutil.ignore_patterns("*.license"))
        self.set_string("folder", backupdir, child="local")

    def switch_to_restore(self):
        widget = self.app.child(roleName="label", name="Restore", showingOnly=False)
        while widget.parent:
            widget = widget.parent
            if widget.roleName == "page tab":
                widget.click()
                return
        assert False

    def scan(self, error=None):
        self.switch_to_restore()

        if self.password:
            self.enter_browser_password(self.app, self.password)

        if error:
            self.app.child(roleName="label", name=error)
            return

        search = self.app.child(roleName="push button", name="Search")
        self.wait_for(lambda: search.sensitive)

    def scan_dir1(self):
        """
        Set up primary backup directory, used for most tests.

        We only look at the most current backup, which must include:
         dir1/three.txt ("three")
         four.txt ("four")
         one.txt ("one")
         two.txt ("two")
        """
        self.use_backup_dir("duplicity1")
        self.scan()

    def scan_dir2(self):
        """
        Set up secondary backup directory.

        If the backup tool supports both encrypted and unencrypted backups,
        it's useful to have the primary or secondary dirs be different.

        This dir should hold three different snapshots, whose dates should
        be stored in self.snapshots.

        The most recent snapshot should contain:
          dir1/three.txt
          one.txt
          two.txt

        The oldest snapshot should contain those as well as four.txt.
        """
        self.password = "test"
        self.use_backup_dir("duplicity2")
        self.scan()
        self.snapshots = ["06/07/20 09:33:07", "06/07/20 09:29:40", "06/04/20"]

    def assert_search_mode(self, searching=True):
        search = self.app.child(roleName="push button", name="Search")
        assert search.pressed == searching

        # The entry is always visible in the accessiblity tree
        search_entry = self.app.child(roleName="entry", name="Search")
        if searching:
            assert search_entry.focused
        else:
            assert search_entry.text == ""

    def assert_selection(self, selecting=True):
        predicate = GenericPredicate(
            roleName="toggle button", name="Click on items to select them"
        )
        selection_button = self.app.findChild(
            predicate, retry=False, requireResult=False
        )
        if selecting:
            assert selection_button
        else:
            assert not selection_button

    def start_restore(self):
        self.click_restore_button(self.app)
        self.window = self.app.window("Restore to Where?")

    def select_location(self, where):
        self.addCleanup(shutil.rmtree, where, ignore_errors=True)
        self.window.child(
            roleName="check box", name="Restore to _specific folder"
        ).click()
        self.window.child(roleName="push button", label="Choose Folder…").click()
        os.makedirs(where, exist_ok=True)
        dlg = self.get_file_chooser("Choose Folder")
        # Focus dialog (not always done automatically with portal dialogs)
        dlg.child(roleName="label", name="Choose Folder").click()
        typeText(where + "\n")
        self.wait_for(lambda: dlg.dead)

    def walk_restore(self, error=False, where=None):
        self.start_restore()
        shutil.rmtree(self.srcdir, ignore_errors=True)

        if where:
            self.select_location(where)

        self.window.button("Restore").click()  # to where

        if self.password:
            self.window.child(
                roleName="text", label="Encryption password"
            ).text = self.password
            self.window.button("Forward").click()

        title = "Restore Failed" if error else "Restore Finished"
        self.wait_for(
            lambda: self.window.findChild(
                GenericPredicate(name=title), retry=False, requireResult=False
            ),
            timeout=60,
        )
        self.window.button("Close").click()

    def check_files(self, *file_args, where=None):
        if not where:
            where = self.srcdir

        # confirm no extra files restored
        file_count = 0
        for root, dirs, files in os.walk(where):
            file_count += len(files)
        assert file_count == len(file_args)

        # confirm content itself
        for name, content in file_args:
            test_file = open(os.path.join(where, name), "r")
            assert test_file.read(None).strip() == content

    def select(self, *args):
        children = self.app.findChildren(lambda x: x.roleName == "table cell")
        for child in children:
            # Skip if this is just a Location column cell
            if not child.findChild(
                lambda x: x.roleName == "image", retry=False, requireResult=False
            ):
                continue

            # SKip if this is already in the selection state we want
            label = child.child(roleName="label")
            on = label.name in args
            if on == child.selected:
                continue

            # Perform a ctrl+click to toggle selection
            holdKey("Control_L")
            child.click()
            releaseKey("Control_L")

            # In a table view, ctrl+click only FOCUSES the row, not
            # selecting it. So we press space to actually toggle selection.
            if child.parent.roleName == "table row":
                pressKey("space")

    def test_enable_search_mode(self):
        self.scan_dir1()

        self.assert_search_mode(False)
        keyCombo("<Control>f")
        self.assert_search_mode()

        keyCombo("Escape")

        self.assert_search_mode(False)
        self.app.child(roleName="push button", name="Search").click()
        self.assert_search_mode()

    def test_select_all(self):
        self.scan_dir1()

        icons = self.app.findChildren(lambda x: x.roleName == "table cell")
        assert len(icons) == 4 and len([i for i in icons if i.selected]) == 0

        self.app.childNamed("Main Menu").click()
        self.app.childNamed("Select All").click()

        assert len([i for i in icons if i.selected]) == 4

    def test_successful_restore(self):
        self.scan_dir1()

        # select one (new location)
        self.select("four.txt")
        self.walk_restore(where=self.restoredir)
        self.check_files(("four.txt", "four"), where=self.restoredir)

        # select multiple (old location)
        self.select("one.txt", "two.txt")
        self.walk_restore()
        self.check_files(("one.txt", "one"), ("two.txt", "two"))

        # select multiple from diff dirs (old location)
        self.app.child(roleName="push button", name="Search").click()
        typeText("txt")
        self.select("one.txt", "three.txt")
        self.walk_restore()
        self.check_files(("one.txt", "one"), ("dir1/three.txt", "three"))
        self.app.child(roleName="push button", name="Search").click()

    def test_encrypted_and_dates(self):
        self.scan_dir2()

        # test dir navigation (could go in any test, but thrown in here)
        view = self.app.child(roleName="table")
        back = self.app.child(roleName="push button", name="Back")
        assert not back.sensitive
        assert len(view.children) == 3
        dir1 = view.child(roleName="label", name="dir1")
        dir1.doubleClick()
        assert back.sensitive
        assert len(view.children) == 1
        back.click()
        assert not back.sensitive
        assert len(view.children) == 3

        # test time combo
        dates_combo = self.app.child(roleName="combo box", label="Date")
        dates_combo.click()
        popover = dates_combo.child(name="GtkPopover")
        dates = [
            x.name
            for x in popover.findChildren(
                lambda x: x.roleName == "label", showingOnly=False
            )
        ]
        assert self.snapshots == dates

        # choose oldest date, it should have an extra item in it
        pressKey("Down")
        pressKey("Down")
        pressKey("Return")
        search = self.app.child(roleName="push button", name="Search")
        self.wait_for(lambda: search.sensitive)
        assert len(view.children) == 4

    def test_scan_error(self):
        self.set_string("folder", "/tmp/deja-dup.missing", child="local")
        self.scan(error="No backup files found")

    def test_bad_restore_permissions(self):
        os.makedirs(self.srcdir, exist_ok=True)
        open(self.srcdir + "/four.txt", "w+").close()
        os.chmod(self.srcdir + "/four.txt", stat.S_IRUSR)
        open(self.srcdir + "/one.txt", "w+").close()
        os.chmod(self.srcdir + "/one.txt", stat.S_IRUSR)

        def findPermissionLabel(x):
            return (
                x.roleName == "label"
                and x.name
                == "Backups does not have permission to restore the following files:"
            )

        self.scan_dir1()
        self.select("four.txt", "dir1")
        self.start_restore()
        button = self.window.button("Restore")

        # Test can't backup
        self.app.findChild(findPermissionLabel)
        self.app.findChild(
            lambda x: x.roleName == "label" and x.name == self.srcdir + "/four.txt"
        )
        assert not button.sensitive

        # Test that we can if you switch locations
        self.select_location(self.restoredir)
        label = self.app.findChild(
            findPermissionLabel, retry=False, requireResult=False
        )
        assert label is None
        assert button.sensitive

        self.window.button("Cancel").click()


class ResticBrowserTest(ResticMixin, BrowserTest):
    def scan_dir1(self):
        self.password = "test1"
        self.use_backup_dir("restic1")
        self.scan()

    def scan_dir2(self):
        self.password = "test2"
        self.use_backup_dir("restic2")
        self.scan()
        self.snapshots = ["08/02/21 15:34:06", "08/02/21 15:33:43", "07/28/21"]
