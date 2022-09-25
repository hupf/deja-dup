<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: Michael Terry
-->

# Packaging Déjà Dup

If you help package Déjà Dup for a distribution, let me first say:
Thank you so much!

This guide is designed to answer your most pressing concerns.
But if you have any further questions, ask away in our [chat room][chat].

If you are merely building Déjà Dup for yourself or hacking on it to make a
patch, try reading [`CONTRIBUTING.md`](CONTRIBUTING.md) instead.

[chat]: https://matrix.to/#/#deja-dup:gnome.org

## Required Dependencies

### Build-time Libraries

You can also see these listed in [`meson.build`](meson.build), but for your
convenience:

- Adwaita 1.2
- GLib 2.70
- GTK 4.6
- JSON-GLib 1.2
- libgpg-error 1.33
- libsecret 0.18.6
- libsoup 3.0

### Duplicity

Duplicity 0.7.14 or greater is a required runtime dependency.
Duplicity itself has a wide variety of possible Python dependencies based on
its many supported backends, but we only use and require a few of them.

You'll want to depend on the following runtime dependencies for your distro:

- Duplicity itself
- GVFS and its backends (it'd be nice to ensure the `afp`, `dav`, `ftp`, `nfs`,
  `sftp`, and `smb` backends at least are installed)
- The Python module `gi` along with the typelibs for `Gio` and `GLib`
  (all of which are usually provided by the `pygobject` project)
- The Python module `pydrive2`
- The Python module `requests_oauthlib`

## Optional Dependencies

### Restic

Restic is an alternative backup tool (instead of Duplicity) for which Déjà Dup
has experimental support. It is not enabled by default.

Eventually, we may use it for some advanced features that Duplicity can't
provide, like changing the encryption password or more fine-tuned storage
management.

Once enabled, users still have to opt-into the feature, with a big warning
about its experimental nature.
Thus, it should be safe to enable.
I'd love it if you could, so that I get more user testing and feedback.

Here's how you enable it as an opt-in feature for users:

- Set `-Denable_restic=true` when building
- Depend on `restic` 0.14.0
- Depend on `rclone`

### PackageKit

Some runtime dependencies may be difficult for you to directly depend on.
As an example, let's say that you're packaging Déjà Dup for Ubuntu and some
dependencies are in `universe`, but `deja-dup` itself is in `main` (which is
the actual historical impetus for this feature). You couldn't just directly
depend on those `universe` dependencies from a `main` package.

However, if you enable PackageKit support, Déjà Dup can prompt the user to
install missing dependencies on the fly, relatively seamlessly as part of the
backup or restore process.

This is disabled by default because it is not the preferred user experience.
Users may reasonably get weirded out by apps that are "missing" dependencies or
that ask for permission to install "arbitrary" packages.
That's not a typical thing for a user to see and might make them distrust their
backup software (which is normally supposed to be a secure and trustworthy
guardian of their data).

But if you need this, it's easy to enable:

- Add `libpackagekit-glib2` as a build dependency
- Set `-Dpackagekit=enabled` when building
- Set any or all of the following option flags. If you need multiple packages
  for a single option, separate their names with commas.
    - `duplicity_pkgs`: defaults to `duplicity`
    - `gvfs_pkgs`: specify packages for GVFS as well as the `gi` Python module,
      **no default**
    - `pydrive_pkgs`: either the `pydrive2` Python module or the unmaintained
      `pydrive` one, **no default**
    - `rclone_pkgs`: defaults to `rclone`
    - `requests_oauthlib_pkgs`: the `requests_oauthlib` Python module,
      **no default**
    - `restic_pkgs`: defaults to `restic`

An example for a Debian-style distro:

```
-Dpackagekit=enabled
-Dgvfs_pkgs=gvfs-backends,python3-gi
-Dpydrive_pkgs=python3-pydrive2
-Drequests_oauthlib_pkgs=python3-requests-oauthlib
```

## Dependencies Outside of PATH

If your distro installs packages in non-standard locations or with non-standard
names, you can still tell Déjà Dup where to find them.

For example, NixOS does not even have a global `/usr/bin`, instead installing
packages in namespaced directories for parallel installation.
Or maybe the Duplicity command gets installed as `duplicity.bin` on your distro.
I don't judge.

That's easy to tell us about. Just set the following option flags:

- `duplicity_command`
- `rclone_command`
- `restic_command`

Absolute paths will be used directly, while bare command names will be searched
for in `PATH`.

An example:

```
-Dduplicity_command=/opt/duplicity/bin/duplicity
```

## Monitoring for New Releases

All releases and tarballs can be found as [tags][tags] on our source repository
in GitLab.

If any packaging changes happen, they will always be mentioned in the release
notes (on the GitLab tag and in [`NEWS.md`](NEWS.md)).

Version numbers follow [GNOME style][versions] (but not their release schedule).
So a notable new release (like a redesigned UI or new dependencies) will get a
bumped major version number.
For example, we went from 43 to 44 because we bumped Adwaita's minimum version
and changed how a build option worked.
Development releases will look like 44.alpha and 44.beta (though not every
major release will bother with a full alpha/beta test cycle).

[tags]: https://gitlab.gnome.org/World/deja-dup/tags
[versions]: https://discourse.gnome.org/t/new-gnome-versioning-scheme/4235
