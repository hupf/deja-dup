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
	cd flatpak; \
	for p in duplicity pydrive setuptools-scm; do \
		../../flatpak-builder-tools/pip/flatpak-pip-generator --output $$p $$p; \
		../../flatpak-builder-tools/flatpak-json2yaml.py -f --output $$p.yaml $$p.json; \
		rm $$p.json; \
		sed -i '1i# SPDX-License-Identifier\: GPL-3.0-or-later\n# SPDX-FileCopyrightText\: Michael Terry\n---' $$p.yaml; \
	done

.PHONY: black
black:
	black --check -t py38 --exclude builddir --include 'mock/duplicity|\.py$$' .

.PHONY: reuse
reuse:
	reuse lint

builddir/vlint:
	mkdir -p builddir
	git clone https://github.com/vala-lang/vala-lint builddir/vala-lint
	cd builddir/vala-lint && meson build && ninja -C build
	ln -s ./vala-lint/build/src/io.elementary.vala-lint builddir/vlint

.PHONY: lint
lint: reuse black builddir/vlint
	builddir/vlint -c vala-lint.conf .
