#!/bin/sh
# -*- Mode: sh; indent-tabs-mode: nil; tab-width: 2 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

# This script creates a quick disposable environment and settings, to quickly
# make screenshots.

set -e

SRCROOT=$(pwd)
ROOT=$(mktemp -d)

# Build non-devel version
[ -d _build/demo ] || meson setup -Denable_restic=true _build/demo
meson compile -C _build/demo
devenv() {
  meson devenv -C "$SRCROOT/_build/demo" env \
    HOME="$ROOT_HOME" XDG_CONFIG_HOME="$ROOT_CONFIG" \
    $*
}

# Set up home
export ROOT_HOME="$ROOT/user"
export ROOT_CONFIG="$ROOT_HOME/config"
mkdir -p "$ROOT_HOME/Downloads" "$ROOT_CONFIG"
echo 'XDG_DOWNLOAD_DIR="$HOME/Downloads"' > "$ROOT_CONFIG/user-dirs.dirs"

# Set up backup source
mkdir -p "$ROOT/src/full" "$ROOT/src/empty"
cd "$ROOT/src/full"
mkdir Recipes Homework Pictures Music
touch screen1.png screen2.png screen3.png
touch report.odt TODO.txt memo.ogg notes.txt
touch resume.pdf Museum.pdf 'building plans.pdf'
touch budget.ods 'lorem ipsum.txt' 'cute_cats.ogv'
touch 'Week1 Report.txt' 'Week2 Report.txt' 'Week3 Report.txt'

# Make initial backup
mkdir -p "$ROOT/dest"
duplicity --no-encryption "$ROOT/src" "file://$ROOT/dest"

# Set up gsettings
export ADW_DISABLE_PORTAL=1
export GSETTINGS_BACKEND=keyfile
devenv gsettings set org.gnome.DejaDup backend local
devenv gsettings set org.gnome.DejaDup last-backup "$(date --utc +%Y%m%dT%H%M%SZ)"
devenv gsettings set org.gnome.DejaDup last-run "$(date --utc +%Y%m%dT%H%M%SZ)"
devenv gsettings set org.gnome.DejaDup periodic true
devenv gsettings set org.gnome.DejaDup.Local folder "$ROOT/dest"

# Set up appearance
export DEJA_DUP_DEMO=1

devenv deja-dup
rm -r "$ROOT"
