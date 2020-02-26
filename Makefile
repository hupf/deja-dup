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

.PHONY: pot
pot: configure
	ninja -C builddir deja-dup-pot help-deja-dup-pot
	@sed -i 's/This file is distributed under the same license as the deja-dup package./SPDX-License-Identifier\: GPL-3.0-or-later/' po/deja-dup.pot
	@sed -i '1i# SPDX-License-Identifier\: CC-BY-SA-4.0\n# SPDX-FileCopyrightText\: Michael Terry\n' help/deja-dup.pot

.PHONY: translations
translations: pot
	mkdir -p builddir
	rm -rf builddir/translations
	bzr co --lightweight lp:~mterry/deja-dup/translations builddir/translations
	cp -a builddir/translations/po/*.po po
	cp -a builddir/translations/help/*.po help
	@sed -i 's/This file is distributed under the same license as the deja-dup package./SPDX-License-Identifier\: GPL-3.0-or-later/' po/*.po
	@sed -i 's/This file is distributed under the same license as the deja-dup package./SPDX-License-Identifier\: CC-BY-SA-4.0/' help/*.po
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
	for p in duplicity pydrive; do \
		../flatpak-builder-tools/pip/flatpak-pip-generator --output flatpak/$$p $$p; \
		../flatpak-builder-tools/flatpak-json2yaml.py -f --output flatpak/$$p.yaml flatpak/$$p.json; \
		rm flatpak/$$p.json; \
		sed -i '1i# SPDX-License-Identifier\: GPL-3.0-or-later\n# SPDX-FileCopyrightText\: Michael Terry\n---' flatpak/$$p.yaml; \
	done

builddir/vlint:
	mkdir -p builddir
	git clone https://github.com/vala-lang/vala-lint builddir/vala-lint
	cd builddir/vala-lint && meson build && ninja -C build
	ln -s ./vala-lint/build/src/io.elementary.vala-lint builddir/vlint

.PHONY: lint
lint: builddir/vlint
	builddir/vlint -c vala-lint.conf .
	reuse lint
