#!/usr/bin/env python3
# -*- Mode: Python; indent-tabs-mode: nil; tab-width: 4; coding: utf-8 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

from subprocess import check_output

import pyatspi
from dogtail import rawinput
from dogtail.config import config
from dogtail.predicate import GenericPredicate
from dogtail.tree import Node, SearchError


class Gtk4Node:
    """Methods to work around the current gtk4 support in dogtail"""

    def __init__(self, node, coords=None):
        super().__init__()
        self.node = node
        self.coords = coords

    def _wrapShowingMethod(self, func, *args, showingOnly=None, **kwargs):
        """Handle a lack of STATE_SHOWING in gtk4"""
        try:
            c = func(*args, **kwargs, showingOnly=False)
        except SearchError:
            self.node.dump()  # a little debugging help
            raise
        if c is None:
            return None
        c = Gtk4Node(c, self.coords)
        if showingOnly is None:
            showingOnly = config.searchShowingOnly
        if showingOnly is True:
            if kwargs.get("requireResult", True):
                assert c.showing
            elif not c.showing:
                return None
        return c

    def button(self, name, *args, **kwargs):
        # Buttons with mnemonics seem to show up with their mnemonic and normal
        # labels jammed together. So look for the label instead, not name.
        return self._wrapShowingMethod(
            self.node.child, label=name, roleName="push button", *args, **kwargs
        )

    def child(self, *args, **kwargs):
        return self._wrapShowingMethod(self.node.child, *args, **kwargs)

    def childNamed(self, *args, **kwargs):
        return self._wrapShowingMethod(self.node.childNamed, *args, **kwargs)

    def findChild(self, *args, **kwargs):
        return self._wrapShowingMethod(self.node.findChild, *args, **kwargs)

    def findChildren(self, *args, showingOnly=None, **kwargs):
        children = self.node.findChildren(*args, **kwargs, showingOnly=False)
        if showingOnly is None:
            showingOnly = config.searchShowingOnly

        allowed = []
        for c in children:
            c = Gtk4Node(c, self.coords)
            if showingOnly is True and not c.showing:
                continue
            allowed.append(c)
        return allowed

    def window(self, *args, **kwargs):
        return self._wrapShowingMethod(self.node.window, *args, **kwargs)

    def _ensure_coords(self):
        if self.coords:
            return

        top = self.node.findAncestor(GenericPredicate(roleName="frame"))
        if not top:
            top = self.node.findAncestor(GenericPredicate(roleName="dialog"))
        assert top

        from Xlib import X, display, Xutil

        d = display.Display()
        r = d.screen().root
        t = r.query_tree()
        for win in t.children:
            if win.get_wm_name() == top.name:
                break
        else:
            raise Exception(f"Couldn't find window {top.name}")

        root_coords = r.translate_coords(win, 0, 0)

        # Fix coords to take into account client side decorations.
        # Hardcoding this is super gross, I'd love a better way.
        self.coords = (root_coords.x + 50, root_coords.y + 50)

    def click(self, button=1):
        """Click with adjusted screen-global coordinates"""
        # If we can avoid the vagaries of coordinates, let's do that. This is
        # useful in particular with popup menu items, whose coordinates need
        # some further adjustment than I've made here...
        if "click" in self.node.actions:
            self.node.doActionNamed("click")
            return

        self._ensure_coords()
        clickX = self.coords[0] + self.node.position[0] + self.node.size[0] / 2
        clickY = self.coords[1] + self.node.position[1] + self.node.size[1] / 2

        rawinput.click(clickX, clickY, button)

    def doubleClick(self, button=1):
        """Double click with adjusted screen-global coordinates"""
        self._ensure_coords()
        clickX = self.coords[0] + self.node.position[0] + self.node.size[0] / 2
        clickY = self.coords[1] + self.node.position[1] + self.node.size[1] / 2
        rawinput.doubleClick(clickX, clickY, button)

    @property
    def pressed(self):
        return self.node.getState().contains(pyatspi.STATE_PRESSED)

    @property
    def checked(self):
        return self.node.checked

    @property
    def children(self):
        return self.node.children

    @property
    def dead(self):
        return self.node.dead

    def dump(self):
        self.node.dump()

    def findAncestor(self, *args, **kwargs):
        return self._wrapShowingMethod(self.node.findAncestor, *args, **kwargs)

    @property
    def focused(self):
        return self.node.focused

    @property
    def labeler(self):
        return self.node.labeler and Gtk4Node(self.node.labeler, self.coords)

    @property
    def name(self):
        return self.node.name

    @property
    def parent(self):
        return self.node.parent and Gtk4Node(self.node.parent, self.coords)

    @property
    def roleName(self):
        return self.node.roleName

    @property
    def selected(self):
        return self.node.getState().contains(pyatspi.STATE_SELECTED)

    @property
    def sensitive(self):
        return self.node.sensitive

    @property
    def showing(self):
        return self.node.visible

    @property
    def text(self):
        return self.node.text

    @text.setter
    def text(self, text):
        self.node.text = text

    def typeText(self, text):
        return self.node.typeText(text)

    @property
    def value(self):
        return self.node.value
