#!/usr/bin/env python3
# -*- Mode: Python; indent-tabs-mode: nil; tab-width: 4; coding: utf-8 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

import pyatspi
from dogtail.config import config
from dogtail.tree import Node, SearchError


class Gtk4Node:
    """Methods to work around the current gtk4 support in dogtail"""

    def __init__(self, node):
        super().__init__()
        self.node = node

    def _wrapShowingMethod(self, func, *args, showingOnly=None, **kwargs):
        """Handle a lack of STATE_SHOWING in gtk4"""
        try:
            c = func(*args, **kwargs, showingOnly=False)
        except SearchError:
            self.node.dump()  # a little debugging help
            raise
        if showingOnly is None:
            showingOnly = config.searchShowingOnly
        if showingOnly is True:
            assert c.getState().contains(pyatspi.STATE_VISIBLE)
        return Gtk4Node(c)

    def button(self, name, *args, **kwargs):
        # Buttons with mnemonics seem to show up with their mnemonic and normal
        # labels jammed together. So look for the label instead, not name.
        return self._wrapShowingMethod(self.node.child, label=name,
                                       roleName='push button', *args, **kwargs)

    def child(self, *args, **kwargs):
        return self._wrapShowingMethod(self.node.child, *args, **kwargs)

    def childNamed(self, *args, **kwargs):
        return self._wrapShowingMethod(self.node.childNamed, *args, **kwargs)

    def window(self, *args, **kwargs):
        return self._wrapShowingMethod(self.node.window, *args, **kwargs)

    def click(self):
        """Click using actions, not coordinates"""
        if 'click' in self.node.actions:
            self.node.doActionNamed('click')
        elif 'toggle' in self.node.actions:
            self.node.doActionNamed('toggle')
        else:
            # Sometimes a node will be like... MenuButton > Image with click
            assert len(self.node.children) == 1
            Gtk4Node(self.node.children[0]).click()

    # Passthroughs
    @property
    def checked(self):
        return self.node.checked
    @property
    def roleName(self):
        return self.node.roleName
    @property
    def name(self):
        return self.node.name
    @property
    def labeler(self):
        return Gtk4Node(self.node.labeler)
    @property
    def parent(self):
        return Gtk4Node(self.node.parent)
