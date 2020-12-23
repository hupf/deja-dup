#!/usr/bin/env python3
# -*- Mode: Python; indent-tabs-mode: nil; tab-width: 4; coding: utf-8 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

from dogtail import tree
from gi.repository import GLib

from . import BaseTest


class PreferencesTest(BaseTest):
    def setUp(self):
        super().setUp()
        self.app = self.cmd()
        self.app.childNamed("Menu").click()
        self.app.childNamed("Preferences").click()

    def test_general(self):
        # Test that there's a special first time welcome screen
        self.app.button("Create My First Backup")

        # Grab switch from main window, set last-run time so the switch shows up
        now = GLib.DateTime.new_now_utc().format_iso8601()
        self.set_string("last-run", now)
        main = self.app.window("Backups")
        periodic_main_box = main.child(roleName="panel", name="Back up automatically")
        periodic_main = periodic_main_box.child(roleName="check box")

        prefs = self.app.window("Preferences")

        # Periodic to settings
        listbox = prefs.child(roleName="list item", name="Back Up Automatically")
        periodic = listbox.child(roleName="check box")
        self.assertFalse(periodic.checked)
        self.assertFalse(periodic_main.checked)
        periodic.click()
        self.assertTrue(self.get_boolean("periodic"))

        # Periodic from settings
        self.assertTrue(periodic.checked)
        self.assertTrue(periodic_main.checked)
        self.set_boolean("periodic", False)
        self.wait_for(lambda: not self.refresh(periodic).checked)
        self.wait_for(lambda: not self.refresh(periodic_main).checked)
        self.set_boolean("periodic", True)
        self.wait_for(lambda: self.refresh(periodic).checked)
        self.wait_for(lambda: self.refresh(periodic_main).checked)

        # Period to settings
        period_box = prefs.child(roleName="list item", name="Automatic Backup Frequency")
        period = period_box.child(roleName="list")
        period.click()
        prefs.child(name="Daily").click()
        self.assertEqual(self.get_int("periodic-period"), 1)

        period.click()
        prefs.child(name="Weekly").click()
        self.assertEqual(self.get_int("periodic-period"), 7)

        # Period from settings
        self.set_int("periodic-period", 10)
        self.refresh(period).child(name="Every 10 days")  # just test existence

        # Delete After to settings
        delete_box = prefs.child(roleName="list item", name="Keep Backups")
        delete = delete_box.child(roleName="list")
        delete.click()
        prefs.child(name="At least a year").click()
        self.assertEqual(self.get_int("delete-after"), 365)

        delete.click()
        prefs.child(name="Forever").click()
        self.assertEqual(self.get_int("delete-after"), 0)

        # Delete After from settings
        self.set_int("delete-after", 12)
        self.refresh(delete).child(name="At least 12 days")  # just test existence

    def table_names(self, table):
        table = self.refresh(table)

        def iter(x):
            return x.roleName == "label" and x.name

        objs = table.findChildren(iter, showingOnly=False)
        return [x.name for x in objs]

    def wait_for_table_names(self, table, names):
        self.wait_for(lambda: self.table_names(table) == names)

    def assert_inclusion_table(self, widget, key):
        prefs = self.app.window("Preferences")
        prefs.child(name="Folders").click()

        label = prefs.child(name=widget)
        table = label.parent.child(roleName="list")

        user = GLib.get_user_name()
        home = GLib.get_home_dir()
        homename = home.rsplit("/", 1)[-1]

        # Test display names
        self.set_strv(
            key,
            [
                "$DESKTOP",
                "$DOCUMENTS/path",
                "$DOWNLOAD",
                "$MUSIC/path",
                "$PUBLIC_SHARE",
                "$TEMPLATES/path",
                "$VIDEOS",
                "$HOME",
                "$TRASH",
                "relative/$USER/path",
                "/absolute/$USER/path",
                "$PICTURES",
            ],
        )
        labels = [
            "~/Desktop",
            "~/Documents/path",
            "~/Downloads",
            "~/Music/path",
            "~/Public",
            "~/Templates/path",
            "~/Videos",
            "Home ({})".format(homename),
            "Trash",
            "~/relative/{}/path".format(user),
            "/absolute/{}/path".format(user),
            "~/Pictures",
        ]
        self.wait_for_table_names(table, labels)

        # Remove most
        def remove_buttons(x):
            return x.roleName == "push button" and x.name == "Remove"

        count = len(labels)
        for i in range(len(labels) - 1):
            self.refresh(table).findChild(remove_buttons).click()
        self.wait_for_table_names(table, ["~/Pictures"])
        self.assertEqual(self.get_strv(key), ["$PICTURES"])

        # Add one
        add = table.child(name="Add")
        add.click()
        dlg = tree.root.child(roleName="file chooser", name='Choose Folders')
        dlg.child(name="Documents").click()
        dlg.child(name="Add").click()
        self.wait_for_table_names(table, ["~/Pictures", "~/Documents"])
        self.assertEqual(self.get_strv(key), ["$PICTURES", home + "/Documents"])

    def test_includes(self):
        self.assert_inclusion_table("Folders to Back Up", "include-list")

    def test_excludes(self):
        self.assert_inclusion_table("Folders to Ignore", "exclude-list")
