#!/bin/sh
# -*- Mode: sh; indent-tabs-mode: nil; tab-width: 2; coding: utf-8 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

datadir="$DESTDIR/$1"

# Drop the translation section from the non-translated help
sed -i 's/.*translation-credits.*//' "$datadir/help/C/deja-dup/credits.page"
