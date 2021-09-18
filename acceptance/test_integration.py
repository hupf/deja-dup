#!/usr/bin/env python3
# -*- Mode: Python; indent-tabs-mode: nil; tab-width: 4; coding: utf-8 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

import glob
import os

from dogtail import tree
from gi.repository import Gio, GLib, Gtk

from . import BaseTest


class IntegrationTest(BaseTest):
    def setUp(self):
        super().setUp()
        if os.environ["DD_MODE"] == "dev":
            self.skipTest("dev mode")

    def test_translations(self):
        app = self.cmd(env="LANG=fr_FR.UTF-8 LANGUAGE=fr")
        assert app.childNamed("Restaurer")

    def test_help(self):
        if os.environ["DD_MODE"] == "snap":
            self.skipTest("snap removes help")

        # Also test that help is translated by passing LANG
        app = self.cmd(env="LANG=fr_FR.UTF-8 LANGUAGE=fr")
        app.button("Menu").click()

        self.addCleanup(self.kill_bus, "org.gnome.Yelp")
        app.button("Aide").click()

        yelp = tree.root.application("yelp")
        assert yelp.childNamed("Sauvegarder")

    def test_desktop_file(self):
        # Find the file in system data dirs
        found = None
        datadirs = {d + "/applications" for d in GLib.get_system_data_dirs()}
        for datadir in datadirs:
            desktopfiles = glob.glob(datadir + "/*.desktop")
            for desktopfile in desktopfiles:
                f = open(desktopfile)
                if os.environ["DD_DESKTOP"] + "\n" in f.readlines():
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
        self.addCleanup(self.kill_bus, os.environ["DD_APPID"])
        found.launch(None, None)
        assert tree.root.application(os.environ["DD_APPID"])
