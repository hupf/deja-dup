# -*- Mode: Makefile; indent-tabs-mode: t; tab-width: 2 -*-
#
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Michael Terry

.PHONY: all
all: configure
	meson compile -C _build

%:
	@[ "$@" = "Makefile" ] || meson compile -C _build $@

.PHONY: configure
configure:
	@[ -d _build ] || meson setup -Dprofile=Devel -Denable_restic=true _build

.PHONY: check
check: all
	meson test -C _build

.PHONY: acceptance-flatpak acceptance-snap
acceptance-flatpak:
	./acceptance/run-ui-tests --flatpak ./acceptance
acceptance-snap:
	./acceptance/run-ui-tests --snap ./acceptance

.PHONY: clean
clean:
	rm -rf _build

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
		make && meson devenv -C _build deja-dup

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
	@meson devenv -C _build env \
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
	                --state-dir=_build/.flatpak-builder \
	                _build/flatpak \
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
	# Hopefully temporary fix to handle setuptools 60 and above, which duplicity doesn't vibe with yet
	sed -i 's/pip3 install/SETUPTOOLS_USE_DISTUTILS=stdlib pip3 install/g' flatpak/duplicity.yaml

.PHONY: black
black:
	black --check -t py38 --exclude _build --include 'mock/duplicity|\.py$$' .

.PHONY: reuse
reuse:
	reuse lint

_build/vlint:
	mkdir -p _build
	git clone https://github.com/vala-lang/vala-lint.git _build/vala-lint
	cd _build/vala-lint && meson build && meson compile -C build
	ln -s ./vala-lint/build/src/io.elementary.vala-lint _build/vlint

.PHONY: lint
lint: reuse black _build/vlint
	_build/vlint -c vala-lint.conf .

