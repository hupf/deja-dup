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
import shutil
import signal
import unittest
from time import sleep

from dogtail.config import config
config.logDebugToFile = False

from dogtail import tree
from dogtail.procedural import run
from gi.repository import Gio, GLib


class BaseTest(unittest.TestCase):
    def setUp(self):
        super().setUp()
        self.dbus = None
        self.settings = Gio.Settings.new('org.gnome.DejaDup')
        self.reset_gsettings(self.settings)

        # Set up tiny sample source root
        self.rootdir = GLib.get_home_dir() + '/.deja-dup-test'
        self.srcdir = self.rootdir + '/src'
        shutil.rmtree(self.rootdir, ignore_errors=True)
        os.mkdir(self.rootdir)
        os.mkdir(self.srcdir)
        test_file = open(self.srcdir + '/test.txt', 'w')
        test_file.write('hello')

        # Point at that root
        self.set_strv('include-list', [self.srcdir])

    def wait_for(self, func, timeout=30):
        while not func() and timeout:
            timeout -= 1
            sleep(1)
        assert func()

    def get_bus_pid(self, name):
        if not self.dbus:
            self.dbus = Gio.DBusProxy.new_for_bus_sync(
                Gio.BusType.SESSION, 0, None,
                'org.freedesktop.DBus', '/org/freedesktop/DBus',
                'org.freedesktop.DBus', None,
            )
        try:
            pid = self.dbus.call_sync('GetConnectionUnixProcessID',
                                      GLib.Variant('(s)', [name]), 0, -1, None)
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

    def start_pid(self, cmd, *args):
        pid = run(cmd,
                  arguments=' '.join(args or []),
                  appName='org.gnome.DejaDup')
        self.addCleanup(self.kill_pid, pid)
        return pid

    def cmd(self, *args, window=True):
        pid = self.start_pid('deja-dup', *args)
        return tree.root.application('org.gnome.DejaDup') if window else pid

    def monitor(self, *args, window=True):
        # Add a cleanup for any spawned deja-dup processes
        self.addCleanup(self.kill_bus, 'org.gnome.DejaDup')

        pid = self.start_pid(os.environ['DEJA_DUP_MONITOR_EXEC'], '--no-delay')
        return tree.root.application('org.gnome.DejaDup') if window else pid

    def reset_gsettings(self, settings):
        schema = settings.get_property('settings-schema')
        for key in schema.list_keys():
            settings.reset(key)
        for child in schema.list_children():
            self.reset_gsettings(settings.get_child(child))

    def child(self, **kwargs):
        # If label= is provided, dogtail doesn't check any other traits
        maybe = self.app.child(**kwargs)
        roleName = kwargs.get('roleName')
        if roleName and maybe.role != roleName:
            return maybe.role

    def refresh(self, obj):
        kwargs = {
            'roleName': obj.roleName,
            'name': obj.name,
        }
        if obj.labeler:
            kwargs['label'] = obj.labeler.name
        return obj.parent.child(**kwargs)

    def walk_initial_backup(self, app, error=False, password=None):
        window = app.window('Back Up')

        if password:
            window.child(roleName='text', label='Encryption password').text = password
            window.child(roleName='text', label='Confirm password').text = password
        else:
            window.child(roleName='radio button',
                         name='Allow restoring without a password').click()

        window.button('Forward').click()

        if not error:
            self.wait_for(lambda: window.dead)
        else:
            window.childNamed('Backup Failed')
            window.button('Close').click()

    def walk_incremental_backup(self, app, password=None, wait=True):
        window = app.window('Back Up')

        if password:
            window.child(roleName='text', label='Encryption password').text = password
            window.button('Forward').click()

        if wait:
            self.wait_for(lambda: window.dead)

    def set_value(self, func, key, value, child=None):
        settings = self.settings.get_child(child) if child else self.settings
        getattr(settings, func)(key, value)
        settings.sync()

    def set_strv(self, key, value, child=None):
        self.set_value('set_strv', key, value, child=child)

    def set_string(self, key, value, child=None):
        self.set_value('set_string', key, value, child=child)

    def set_boolean(self, key, value, child=None):
        self.set_value('set_boolean', key, value, child=child)

    def set_int(self, key, value, child=None):
        self.set_value('set_int', key, value, child=child)
