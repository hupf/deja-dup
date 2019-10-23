# -*- Mode: Makefile; indent-tabs-mode: t; tab-width: 2 -*-
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

.PHONY: all
all: configure
	ninja -C builddir

%:
	@[ "$@" = "Makefile" ] || ninja -C builddir $@

.PHONY: configure
configure:
	@[ -f builddir/build.ninja ] || meson -Dprofile=Devel builddir

.PHONY: check
check: all
	LC_ALL=C.UTF-8 meson test -C builddir

.PHONY: clean
clean:
	rm -rf builddir parts stage prime *.snap

.PHONY: screenshots
screenshots: all
	@gsettings set org.gnome.desktop.interface font-name 'Cantarell 11'
	@gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'
	@gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'
	@gsettings set org.gnome.desktop.wm.preferences theme 'Adwaita'
	@gsettings set org.gnome.DejaDup backend 'file'
	@sleep 5
	
	@mkdir -p ./builddir/screenshots
	@rm -f ./builddir/screenshots/*
	
	@./tests/shell-local "deja-dup" &
	@gnome-screenshot --window --delay 1 --file data/appdata/01-main.png
	@killall deja-dup
	
	@./tests/shell-local "deja-dup --backup" >/dev/null &
	@gnome-screenshot --window --delay 1 --file data/appdata/02-backup.png
	@killall deja-dup
	
	@gsettings reset org.gnome.desktop.interface font-name
	@gsettings reset org.gnome.desktop.interface gtk-theme
	@gsettings reset org.gnome.desktop.interface icon-theme
	@gsettings reset org.gnome.desktop.wm.preferences theme
	@gsettings reset org.gnome.DejaDup backend
	
	@eog data/appdata

.PHONY: pot
pot: configure
	ninja -C builddir deja-dup-pot help-deja-dup-pot

.PHONY: translations
translations: pot
	mkdir -p builddir
	rm -rf builddir/translations
	bzr co --lightweight lp:~mterry/deja-dup/translations builddir/translations
	cp -a builddir/translations/po/*.po po
	cp -a builddir/translations/help/*.po help
	git add po/*.po
	git add help/*.po

.PHONY: devshell
devshell:
	flatpak run --filesystem=host org.gnome.Sdk//master

.PHONY: flatpak
flatpak:
	flatpak-builder --repo=$(HOME)/repo \
	                --force-clean \
	                --state-dir=builddir/.flatpak-builder \
	                builddir/flatpak \
	                flatpak/org.gnome.DejaDupDevel.yaml
	flatpak update --user -y org.gnome.DejaDupDevel

.PHONY: flatpak-update
flatpak-update:
	for p in fasteners future pydrive; do \
		../flatpak-builder-tools/pip/flatpak-pip-generator --output flatpak/$$p.json $$p; \
	done
	sed -i 's/^[][]//g' flatpak/*.json

.PHONY: snap
snap:
	rm -f *.snap
	snapcraft snap
	snap install ./*.snap --classic --dangerous

builddir/vlint:
	mkdir -p builddir
	git clone https://github.com/vala-lang/vala-lint builddir/vala-lint
	cd builddir/vala-lint && meson build && ninja -C build
	ln -s ./vala-lint/build/src/io.elementary.vala-lint builddir/vlint

.PHONY: lint
lint: builddir/vlint
	builddir/vlint -c vala-lint.conf .
