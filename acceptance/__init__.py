#!/usr/bin/env python3
# -*- Mode: Python; indent-tabs-mode: nil; tab-width: 4; coding: utf-8 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

import configparser
import os
import shutil
import signal
import subprocess
import unittest
from time import sleep

from dogtail.config import config

config.ensureSensitivity = True
config.logDebugToFile = False
config.searchShowingOnly = True

from dogtail import tree
from dogtail.predicate import GenericPredicate
from dogtail.utils import run
from gi.repository import Gio, GLib

from .gtk4 import Gtk4Node


class BaseTest(unittest.TestCase):
    def setUp(self):
        super().setUp()
        self.restic = False
        self.dbus = None
        self.reset_gsettings(self.get_settings())

        # Clean any previous cache files
        self.clean_cache()

        # Set up tiny sample source root
        self.rootdir = GLib.get_home_dir() + "/.deja-dup-test"
        self.srcdir = self.rootdir + "/src"
        shutil.rmtree(self.rootdir, ignore_errors=True)
        os.mkdir(self.rootdir)
        os.mkdir(self.srcdir)

        # Point at that root
        self.set_strv("include-list", [self.srcdir])

        # Set up config.ini support
        basedir = os.path.realpath(os.path.dirname(__file__))
        configname = os.path.join(basedir, "config.ini")
        if os.path.exists(configname):
            self.config = configparser.ConfigParser()
            self.config.read(configname)
        else:
            self.config = None

    def clean_cache(self):
        shutil.rmtree(os.environ["DD_CACHE_DIR"], ignore_errors=True)

    def randomize_srcdir(self):
        datadir = os.path.join(self.srcdir, "data")
        os.makedirs(datadir, exist_ok=True)

        basedir = os.path.realpath(os.path.join(os.path.dirname(__file__)))
        args = [os.path.join(basedir, "randomizer"), datadir]

        subprocess.run(args, check=True)

    def wait_for(self, func, timeout=30):
        while timeout:
            if func():
                return
            timeout -= 1
            sleep(1)
        assert func()

    def get_bus_pid(self, name):
        if not self.dbus:
            self.dbus = Gio.DBusProxy.new_for_bus_sync(
                Gio.BusType.SESSION,
                0,
                None,
                "org.freedesktop.DBus",
                "/org/freedesktop/DBus",
                "org.freedesktop.DBus",
                None,
            )
        try:
            pid = self.dbus.call_sync(
                "GetConnectionUnixProcessID", GLib.Variant("(s)", [name]), 0, -1, None
            )
        except GLib.Error:
            return None
        return pid.get_child_value(0).get_uint32()

    def kill_bus(self, name):
        pid = self.get_bus_pid(name)
        if pid:
            self.kill_pid(pid)

    def kill_pid(self, pid):
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass

    def start_pid(self, cmd, *args, **kwargs):
        commandline = cmd.split(" ") + list(args or [])
        pid = run(" ".join(commandline), appName=os.environ["DD_APPID"], **kwargs)
        self.addCleanup(self.kill_pid, pid)
        return pid

    def cmd(self, *args, window=True, env=None):
        execline = os.environ["DD_EXEC"]
        if env:
            execline = "env %s %s" % (env, execline)
        pid = self.start_pid(execline, *args)
        return self.get_app() if window else pid

    def monitor(self, *args):
        # Add a cleanup for any spawned deja-dup processes
        self.addCleanup(self.kill_bus, os.environ["DD_APPID"])
        return self.start_pid(
            os.environ["DD_MONITOR_EXEC"], "--no-delay", dumb=True, timeout=1
        )

    def get_app(self):
        return Gtk4Node(tree.root.application(os.environ["DD_APPID"]))

    def reset_gsettings(self, settings):
        schema = settings.get_property("settings-schema")
        for key in schema.list_keys():
            settings.reset(key)
        for child in schema.list_children():
            self.reset_gsettings(settings.get_child(child))

    def child(self, **kwargs):
        # If label= is provided, dogtail doesn't check any other traits
        maybe = self.app.child(**kwargs)
        roleName = kwargs.get("roleName")
        if roleName and maybe.role != roleName:
            return maybe.role

    def refresh(self, obj):
        kwargs = {"roleName": obj.roleName, "name": obj.name}
        if obj.labeler:
            try:
                kwargs["label"] = obj.labeler.name
            except AttributeError:
                pass
        return obj.parent.child(**kwargs)

    def walk_initial_backup(self, app, password=None, wait=True, remember=False):
        window = app.window("Back Up")
        window.button("Forward").click()  # folders
        window.button("Forward").click()  # storage location

        # window might have closed if auto-launched, so regrab it
        if self.restic:
            window = app.window("Set Encryption Password")
            password = password or "resticpassword"
        else:
            window = app.window("Require Password?")
        if password:
            window.child(roleName="text", label="Encryption password").text = password
            window.child(roleName="text", label="Confirm password").text = password
            if remember:
                window.child(roleName="check box", name="Remember password").click()
        else:
            window.child(
                roleName="check box", name="Password-protect your backup"
            ).click()

        window.button("Forward").click()

        if wait:
            self.wait_for(lambda: window.dead, timeout=60)
            return None
        else:
            return window

    def walk_incremental_backup(self, app, password=None, wait=True, title=None):
        if self.restic:
            password = password or "resticpassword"
        if password:
            window = app.window(title or "Encryption Password Needed")
            window.child(roleName="text", label="Encryption password").typeText(
                password
            )
            window.button("Forward").click()
        else:
            window = app.window(title or "Backing Up…")

        if wait:
            self.wait_for(lambda: window.dead)
            return None
        else:
            return window

    def enter_browser_password(self, app, password):
        # I'm having trouble with Enter Password appearing visible to dogtail,
        # but not really being rendered. So let's click it and see if a dialog appears.
        def click_and_see():
            app.button("Enter Password").click()
            return app.findChild(
                GenericPredicate(roleName="text entry", label="Encryption password"),
                retry=False,
                requireResult=False,
            )

        self.wait_for(click_and_see)
        app.child(roleName="text entry", label="Encryption password").typeText(password)
        app.button("Continue").click()

    def get_file_chooser(self, name):
        dlg = Gtk4Node(tree.root).child(roleName="dialog", name=name)

        # Focus dialog (not always done automatically with portal dialogs)
        dlg.child(roleName="panel").click()

        return dlg

    def click_restore_button(self, parent):
        buttons = parent.findChildren(GenericPredicate(roleName="push button", name="Restore"))
        self.assertEqual(len(buttons), 2)  # first is top tab, second is bottom button
        buttons[1].click()

    def get_config(self, section, option, fallback=None, required=True):
        if not self.config:
            if required:
                self.skipTest("No config.ini found")
            return fallback
        return self.config.get(section, option, fallback=fallback)

    def get_settings(self, child=None):
        settings = Gio.Settings.new(os.environ["DD_APPID"])
        if child:
            return settings.get_child(child)
        return settings

    def get_value(self, func, key, child=None):
        if "DD_KEYFILE" in os.environ:
            # The keyfile gsettings backend does not seem to reload correctly.
            # Or more accurately, I couldn't get it to do so. So we read
            # directly from it.
            keyfile = GLib.KeyFile()
            keyfile.load_from_file(os.environ["DD_KEYFILE"], 0)
            group = "org/gnome/" + os.environ["DD_KEYFILE_GROUPNAME"]
            if child:
                group += "/" + child
            if func == "get_int":
                func = "get_int32"
            try:
                strvalue = keyfile.get_value(group, key)
                varvalue = GLib.Variant.parse(None, strvalue)
            except GLib.GError:
                varvalue = self.get_settings(child=child).get_default_value(key)
            return getattr(varvalue, func)()

        settings = self.get_settings(child=child)
        return getattr(settings, func)(key)

    def get_strv(self, key, child=None):
        return self.get_value("get_strv", key, child=child)

    def get_string(self, key, child=None):
        return self.get_value("get_string", key, child=child)

    def get_boolean(self, key, child=None):
        return self.get_value("get_boolean", key, child=child)

    def get_int(self, key, child=None):
        return self.get_value("get_int", key, child=child)

    def set_value(self, func, key, value, child=None):
        if "DD_KEYFILE" in os.environ:
            # I was seeing failures because writing one entry would wipe out
            # other entries, when using the normal GSettings interface.
            # So much like when reading, we write directly to the keyfile.
            keyfile = GLib.KeyFile()
            keyfile.load_from_file(os.environ["DD_KEYFILE"], 0)
            group = "org/gnome/" + os.environ["DD_KEYFILE_GROUPNAME"]
            if child:
                group += "/" + child
            if func == "set_int":
                func = "new_int32"
            else:
                func = func.replace("set_", "new_")
            varvalue = getattr(GLib.Variant, func)(value)
            keyfile.set_value(group, key, varvalue.print_(False))
            keyfile.save_to_file(os.environ["DD_KEYFILE"])
        else:
            settings = self.get_settings(child=child)
            getattr(settings, func)(key, value)

        Gio.Settings.sync()

    def set_strv(self, key, value, child=None):
        self.set_value("set_strv", key, value, child=child)

    def set_string(self, key, value, child=None):
        self.set_value("set_string", key, value, child=child)

    def set_boolean(self, key, value, child=None):
        self.set_value("set_boolean", key, value, child=child)

    def set_int(self, key, value, child=None):
        self.set_value("set_int", key, value, child=child)


class ResticMixin:
    def setUp(self):
        super().setUp()
        self.set_string("tool", "restic")
        self.restic = True
