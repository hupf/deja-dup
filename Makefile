# -*- Mode: Makefile; indent-tabs-mode: t; tab-width: 2 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

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

.PHONY: acceptance-flatpak acceptance-snap
acceptance-flatpak:
	./acceptance/run-ui-tests --flatpak ./acceptance
acceptance-snap:
	./acceptance/run-ui-tests --snap ./acceptance

.PHONY: clean
clean:
	rm -rf builddir

.PHONY: devshell
devshell:
	@flatpak run \
		--env=LD_LIBRARY_PATH=`pwd`/builddir/dev/lib \
		--env=PKG_CONFIG_PATH=`pwd`/builddir/dev/lib/pkgconfig \
		--env=XDG_DATA_DIRS=/app/share:/usr/share:/usr/share/runtime/share:/run/host/user-share:/run/host/share:`pwd`/builddir/dev/share \
		--filesystem=host \
		org.gnome.Sdk//master

.PHONY: devshell-setup
devshell-setup:
	flatpak remote-add --if-not-exists gnome-nightly https://nightly.gnome.org/gnome-nightly.flatpakrepo
	flatpak install --or-update gnome-nightly flatpak org.gnome.Sdk//master
	mkdir -p builddir
	rm -rf builddir/libhandy
	git clone --depth=1 --branch=libhandy-0-0 https://gitlab.gnome.org/GNOME/libhandy.git builddir/libhandy
	flatpak run --filesystem=host --command=make org.gnome.Sdk//master devshell-internal
	@echo -e '\033[0;36mAll done!\033[0m Run "make devshell" to enter the build environment'

.PHONY: devshell-internal
devshell-internal:
	meson -Dtests=false -Dexamples=false --prefix=`pwd`/builddir/dev builddir/libhandy/_build builddir/libhandy
	ninja -C builddir/libhandy/_build
	ninja -C builddir/libhandy/_build install

.PHONY: flatpak
flatpak:
	flatpak-builder --repo=$(HOME)/repo \
	                --force-clean \
	                --state-dir=builddir/.flatpak-builder \
	                builddir/flatpak \
	                flatpak/org.gnome.DejaDupDevel.yaml
	flatpak install --or-update --user -y org.gnome.DejaDupDevel//master

.PHONY: flatpak-update
flatpak-update:
	cd flatpak; \
	for p in duplicity pydrive2 setuptools-scm wheel; do \
		../../flatpak-builder-tools/pip/flatpak-pip-generator --output $$p $$p; \
		../../flatpak-builder-tools/flatpak-json2yaml.py -f --output $$p.yaml $$p.json; \
		rm $$p.json; \
		sed -i '1i# SPDX-License-Identifier\: GPL-3.0-or-later\n# SPDX-FileCopyrightText\: Michael Terry\n---' $$p.yaml; \
	done; \
	grep -e type: -e url: -e sha256: wheel.yaml >> pydrive2.yaml; \
	rm wheel.yaml

.PHONY: black
black:
	black --check -t py38 --exclude builddir --include 'mock/duplicity|\.py$$' .

.PHONY: reuse
reuse:
	reuse lint

builddir/vlint:
	mkdir -p builddir
	git clone https://github.com/vala-lang/vala-lint.git builddir/vala-lint
	cd builddir/vala-lint && meson build && ninja -C build
	ln -s ./vala-lint/build/src/io.elementary.vala-lint builddir/vlint

.PHONY: lint
lint: reuse black builddir/vlint
	builddir/vlint -c vala-lint.conf .
