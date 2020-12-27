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

.PHONY: run
run:
	@flatpak run \
		--command=make \
		--devel \
		org.gnome.DejaDupDevel//master \
		run-bash

.PHONY: run-bash
run-bash:
	@env \
		PKG_CONFIG_PATH=/app/lib/pkgconfig \
		make && ./tests/shell deja-dup

.PHONY: devshell
devshell:
	@flatpak run \
		--command=make \
		--devel \
		org.gnome.DejaDupDevel//master \
		devshell-bash

.PHONY: devshell-bash
devshell-bash:
	@env \
		PKG_CONFIG_PATH=/app/lib/pkgconfig \
		PS1='[📦 \W]$$ ' \
		bash --norc

.PHONY: devshell-sdk
devshell-sdk:
	flatpak remote-add --user --if-not-exists gnome-nightly https://nightly.gnome.org/gnome-nightly.flatpakrepo
	flatpak install --or-update -y gnome-nightly org.gnome.Platform//master org.gnome.Sdk//master

.PHONY: devshell-setup
devshell-setup: devshell-sdk flatpak
	@echo -e '\033[0;36mAll done!\033[0m Run "make devshell" to enter the build environment'

.PHONY: flatpak
flatpak:
	flatpak-builder --install \
	                --user \
	                --force-clean \
	                --state-dir=builddir/.flatpak-builder \
	                builddir/flatpak \
	                flatpak/org.gnome.DejaDupDevel.yaml

.PHONY: flatpak-update
flatpak-update:
	cd flatpak; \
	for p in duplicity pydrive2 requests-oauthlib setuptools-scm wheel; do \
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
