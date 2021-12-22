<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: Michael Terry
-->

# Building from a Source Release

This is recommended if you are a downstream packager of stable releases.

If you have downloaded this source from a tarball release (that is, a file like `.tar.bz2` or `.zip`),
you can use standard meson commands like:
 * `meson --buildtype=release my-build-directory`
 * `meson compile -C my-build-directory`

See the [meson documentation](https://mesonbuild.com/) for more guidance. And look at `meson_options.txt` for all the extra build options you can set.

# Building from a Git Clone

This is recommended if you intend to contribute back a patch. Git checkouts include a `Makefile` that make setting up a sandboxed development environment easier.

## Set Up the GNOME SDK

To make sure you can build against the latest GNOME libraries, it helps to install the GNOME SDK.

1. [Install flatpak](https://flatpak.org/setup/).
1. `make devenv-setup`
1. `make devenv`

Now you're inside a flatpak container (org.gnome.DejaDupDevel) with all dependencies installed.
Plus an environment pointed at any built data and executables.

## Building

 * To build: `make`
 * To install: `make install DESTDIR=/tmp/deja-dup`

# Folder Layout
 * libdeja: non-GUI library that wraps policy and hides complexity of duplicity
 * app: GNOME UI for libdeja
 * monitor: the deja-dup-monitor user daemon
 * data: shared schemas, icons, etc

# Testing

From inside a devenv shell, you can iterate as you develop by just running `deja-dup` directly.

* Running all unit tests: `meson test -C _build`
* Running one unit test: `meson test script-threshold-inc -C _build -v`

# Copyright

If you are making a [substantial patch](https://www.gnu.org/prep/maintain/html_node/Legally-Significant.html) (adding ~15 lines or more), add yourself to the top of the file in a new copyright line.

# Project Assets

If the maintainers get hit by a bus, these are the various pieces of the administrative puzzle:

* [Main project page](https://gitlab.gnome.org/World/deja-dup)
* [Homepage / wiki](https://wiki.gnome.org/Apps/DejaDup)
* [Discourse tag](https://discourse.gnome.org/tag/deja-dup)
* [Snap packaging](https://github.com/deja-dup/snap) (plus the store account)
* [Flathub packaging](https://github.com/flathub/org.gnome.DejaDup)
* Google Drive API account (client ID is in `meson_options.txt`)
* Microsoft OneDrive API account (client ID is in `meson_options.txt`)
* dejadup.org domain (redirects to wiki above, only currently used for our Google API account, which requires a domain)
* [Liberapay team](https://liberapay.com/DejaDup)
* [Old project page](https://launchpad.net/deja-dup)
