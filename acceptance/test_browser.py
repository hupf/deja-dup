#!/usr/bin/env python3
# -*- Mode: Python; indent-tabs-mode: nil; tab-width: 4; coding: utf-8 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

import os
import shutil
import stat

from dogtail.predicate import GenericPredicate
from dogtail.rawinput import keyCombo, typeText
from gi.repository import GLib

from . import BaseTest


class BrowserTest(BaseTest):
    def setUp(self):
        super().setUp()
        self.set_string("backend", "local")
        self.set_string("last-backup", "2000-01-01")  # to skip welcome screen
        self.set_string("last-run", "2000-01-01")

        self.use_backup_dir("unencrypted")

        shutil.rmtree(self.rootdir, ignore_errors=True)
        self.srcdir = "/tmp/deja-dup"
        shutil.rmtree(self.srcdir, ignore_errors=True)

        self.restoredir = "/tmp/deja-dup.restore"

        self.app = self.cmd()

    def use_backup_dir(self, path):
        basedir = os.path.realpath(os.path.join(os.path.dirname(__file__)))
        srcfiles = basedir + "/" + path

        backupdir = "/tmp/deja-dup.backup"
        shutil.rmtree(backupdir, ignore_errors=True)
        shutil.copytree(srcfiles, backupdir, ignore=shutil.ignore_patterns("*.license"))
        self.set_string("folder", backupdir, child="local")

    def switch_to_restore(self):
        self.app.child(roleName="radio button", name="Restore").click()

    def scan(self, password=None, error=None):
        self.switch_to_restore()

        if password:
            self.app.button("Enter Password").click()
            self.app.child(roleName="text entry", label="Encryption password").typeText(
                password
            )
            self.app.button("Continue").click()

        if error:
            self.app.child(roleName="label", name=error)
            return

        search = self.app.child(roleName="toggle button", name="Search")
        self.wait_for(lambda: search.sensitive)

    def assert_search_mode(self, searching=True):
        search = self.app.child(roleName="toggle button", name="Search")
        assert search.isChecked == searching

        search_entry = self.app.findChild(
            GenericPredicate(roleName="text", name="Search"),
            retry=False,
            requireResult=False,
        )
        if searching:
            assert search_entry
            assert search_entry.focused
        else:
            assert not search_entry

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
        self.app.button("Restore").click()
        self.window = self.app.window("Restore to Where?")

    def select_location(self, where):
        self.addCleanup(shutil.rmtree, where, ignore_errors=True)
        self.window.child(
            roleName="radio button", name="Restore to specific folder"
        ).click()
        self.window.child(roleName="push button", label="    Restore folder").click()
        self.window.child(roleName="menu item", name="Other…").click()
        os.makedirs(where, exist_ok=True)
        dlg = self.app.child(roleName="file chooser")
        typeText(where + "\n")
        dlg.child(name="Open").click()

    def walk_restore(self, password=None, error=False, where=None):
        self.start_restore()
        shutil.rmtree(self.srcdir, ignore_errors=True)

        if where:
            self.select_location(where)

        self.window.button("Restore").click()  # to where

        if password:
            self.window.child(
                roleName="text", label="Encryption password"
            ).text = password
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
        need_selection_mode = len(args) > 1
        if need_selection_mode:
            self.app.button("Select").click()

        view = self.app.findChild(
            lambda x: x.roleName == "layered pane", retry=False, requireResult=False
        )
        role = "icon"
        check_selected = True
        if not view:
            view = self.app.findChild(lambda x: x.roleName == "table")
            role = "table cell"
            check_selected = False

        children = view.findChildren(
            lambda x: x.roleName == role and x.text, showingOnly=False
        )
        for child in children:
            on = child.text in args
            if (check_selected and on != child.selected) or (not check_selected and on):
                child.click()

        if need_selection_mode:
            self.app.button("Cancel").click()

    def test_enable_search_mode(self):
        self.scan()

        self.assert_search_mode(False)
        keyCombo("<Control>f")
        self.assert_search_mode()

        keyCombo("Escape")

        self.assert_search_mode(False)
        self.app.child(roleName="toggle button", name="Search").click()
        self.assert_search_mode()

    def test_selection(self):
        self.scan()

        # Confirm titlebar buttons work
        self.assert_selection(False)
        self.app.button("Select").click()
        self.assert_selection()
        self.app.button("Cancel").click()
        self.assert_selection(False)
        self.app.button("Select").click()
        self.assert_selection()

        # Select all/none/some
        view = self.app.findChild(lambda x: x.roleName == "layered pane")
        icons = view.children
        assert len(icons) == 4 and len([i for i in icons if i.selected]) == 0
        menu = self.app.child(
            roleName="toggle button", name="Click on items to select them"
        )
        menu.click()
        self.app.button("Select All").click()
        assert len([i for i in icons if i.selected]) == 4
        menu.click()
        self.app.button("Select None").click()
        assert len([i for i in icons if i.selected]) == 0
        icons[0].click()
        assert len([i for i in icons if i.selected]) == 1
        icons[1].click()
        assert len([i for i in icons if i.selected]) == 2

        # Now test combining selection with search modes
        self.app.child(roleName="toggle button", name="Search").click()
        self.assert_search_mode()
        keyCombo("Escape")
        self.assert_selection(False)
        self.assert_search_mode()
        keyCombo("Escape")
        self.assert_selection(False)
        self.assert_search_mode(False)

    def test_successful_restore(self):
        self.scan()

        # select one (new location)
        self.select("four.txt")
        self.walk_restore(where=self.restoredir)
        self.check_files(("four.txt", "four"), where=self.restoredir)

        # select multiple (old location)
        self.select("one.txt", "two.txt")
        self.walk_restore()
        self.check_files(("one.txt", "one"), ("two.txt", "two"))

        # select multiple from diff dirs (old location)
        self.app.child(roleName="toggle button", name="Search").click()
        typeText("txt")
        self.select("one.txt", "three.txt")
        self.walk_restore()
        self.check_files(("one.txt", "one"), ("dir1/three.txt", "three"))
        self.app.child(roleName="toggle button", name="Search").click()

    def test_encrypted_and_dates(self):
        self.use_backup_dir("encrypted")
        self.scan(password="test")  # test password prompt

        # test dir navigation (could go in any test, but thrown in here)
        view = self.app.findChild(lambda x: x.roleName == "layered pane")
        back = self.app.button("Back")
        assert not back.sensitive
        assert len(view.children) == 3
        dir1 = self.app.findChild(
            lambda x: x.roleName == "icon" and x.text == "dir1", showingOnly=False
        )
        dir1.doubleClick()
        assert back.sensitive
        assert len(view.children) == 1
        back.click()
        assert not back.sensitive
        assert len(view.children) == 3

        # test time combo
        dates_combo = self.app.child(roleName="combo box", label="Date")
        dates = [
            x.name
            for x in dates_combo.findChildren(
                lambda x: x.roleName == "menu item", showingOnly=False
            )
        ]
        assert ["06/07/20 19:33:07", "06/07/20 19:29:40", "06/05/20"] == dates

        # click oldest date, it should have an extra item in it
        dates_combo.click()
        dates_combo.child(roleName="menu item", name="06/05/20").click()
        search = self.app.child(roleName="toggle button", name="Search")
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

        self.scan()
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
        self.select_location(self.srcdir)
        label = self.app.findChild(
            findPermissionLabel, retry=False, requireResult=False
        )
        assert label is None
        assert button.sensitive

        self.window.button("Cancel").click()

        # Now test a full backup attempt
        self.app.child(roleName="radio button", name="Overview").click()
        self.set_string("last-backup", "")  # to reset welcome screen
        self.app.button("Restore From a Previous Backup").click()
        self.window = self.app.window("Restore From Where?")
        self.window.button("Forward").click()  # from where
        self.window.button("Forward").click()  # when
        button = self.window.button("Forward")
        self.app.findChild(findPermissionLabel)
        self.app.findChild(
            lambda x: x.roleName == "label"
            and x.name == self.srcdir + "/four.txt\n" + self.srcdir + "/one.txt"
        )
        assert button.sensitive  # can still restore in this case
