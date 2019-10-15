# Set Up the GNOME SDK

To make sure you can build against the latest GNOME libraries, it helps to install the GNOME SDK.

1. [Install flatpak](https://flatpak.org/setup/).
1. `flatpak remote-add --if-not-exists gnome-nightly https://nightly.gnome.org/gnome-nightly.flatpakrepo`
1. `flatpak install gnome-nightly flatpak org.gnome.Sdk//master`
1. `make devshell`

# Building

deja-dup uses meson, but for most development purposes, you can simply use the convenience top-level Makefile:
 * To build: `make`
 * To install: `make install DESTDIR=/tmp/deja-dup`

# Folder Layout
 * libdeja: non-GUI library that wraps policy and hides complexity of duplicity
 * deja-dup: GNOME UI for libdeja, including a nautilus plugin
 * data: shared schemas, icons, etc

# Testing

When manually testing a change, it is helpful to run `./tests/shell` (or `shell-local` if you want a silo'd dbus environment too)
That will give you a full shell pointing at all your built executables.

* Running all tests: `make check`
* Running one test: `meson test script-threshold-inc -C builddir/ -v`
