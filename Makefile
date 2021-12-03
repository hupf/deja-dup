# -*- Mode: Makefile; indent-tabs-mode: t; tab-width: 2 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

.PHONY: all
all: configure
	meson compile -C builddir

%:
	@[ "$@" = "Makefile" ] || meson compile -C builddir $@

.PHONY: configure
configure:
	@[ -d builddir ] || meson setup -Dprofile=Devel -Denable_restic=true builddir

.PHONY: check
check: all
	meson test -C builddir

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
		--talk-name=com.feralinteractive.GameMode \
		--talk-name=org.freedesktop.Notifications \
		org.gnome.DejaDupDevel//master \
		run-bash

.PHONY: run-bash
run-bash:
	@env \
		PKG_CONFIG_PATH=/app/lib/pkgconfig \
		make && meson devenv -C builddir deja-dup

.PHONY: devenv
devenv:
	# Owns org.gnome.DejaDup so that we can run non-devel builds too
	@flatpak run \
		--command=make \
		--devel \
		--own-name=org.gnome.DejaDup \
		--talk-name=com.feralinteractive.GameMode \
		--talk-name=org.freedesktop.Notifications \
		org.gnome.DejaDupDevel//master \
		devenv-bash

.PHONY: devenv-bash
devenv-bash:
	@env PKG_CONFIG_PATH=/app/lib/pkgconfig make configure
	@meson devenv -C builddir env \
		-C `pwd` \
		PKG_CONFIG_PATH=/app/lib/pkgconfig \
		PS1='[📦 \W]$$ ' \
		bash --norc

.PHONY: devenv-sdk
devenv-sdk:
	flatpak remote-add --user --if-not-exists gnome-nightly https://nightly.gnome.org/gnome-nightly.flatpakrepo
	flatpak install --or-update -y gnome-nightly org.gnome.Platform//master org.gnome.Sdk//master

.PHONY: devenv-setup
devenv-setup: devenv-sdk flatpak
	@echo -e '\033[0;36mAll done!\033[0m Run "make devenv" to enter the build environment'

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
	for p in borgbackup "setuptools-scm duplicity" "cryptography<3.4 pydrive2" requests-oauthlib; do \
		name=$$(echo $$p | grep -oE '[^[:space:]]+$$'); \
		echo $$name; \
		../../flatpak-builder-tools/pip/flatpak-pip-generator --runtime org.gnome.Sdk//master --output $$name $$p; \
		../../flatpak-builder-tools/flatpak-json2yaml.py -f --output $$name.yaml $$name.json; \
		rm $$name.json; \
		sed -i '1i# SPDX-License-Identifier\: GPL-3.0-or-later\n# SPDX-FileCopyrightText\: Michael Terry\n---' $$name.yaml; \
	done

.PHONY: black
black:
	black --check -t py38 --exclude builddir --include 'mock/duplicity|\.py$$' .

.PHONY: reuse
reuse:
	reuse lint

builddir/vlint:
	mkdir -p builddir
	git clone https://github.com/vala-lang/vala-lint.git builddir/vala-lint
	cd builddir/vala-lint && meson build && meson compile -C build
	ln -s ./vala-lint/build/src/io.elementary.vala-lint builddir/vlint

.PHONY: lint
lint: reuse black builddir/vlint
	builddir/vlint -c vala-lint.conf .

