#!/bin/sh
# -*- Mode: sh; indent-tabs-mode: nil; tab-width: 2; coding: utf-8 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

if [ -z "$DESTDIR" ]; then
  datadir="$1"

  echo "Updating icon cache..."
  gtk4-update-icon-cache -f -t "$datadir/icons/hicolor"

  echo "Updating gsettings cache..."
  glib-compile-schemas "$datadir/glib-2.0/schemas"
fi
