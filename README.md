<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: Michael Terry
-->

# Déjà Dup Backups

Déjà Dup is a simple backup tool. It hides the complexity of backing up the
Right Way (encrypted, off-site, and regular) and uses
[duplicity](https://duplicity.gitlab.io/) as the backend.

 * Support for local, remote, or cloud backup locations such as Google Drive
 * Securely encrypts and compresses your data
 * Incrementally backs up, letting you restore from any particular backup
 * Schedules regular backups
 * Integrates well into your GNOME desktop

Déjà Dup focuses on ease of use and personal, accidental data loss.
If you need a full system backup or an archival program, you may prefer other
backup apps.

## ⚠️ Fork ⚠️

This is a fork of the [official Déjà Dup](https://gitlab.gnome.org/World/deja-dup) app, that supports a Duplicity
exclude file, which is considered when present at
`~/.config/deja-dup-excludes`. This file may contain multiple file
glob patterns such the following example:

```
/home/john/**/node_modules
/home/john/**/log
/home/john/**/tmp
```

For more context, checkout the following discussion:
https://gitlab.gnome.org/World/deja-dup/-/issues/112

To test and run locally, excecute:

```
# Only once initially:
apt install flatpak-builder
make devenv-setup

# Then:
make devenv

# And within the dev env:
make
deja-dup
```

To install (will create launcher icon):

```
make flatpak
```


## Building

If you are hacking on Déjà Dup, see [CONTRIBUTING.md](CONTRIBUTING.md).

Or if you are packaging Déjà Dup for a distribution, see
[PACKAGING.md](PACKAGING.md) for extra tips.

## Links

 * [Homepage](https://wiki.gnome.org/Apps/DejaDup)
 * [Download](https://wiki.gnome.org/Apps/DejaDup/Download)
 * [Get involved](https://wiki.gnome.org/Apps/DejaDup/GettingInvolved)
 * [Chat room](https://matrix.to/#/#deja-dup:gnome.org)
 * [Forums](https://discourse.gnome.org/tags/c/applications/7/deja-dup)

