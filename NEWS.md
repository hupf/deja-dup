<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: Michael Terry
-->

# 46.0

##### Packaging
- Require duplicity 2.0.0
- Duplicity cloud support will now be provided by Rclone (like we do when
  using Restic)
  - Meson options `pydrive_pkgs` and `requests_oauthlib_pkgs` are both
    deprecated and ignored
  - You can remove any runtime dependencies for pydrive or oauthlib
  - You should add a runtime dependency on `rclone`

# 45.2
- Fix not being prompted for packagekit installs during a restore
- Allow using the '~/' alias for the home dir in more text entries
- Add clearer error message when auto-backups can't be set in flatpak mode
- Fix compilation on non-glibc systems
- Updated translations

# 45.1
- Fix compilation with valac 0.56 - 45.0 accidentally require the unreleased
  0.57 branch (sorry!)

# 45.0
- Use the modern flat header style
- Use latest Gtk file dialog
- Fix a vague SMB error into a more specific one (thanks Fina Wilke)
- Updated Basque, Catalan, Chinese (China), Czech, Danish, Dutch, Finnish,
  Galician, Georgian, German, Hebrew, Hungarian, Indonesian, Persian, Polish,
  Russian, Slovak, Slovenian, Swedish, Turkish, and Ukrainian translations

##### Packaging
- Require gtk4 4.12+
- Require libadwaita1 1.4+
- Require meson 0.64+

# 44.2
- Support duplicity 2.0's command line changes
- Update OneDrive api key to work with Duplicity 1.2.3 by using a key that
  allows both personal and business accounts (business untested so far).
  This means folks will need to re-authorize deja-dup, unfortunately.
- Add more details to the error message about not enough space
- Fix not being able to open the preferences window after a restore
- Updated Basque, Friulian, Georgian, German, Hebrew, Hungarian, Indonesian,
  Occitan, Persian, Polish, Portuguese, Russian, Serbian, Slovenian, Swedish,
  Turkish, and Ukrainian translations

# 44.1
- Refuse to back up to a destination that doesn't have enough space, and
  suggest how much more space is needed
- Fix Trash location when run as a flatpak
- Don't try to back up when the network is behind a wifi captive portal
- New Interlingue translation
- Updated Basque, Belarusian, Brazilian Portuguese, Croatian, Danish, Finnish,
  Friulian, Georgian, German, Hebrew, Hungarian, Indonesian, Korean, Occitan,
  Persion, Polish, Portuguese, Russian, Slovenian, Spanish, Swedish, Turkish,
  and Ukrainian translations

# 44.0
- Refresh the visuals in a few places by using modern text entries and the
  new About dialog
- Newly created restic backups will now use compression
- Fix a bug that prevented updating the folder option in the Preferences
  window after changing to an external disk
- Fix a bug that prevented switching to the restore view if the app starts
  up in mobile mode (thin width)
- Update Basque, Brazilian Portuguese, Catalan, Chinese (China), Croatian,
  Danish, Dutch, Finnish, French, German, Hebrew, Hungarian, Indonesian,
  Korean, Polish, Portuguese, Russian, Serbian, Slovenian, Swedish, Turkish,
  and Ukrainian translations

##### Packaging
- There is now some documentation about how to package deja-dup in
  [PACKAGING.md](PACKAGING.md) - walking through required & optional
  dependencies and build options
- Add new `-Dpackagekit=enabled` option flag to control whether we build with
  PackageKit support. Previously, this was an `auto` feature without an option
  flag to control it, but is now `disabled` by default and you can explicitly
  enable it if your packaging cannot directly depend on runtime dependencies
  like duplicity. If you do enable this, read the above doc for a list of other
  `pkgs` options to set as well.
- Require libadwaita1 1.2+
- If you enable restic, we now require restic 0.14+

# 43.4
- Warn about delayed backups due to power saver mode, if it's been over a day
  since we were supposed to back up
- Improve support for mobile screen sizes
- Add some in-preferences help explaining some of the always-ignored folders
- Bump default volume size from 25/50MB to 200MB, to keep fewer files around
  and improve network throughput
- Minor fixes to our experimental restic support (make sure to unlock the repo
  and warn if some files could not be read when backing up)
- Update Brazilian Portuguese, Chinese (China), French, German, Hebrew,
  Occitan, Persian, Polish, Portuguese, Russian, Swedish, and Ukrainian
  translations

# 43.3
- Change Google/Microsoft authentication flow to use a more secure,
  non-deprecated approach (Google is turning off the approach we use now in
  just a few months)
- Remember window size after closing
- Fix incorrect file permissions / mtime when restoring files from other users
- Update Basque, Brazilian Portuguese, Catalan, Chinese (China), Croatian,
  Danish, Dutch, Finnish, French, Galician, Hebrew, Hungarian, Indonesian,
  Italian, Japanese, Occitan, Persian, Polish, Portuguese, Russian, Serbian,
  Slovenian, Spanish, Swedish, Turkish, Ukrainian, and Vietnamese translations

##### Packaging
- Heads up that the above-mentioned authentication flow changes require
  registering custom mimetypes so that the browser can launch deja-dup to give
  us the authentication token after the user allows it (these mimetypes look
  like 'x-scheme-handler/com.google...' or 'x-scheme-handler/msal...' with
  identifiers specific to deja-dup's client ids for each service)
- Fix building against recent meson and vala (0.56.1+) releases

# 43.2
- Fix a crash if you select a mount in the Local Folder settings file chooser
- Fix the "hostname has changed" dialog to let you actually continue the backup
- Fix a bogus notification that complained about not being connected to the
  network for scheduled backups to Network Servers, even if you were connected
- Make replacing existing monitor processes during upgrade work better
- Add a hidden advanced setting to run setup/teardown commands when running
  the backup tool (useful if you have an unusual manual mount you need)
- Update Chinese (China), Chinese (Taiwan), Czech, Russian, and Ukrainian
  translations

# 43.1
- Increase default window size to avoid being too small

##### Packaging
- Require libsoup-3.0 (instead of libsoup-2.4) - sorry, I agree that it's
  rude to bump a dependency like this in a minor stable release, but I wanted
  to squeeze this in before too long, to help future proof the 43.x line.

# 43.0
This is a stable release, following 43.alpha and 43.beta in the GNOME style.
Previously, odd number releases were the development releases, but no longer.

##### Changes Since 43.beta
- Fix the restore browser not asking any user questions during mount (like an
  invalid ssl cert)
- Use dark mode if color schemes are not supported by the system, but the gtk
  theme is a dark variant
- Minor UI spacing/style tweaks
- Update Basque, Friulian, Occitan, Portuguese, Russian, and Serbian
  translations

##### New Features Since 42.x
- Add support for Microsoft OneDrive
- Delay scheduled backups when Power Saver mode or GameMode are enabled
- Add opt-in experimental support for using Restic

##### Required Packaging Changes Since 42.x
- Require libadwaita1 1.0+ (instead of libhandy1)
- Require gtk4 4.6+ (instead of gtk3)
- Require glib2 2.66+
- Require meson 0.59+
- Due to new support for Microsoft OneDrive:
  - Require the `requests_oauthlib` python module
  - If you can't hard-depend on it, define the new `requests_oauthlib_pkgs`
    config flag if building with packagekit support
  - This feature will only be visible if duplicity 0.8.21+ is available

##### Optional Packaging Changes Since 42.x
- For experimental Restic support:
  - New config flag `enable_restic`, which you can set to `true` to turn on
    the new experimental support for Restic. This will not use Restic by
    default, but merely expose a new "Labs" panel in the preferences window
    where users can opt-in. So it is safe to enable and helps us get feedback.
  - Require the `restic` and `rclone` packages
  - New config flags `restic_pkgs` and `rclone_pkgs`, if you can't hard-depend
    on the restic or rclone packages and are building with packagekit support
  - New config flags `restic_command` and `rclone_command`, where you can
    override the path to the restic and rclone executables (defaults to
    searching `PATH`)

# 43.beta
This is a beta release for the upcoming 43.0. No further feature changes are
planned. 43.0 will come out sometime during the GNOME 42 window, so if your
distro version will include GNOME 42, this is safe to package.

##### New Since 43.alpha
- Add two- and three-day schedule options to the preferences window
- More aggressively replace old existing monitor processes when launching
- When scanning duplicity output for gpg error messages, also look for the
  English version of error strings (in addition to the current language), as
  it is possible the installed languages of Deja Dup and gpg could be different
- Update Brazilian Portuguese, Croatian, Finnish, German, Japanese, Occitan,
  Persian, Polish, Slovak, Slovenian, Swedish, Turkish, and Ukrainian
  translations

##### Required Packaging Changes Since 42.x
- Require libadwaita1 1.0.0.alpha.4+ (instead of libhandy1)
- Require gtk4 4.4+ (instead of gtk3)
- Require glib 2.66+
- Require meson 0.59+
- Due to new support for Microsoft OneDrive:
  - Require the `requests_oauthlib` python module
  - If you can't hard-depend on it, define the new `requests_oauthlib_pkgs`
    config flag if building with packagekit support
  - This feature will only be visible if duplicity 0.8.21+ is available

##### Optional Packaging Changes Since 42.x
- For experimental Restic support:
  - New config flag `enable_restic`, which you can set to `true` to turn on
    the new experimental support for Restic. This will not use Restic by
    default, but merely expose a new "Labs" panel in the preferences window
    where users can opt-in. So it is safe to enable and helps us get feedback.
  - Require the `restic` and `rclone` packages
  - New config flags `restic_pkgs` and `rclone_pkgs`, if you can't hard-depend
    on the restic or rclone packages and are building with packagekit support
  - New config flags `restic_command` and `rclone_command`, where you can
    override the path to the restic and rclone executables (defaults to
    searching `PATH`)

# 43.alpha
- Add support for Microsoft OneDrive
- Delay scheduled backups when Power Saver mode or GameMode are enabled
- Add opt-in experimental support for using Restic
- Refresh the UI in various places
- Update Basque, Brazilian Portuguese, Catalan, Chinese (China), Danish, Dutch,
  Finnish, Friulian, Galician, German, Hungarian, Indonesian, Italian,
  Japanese, Occitan, Polish, Romanian, Russian, Serbian, Slovenian, Spanish,
  Swedish, Turkish, and Ukrainian translations

##### Packaging
- **A note on versioning:** Déjà Dup has switched to a GNOME-style version
  scheme, with a .alpha and .beta leading to a .0 stable release, instead of
  the previous odd/even scheme. So this 43.alpha release is leading towards a
  stable 43.0 release. Déjà Dup still doesn't follow the GNOME release
  schedule, just their versioning style.
- **A note on this release:** You probably should not package this release for
  your distro, even in a testing capacity. It wants an unreleased duplicity and
  needs an unreleased libadwaita. This is truly a bleeding edge alpha release,
  mostly to get community testing.
- Switch from gtk3 to gtk4
- Switch from libhandy1 to libadwaita1
- Require meson 0.58+
- Require gtk4 4.4+
- Require glib 2.66+
- For Microsoft OneDrive support:
  - OneDrive will need to use the `requests_oauthlib` python module. So please
    either have your packaging depend on it, or define the new
    `requests_oauthlib_pkgs` config flag if building with packagekit
    support.
  - New config flag `microsoft_client_id` (you likely don't want to change this
    from its default)
- For experimental Restic support:
  - New config flag `enable_restic`, which you can set to `true` to turn on
    the new experimental support for Restic. This will not use Restic by
    default, but merely expose a new "Labs" panel in the preferences window
    where users can opt-in.
  - New config flag `restic_command`, where you can override the path to the
   `restic` executable (defaults to searching `PATH` for `restic`)
  - New config flag `restic_pkgs`, if you are building with packagekit support
    and don't want to depend on the restic package.
  - New config flag `rclone_command`, where you can override the path to the
   `rclone` executable (defaults to searching `PATH` for `rclone`). Rclone is
    used by the new Restic backend to connect to cloud storage providers.
  - New config flag `rclone_pkgs`, if you are building with packagekit support
    and don't want to depend on the rclone package.

# 42.8
- Fix not prompting for the encryption password during a scheduled backup if
  the previous scheduled backup's prompt was ignored. This would have the
  practical effect of disabling scheduled backups after the first ignored
  prompt of each login session, if you don't keep your password saved.
- Update Basque, Dutch, Hungarian, Indonesian, Italian, Occitan, Romanian,
  Russian, Serbian, and Spanish translations

# 42.7
- Fix descending into a directory while searching in the browse & restore view
- Update Google Drive logo
- Update Japanese and Swedish translations

##### Packaging
- Update to libhandy-1. This is probably an overdue, welcome change, so I'm not
  bothering to bump our major version for this dependency change.

# 42.6
- Fix possible crash when searching backup files with unicode filenames
- Exclude snap and flatpak cache files (fixed regression that stopped doing this)
- Show backup times in local timezone, not UTC
- Handle a symlinked ~/.cache/deja-dup folder
- Bump default network timeout to cover flaky connections/services better
- Update Brazilian Portuguese, Danish, Esperanto, Friulian, and German
  translations

# 42.5
- Fix "Resume later" from resetting your backup schedule
- Fix difficulty in selecting an internal drive as your storage location when
  using the file browser dialog
- Fix using "/" as an included folder being ignored
- Fix silently refusing to restore filenames with illegal characters to a FAT
  filesystem; we now show an error
- Fix restoring filenames with an apostrophe followed by a space (`' `) in them
- Always exclude ~/.cache, even if its not our current cache folder
- Clarify deletion policy (that it can take up to three months longer than
  you might think) and allow a deletion policy of 3 months (previously 6 months
  was earliest allowed policy, which could mean up to 9 months)
- Update French, Friulian, Indonesian, Polish, and Ukranian translations

# 42.4
- Fix regression in 42.3 that prevented restoring from removable drives
- Update Japanese, Slovak, and Spanish translations

# 42.3
- Fix support for scheduled backups for encrypted drives
- On a fresh install, use the browse & restore interface when restoring from
  a previous backup (rather than requiring a full restore)
- Show desktop notifications if we need user attention during a backup, rather
  than trying to mark window as visible and urgent, since notifications work in
  more desktop environments and wayland
- Inhibit suspend and logout during manual backups and restores
- Add debug info screen, visible from the About dialog
- Don't warn user about folders that are explicitly excluded
- Exclude /dev by default
- Update Basque, Brazilian Portuguese, Catalan, Finnish, German, Japanese,
  Polish, Spanish, Turkish, and Ukrainian translations

##### Packaging
- Add new -Dduplicity_command argument (defaulting to "duplicity"), useful if
  you have a duplicity install isn't normally in PATH

# 42.2
- Mount partitions specified in /etc/fstab if necessary
- When selecting an internal drive as a Local Folder, treat it as a removable
  drive, so that we will mount if necessary
- If using a flatpak install and we can't run in the background, tell the
  user how to fix it
- Update Brazilian Portuguese, Catalan, German, Japanese, Polish, and Ukrainian
  translations

# 42.1
- Fix automatic backups not firing for removable storage drives, which got
  broken during the 41.x development cycle
- Automatically exclude folders that follow the cachedir spec (i.e. that have a
  CACHEDIR.TAG file in them), and same if they have a .deja-dup-ignore file
- Use a symbolic back icon in header (vs a full color icon)
- Stop the restore confirmation screen from growing too big if you are
  restoring a lot of files
- Update Polish, Romanian, and Ukrainian translations

# 42.0
- Updated translations

#### Changes since 40.7

- Redesign the main window and preferences to follow GNOME design patterns
- Add welcome state for first time use (with slightly guided backup/restore)
- Add an in-app browse & restore interface
- Drop nautilus plugin, in preference of above new browse interface
- Drop deprecated backends (GOA, S3, GCS, OpenStack, and Rackspace)
- Use "Déjà Dup Backups" instead of "Déjà Dup Backup Tool" as full name
- Drop "Version" key from desktop files, which broke some parsers
- Adds a button to reset your Google authorization in the preferences
- Warn users before they restore files that we can't write to

##### Packaging
- Add required libhandy-0.0 dependency
- Bump minimum glib version to 2.64
- Drop optional goa-1.0 dependency
- Drop optional libnautilus-extension dependency
- Drop boto_pkgs, cloudfiles_pkgs, and swiftclient_pkgs meson options

# 41.3
This is a development release leading up to 42.0.

- Warn users before they restore files that we can't write to
- When restoring files to a specific folder, just drop them all in that folder,
  without their full subtree path
- Mark symlinks in restore browser
- Updated translations

# 41.2
This is a development release leading up to 42.0.

- Fixes bug preventing some restores using the new browser
- Adds a button to reset your Google authorization in the preferences
- Updates look of progress dialogs to be a little less crowded
- Fixes missing icons for unrecognized file types when using the Adwaita theme
- Updated help documentation
- Updated translations

# 41.1
This is a development release leading up to 42.0.

- Add welcome state for first time use (with slightly guided backup/restore)
- Add an in-app browse & restore interface
- Drop nautilus plugin, in preference of above new browse interface
- Updated translations

##### Packaging
- Drop optional libnautilus-extension dependency

# 41.0
This is a development release leading up to 42.0.

- Drop deprecated backends (GOA, S3, GCS, OpenStack, and Rackspace)
- Redesign the main window and preferences to follow GNOME design patterns
- Use "Déjà Dup Backups" instead of "Déjà Dup Backup Tool" as full name
- Drop "Version" key from desktop files, which broke some parsers
- Updated translations

##### Packaging
- Add required libhandy-0.0 dependency
- Bump minimum glib version to 2.64
- Drop optional goa-1.0 dependency
- Drop boto_pkgs, cloudfiles_pkgs, and swiftclient_pkgs meson options
- appstream-util, dbus-run-session, and desktop-file-validate are now optional
  during build if you don't intend to run tests

# 40.7
- Fixes a bug that prevented restoring from Google Drive accounts if you haven't
  backed up yet
- Drop "Version" key from desktop files, which broke some parsers

##### Packaging
- appstream-util, dbus-run-session, and desktop-file-validate are now optional
  during build if you don't intend to run tests

# 40.6
- Fixes a bug that prevented backing up to Google Drive accounts with unlimited
  quotas
- Updated translations

# 40.5
- Fix a bug that prevented backing up to Google Drive in some rare situations
- Update translations

# 40.4
- Fix a bug that prevented the first login to Google Drive
- Update translations

# 40.3
- Fix a bug that prevented resuming a full backup
- Update translations

# 40.2
- Fix 2038 date problems by using 64-bit dates internally
- Update translations

## Packaging
- Fix building against `valac` 0.45.2 and later
- Require `glib` 2.56
- Require `meson` 0.47
- Add optional dependency on `libgdk-x11-3.0` (only used in flatpak builds)
- Make `libgoa-1.0` an optional dependency (still recommended for a few years
  though)

## Flatpak
- Support autostarting via the new Background portal

# 40.1
- Fix versioning to be correct

# 40.0
- Fix tests when run under glib 2.60

# 39.1
This is a development release leading up to 40.0.

- Fix a bug that could have caused backups to be encrypted with two different
  passwords in some cases. This would result in difficulty backing up or
  restoring by not accepting the password you expected it to.
- Fix a bug that caused duplicate save or exclude folders to appear in the
  preferences.
- Delete a canary file that duplicity's pydrive puts in your Drive.
- If you don't ask for your password to be saved, we now clear out any older
  saved password.
- Finally delete the ancient Ubuntu One backend code.

# 39.0
This is a development release leading up to 40.0.

- Switch away from GNOME Online Accounts to our own cloud keys
    - It was brought to our attention that we shouldn't be using GNOME's keys,
      as they are intended for GNOME only.
    - Google accounts will have to be re-authenticated with our keys.
    - Nextcloud accounts will now appear as webdav network server accounts.
    - Adds new `pydrive_pkgs` option to list the package names needed for the
      pydrive duplicity backend (for now, the system package that provides the
      `pydrive` python2 package should suffice).
    - Adds new `google_client_id` option if you want to override our default
      account key and use your own. You likely won't want to do this.
    - Adds new dependencies on `libjson-glib` and `libsoup`.
    - Drops `libgoa-backend` dependency. The `libgoa` dependency will stay
      during a transition period from the old keys to the new keys.
- Unmount a remote backup location when we are done with it, if we originally
  mounted it.

# 38.4
- Update app icon
- Don't run monitor when automatic backups are disabled
- Drop libpeas dependency
- Fix compilation with valac 0.43
- Be more forgiving if packagekit is unresponsive
- Update translations

# 38.3
- Allow restoring from paths with symlinks in more situations (including a fix
  for a backup error when ~/.cache is a symlink)
- Treat operation dialogs more like real dialogs (modal to preference window,
  with correct styling on default buttons)
- Try harder to stop running duplicity commands when we are terminated
- Don't hide an error message when also running our bimonthly backup
  verification
- If there isn't enough space in the backup location, tell the user how much
  is needed
- Exclude flatpak cache directories by default

# 38.2
- Fix not being able to find the backup files when restoring on a fresh install

# 38.1
- Use a primary menu instead of an AppMenu, per current GNOME
  recommendations (thanks Jeremy Bicha)
- Drop support for the legacy desktop status icon
- Update translations

# 38.0
- Drop ulimit for monitor process, it was causing crashes
- Fix autoscrolling in progress window
- Exclude snap cache directories by default
- Update translations

# 37.1
- Fix crash when restoring missing files
- Clarify the error message when trying to use an smb server without a share name
- Update translations

# 37.0
- Add new Google Drive backend and make it the new default backend
- Update translations

# 36.3
- Fix the restore dialog sometimes being blank
- Update translations

# 36.2
- Fix crash when trying to restore missing files
- Fix the UI from freezing for a second when mounting the backend location
- Update translations

# 36.1
- Fix backing up to external drives
- Update translations

# 36.0
- Use sh instead of bash in monitor's autostart command
- Avoid an error when trying to mount a null GFile
- Update translations

# 35.6
- Fix warnings about not starting an automatic backup because the location is already mounted
- Try to work around the monitor daemon leaking memory by limiting how much memory it can consume
- Fix settings being read-only if the user first opens a restore window then opens the preferences window before the restore finishes
- Update translations

# 35.5
- Fix a bug when restoring missing files that caused not every older missing files to be shown
- Work around a couple distro oddities when installing backend dependencies on the fly
- When testing backup every two months, keep dialog visible so the user can see any positive results
- Fix a few minor bugs
- Depend on libgpg-error
- Update translations

# 35.4
- Support GNOME Online Accounts (Nextcloud only so far)
- Don't show non-GOA cloud accounts by default (they still show up for existing users or when set manually in gsettings)
- Unify the settings pages for remote network servers, making it look more like nautilus
- Add a nicer prompt message when asking to run duplicity as root
- Allow even more of the optional dependencies for backends to be installed at run time. Packagers, you can now specify several meson variables to tell deja-dup which packages will let various duplicity backends to work.
- Fix a few minor bugs
- Update translations

# 35.3
- Fix handling of some unicode filenames
- Fix accuracy of checking whether some servers are reachable
- Fix server password dialog giving an error if you waited a while before logging in
- Don't start an automatic backup on a metered connection
- Add About and Keyboard Shortcuts dialogs
- Ignore ~/.ccache by default
- Update translations
- Require GTK+ 3.22 and glib 2.46

# 35.2
- Fix nautilus crash caused by our extension
- Fix nautilus extension not working on some files with special characters
- Add F1 and Ctrl+Q accelerators

# 35.1
- Fix progress window header color
- Make Restore/Backup button sensitivity more reliable

# 35.0
- Fix preferences window opening on the wrong page
- Improve notification support in GNOME3
- Remove special support for Unity
- Switch from cmake to meson
- Require GTK+ 3.10, glib 2.42, and valac 0.36
- Drop dependency on libnotify
- Drop deja-dup-preferences binary, that functionality is now inside the main deja-dup binary

# 34.4
- In MATE, call the file manager Caja, not Files
- Fix documentation and strictness of using xdg location variables in gsettings include/exclude keys
- Don't show control center panel in Unity8
- Translation updates

# 34.3
- Fix a bug that allowed an incorrect password when making a new full backup
- Translation updates

# 34.2
- Fix parsing of some utf8 filenames that prevented restoring files
- Translation updates

# 34.1
- Add experimental support for Google Cloud Storage, please test and file bugs
- Add experimental support for OpenStack Swift, please test and file bugs
- Fix a bug where the error dialog wasn't visible after a failed backup in GNOME
- Fix a bug where background backups were using smaller 'nice' values than they should have
- Drop support for building the GNOME Control Center plugin; upstream hasn't supported that for a while, and Ubuntu finally dropped their patch allowing it
- Install duplicity on demand if needed
- Support reproducible builds by using $SOURCE_DATE_EPOCH to set the man page timestamps, if present
- Translation updates

# 34.0
- Support duplicity 0.6.25 and up
- Support latest versions of appstream-util
- Translation updates

# 32.0
## Features
- Drop support for Ubuntu One cloud storage, since it has shut down
## Packaging
- Fix some compile issues and warnings
## Translations
- New French (Canadian) translation
- Updated Basque, Brazilian Portuguese, Dutch, French, German, Hungarian, and
   Polish translation

# 30.0
## Packaging
- Fix build with CMake 2.8.12
## Translations
- Updated Japanese translation

# 29.5
## Bug Fixes
- Re-enable libunity support after it was accidentally dropped in 29.1
## Packaging
- Require duplicity 0.6.23
## Translations
- Updated Dutch and Spanish translations

# 29.4
## Bug Fixes
- Add missing icon in help documentation
## Packaging
- Add ENABLE_UNITY_CCPANEL argument for unity-control-center support
- Fix some compile problems with valac, parallel building, and rpath support
## Translations
- Updated Basque, Chinese (Traditional), Finnish, French, Polish, and Spanish
   translations

# 29.1
## Bug Fixes
- Detect encryption on existing backups by paying attention to what Duplicity
   tells us, rather than trying to figure it out by scanning ourselves.
   This removes a possible source of error.
## Polish
- Rename to Backups (instead of Backup)
- Update look and feel of preferences a bit
- Add screenshots to appdata file
## Packaging
- Require GTK+ 3.6 and GLib 2.34
- Convert from autotools to cmake:
    --with-ccpanel is now -DENABLE_CCPANEL
    --with-nautilus is now -DENABLE_NAUTILUS
    --with-unity is now -DENABLE_UNITY
   Otherwise, normal cmake conventions apply
- Add some autopilot tests, runnable by 'autopilot' and 'autopilot-system'
   targets (which test against the local built executables or the installed
   system ones respectively)
## Translations
- Updated Basque, Chinese (Traditional), Dutch, Finnish, and Polish
   translations

# 28.0 (GNOME 3.10)
## Polish
- Clean up help documentation a tad
- When using the System Settings panel, have F1 pull up the help documentation
- Ship an AppData file
- Be more verbose about errors when restoring files
## Translations
- New Northern Sami translation
- Updated Hungarian and Polish translations

# 27.3 (GNOME 3.9.3)
## Bug Fixes
- Fix optional System Settings panel to work with GNOME 3.8 and above
## Translations
- Updated Galician, Italian, and Turkish translations

# 26.0 (GNOME 3.8.0)
## Bug Fixes
- Only use the GNOME Shell interface when actually in GNOME Shell, not something that is merely similar, like the Cinnamon shell
- When testing a restore, also use a temporary directory that is on the same partition as the include files
## Polish
- Spread default backup time around a bit, from always starting at midnight UTC to starting between 2 and 4 AM local time
- Use more-aggressively-idle modes for ionice and nice if available
## Translations
- Updated Ukrainian translation

# 25.5 (GNOME 3.7.5)
## Features
- Support replacing $USER in gsettings file backup location too (in addition to previous support for include and exclude folders)
## Polish
- Tell duplicity to use a temporary directory that is on the same partition as the include files, to avoid problems with tiny /tmp directories (as can happen with tmpfs)
- Tell GNOME 3 about our notifications, so the user can disable them
- Always exclude /run (in case user includes /)
## Packaging
- Require duplicity 0.6.21 for its data corruption fixes
## Translations
- Updated Bulgarian and Ukrainian translations

# 25.3 (GNOME 3.7.3)
## Features
- Support replacing $USER in gsettings default paths for system administrators
## Bug Fixes
- Fix Ubuntu One support for duplicity 0.6.20 and above
## Polish
- Ignore ~/Steam due to its large and cache-oriented content
## Translations
- Updated Basque, Dutch, and Slovenian translations

# 25.1.1
## Bug Fixes
- Fix notifications from deja-dup-monitor not being translated
## Packaging
- Fix libsecret build error with last tarball
- Tests now require python3 instead of python2
- Run 'make -C tests check-system' to test against installed deja-dup

# 25.1 (GNOME 3.7.1)
## Packaging
- Switch from libgnome-keyring to libsecret
## Translations
- Updated Arabic, Basque, Burmese, Catalan, Dutch, Esperanto, Estonian, Finnish, French, Galician, German, Greek, Hebrew, Hungarian, Italian, Japanese, Occitan (post 1500), Polish, Russian, Slovenian, Spanish, and Uyghur translations

# 24.0 (GNOME 3.6.0)
## Translations
- Updated Czech, Croatian, and Dutch translations

# 23.92 (GNOME 3.5.92)
## Bug Fixes
- Only allow one deja-dup-monitor process at a time
## Translations
- Updated Basque, Chinese (Traditional), Dutch, Finnish, Lithuanian, and Polish translations

# 23.90 (GNOME 3.5.90)
## Features
- At the end of every backup, verify that we can correctly restore a file
- Every two months, additionally verify that the user could correctly restore a file from a new computer by prompting for password and not using cached duplicity files
## Translations
- Updated Asturian, Belarusian, Polish, and Slovenian translations

# 23.4 (GNOME 3.5.4)
## Polish
- Always makes a fresh backup every three months now, regardless of how often automatic backups happen
- Don't prompt for root password when restoring from Ubuntu One, as it won't work anyway (U1 needs to talk to your session bus, which root can't do)
- Use pkexec instead of gksu
## Translations
- Updated Arabic, Basque, Bengali, Bosnian, Brazilian Portuguese, Bulgarian, Chinese (Simplified), Danish, Esperanto, Finnish, French, Galician, German, Hebrew, Indonesian, Khmer, Lithuanian, Norwegian Bokmal, Russian, Sinhalese, Slovenian, and Turkish translations

# 23.2 (GNOME 3.5.2)
## Packaging
- Require glib >= 2.32
- Require valac >= 0.16
- Require libpeas
## Translations
- New Sinhalese translation
- Updated Albanian, Asturian, Basque, Bosnian, Bulgarian, Catalan, Catalan (Valencian), Danish, English (Australia), Esperanto, Finnish, French, German, Greek, Hungarian, Japanese, Lithuanian, Malay, Occitan (post 1500), Polish, Romanian, Serbian, Slovak, Slovenian, Spanish, Uyghur, and Welsh translations

# 22.1 (GNOME 3.4.1)
## Bug Fixes
- Allow resuming an encrypted but incomplete backup
## Translations
- Updated Chinese (Simplified), Croatian, Danish, Dutch, and Esperanto translations

# 22.0 (GNOME 3.4.0)
## Bug Fixes
- When restoring files outside of $HOME from a non-cloud remote server, don't run under sudo since it will fail anyway
- Tell user when a file could not be restored due to permission problems
## Translations
- New Frisian, Punjabi, and Uzbek translations
- Updated Brazilian Portuguese, Czech, English (Australia), Finnish, French, Galician, Japanese, and Turkish translations

# 21.90 (GNOME 3.3.90)
## Bug Fixes
- Work around bug in GTK+ that caused text to be white-on-white
## Polish
- Won't try to backup if online but target server is not available
## Packaging
- Support building with valac-0.16 (in addition to valac-0.14)
## Translations
- New Kazakh translation
- Updated Chinese (Traditional), Dutch, English (UK), Esperanto, Faroese, Finnish, Galician, Greek, Italian, Lithuanian, Serbian, Swedish, Turkish, and Uyghur translations

# 21.4 (GNOME 3.3.4)
## Polish
- Warn user if we couldn't back up a file because we couldn't read it
## Packaging
- Fix -j2 build
- Add auto tests that are run during 'make check', suitable for build servers
## Translations
- Updated Chinese (Traditional), Croatian, Dutch, Finnish, French, German, Hungarian, Polish, Russian, Slovenian, Tamil, and Turkish translations

# 21.2 (GNOME 3.3.2)
## Bug Fixes
- Use smarter test for detecting whether existing backups are encrypted, which will work even if duplicity uses translations
- Fix a bug that in some situations could lead to a full backup being created more frequently than once a month
## Polish
- Drop "After a week" from "Keep backups" option, since internally, we always wait a month anyway
- Treat any AssertionError by duplicity as an internal duplicity error by wiping the cache and trying again; this will let us be more pro-active about fixing some odd duplicity situations
## Packaging
- Start of a unit test for our internal library; compile and run it with 'make check'
## Translations
- Updated Basque, Brazilian Portuguese, English (UK), Estonian, Finnish, German, Norwegian Bokmal, Norwegian Nynorsk, Serbian, Slovak, Slovenian, Swedish, Telugu, Turkish, and Vietnamese translations

# 21.1 (GNOME 3.3.1)
## Bug Fixes
- Allow passwords that contain only whitespaces (while continuing to strip whitespace from normal passwords)
## Polish
- Switch to notebook tabs for preferences instead of side list
## Packaging
- Use valac 0.14 instead of 0.12
- Tarballs now only include the vala code, so you'll need valac to compile
- Tarballs now use xz compression instead of bz2
- No longer require libdbusmenu-gtk3 for Unity support
## Translations
- New Bengali and Estonian translations
- Updated Albanian, Asturian, Basque, Brazilian Portuguese, Bulgarian, Catalan, Dutch, Hebrew, Hungarian, Japanese, Korean, Latvian, Lithuanian, Norwegian Bokmal, Occitan, Polish, Serbian, and Slovenian translations

# 20.1 (GNOME 3.2.1)
## Bug Fixes
- Correctly backup or exclude folders with [, ], ?, and * in their names
- Fix translation of some strings when used in control center panel mode
- Fix a nautilus crash if the gsettings schema isn't installed correctly
- Allow LUKS encrypted volumes to appear in backup location list
## Translations
- New Catalan (Valencian), Ido, Tamil, and Uyghur translations
- Updated Croatian, Danish, Esperanto, French, German, and Indonesian translations

# 20.0 (GNOME 3.2.0)
## Polish
- Backed out ubuntuone-installer support; it wasn't perfect and Ubuntu 11.10 won't use it after all
- In Unity, go back to using minimized automatic backup windows
## Translations
- Updated Croatian, Dutch, French, Italian, Japanese, Russian, and Ukrainian translations

# 19.92 (GNOME 3.1.92)
## Bug Fixes
- In Unity, work around bug with minimized windows and the launcher by just not minimizing windows but instead showing them without stealing focus
- If a user manually enters a volume (e.g. USB drive) path as a local folder, correct that internally on the first backup
## Polish
- If Ubuntu One support is not available but the ubuntuone-installer is, use that
- Never clean up files in the backup location during a restore
- Fix spacing and layout with latest versions of GTK+
## Translations
- New Chinese (Hong Kong) and Welsh translations
- Updated Basque, Brazilian Portuguese, Chinese (Traditional), Czech, English (UK), Faroese, Finnish, German, Hungarian, Italian, Occitan, Persian, Slovenian, Telugu, and Thai translations

# 19.91 (GNOME 3.1.91)
## Bug Fixes
- Fix incorrectly resuming encrypted backups as non-encrypted ones
- Fix help not opening
- Fix removing multiple folders at once from the include/exclude lists
## Polish
- When newer versions of duplicity warn that a file has been corrupted upon upload, Déjà Dup will intelligently retry the backup
## Packaging
- Require Duplicity >= 0.6.14, for its data corruption fixes
## Translations
- New Bosnian and Latvian translations
- Updated Brazilian Portuguese, Chinese (Traditional), Czech, English (UK), Finnish, French, Italian, and Russian translations

# 19.90 (GNOME 3.1.90)
## Polish
- Allow showing the progress dialog in GNOME Shell
## Packaging
- Drop optional support for libappindicator, libunity plus legacy GtkStatusIcon support is enough
## Translations
- New Occitan and Serbian translations
- Updated Basque, Croatian, Dutch, English (UK), French, German, Hungarian, Lithuanian, Polish, Serbian, Spanish, and Vietnamese translations

# 19.5 (GNOME 3.1.5)
## Bug Fixes
- Fix crash if using nautilus plugin as root
- Fix crash if restore-missing dialog gives us unexpected non-path files
- Fix incorrect order of old/new hostnames in error dialog about new hostname
- Fix pressing Delete key in include/exclude lists being ignored
## Polish
- Lots of UI and label tweaks
- Don't show optical media in backup location dropdown
- Update backup location dropdown as external drives come and go
- Allow drag and drop of folders into include/exclude lists
- Make it clear that the default home folder include is only your user's home folder
- Don't keep notifying about delayed backups between setting up your preferences and your first backup
## Translations
- New Malay translation
- Updated Basque, Croatian, Dutch, Finnish, Galician, German, Hungarian, Italian, Polish, Slovenian, Spanish, Swedish, Turkish, and Vietnamese translations

# 19.4 (GNOME 3.1.4)
## Bug Fixes
- Fix crash with accessibility turned on
- Revert change in 19.3 that sometimes caused bogus "unknown error" dialogs after a successful backup
- Watch for changes in automatic backup settings again
- Check for Ubuntu One support more robustly, preventing it being shown as an option when it isn't available
- Workaround some NetworkManager oddities by waiting two minutes to make sure we are really connected
- When duplicity gives us an error we don't understand, try operation again without a cache to try and workaround whatever the problem is
## Polish
- Drop encryption preference and either ask during first backup or detect from existing backup
- More layout fixups to work better with latest GTK+
- Where the Autostart-Delay key is supported, delay monitor start by two minutes
## Packaging
- Require Duplicity >= 0.6.8
## Translations
- New Albanian, Asturian, and English (Australia) translations
- Updated Basque, Brazilian Portuguese, Bulgarian, Chinese (Traditional), Croatian, Dutch, Faroese, Finnish, French, German, Hungarian, Italian, Lithuanian, Norwegian Bokmal, Polish, Slovenian, Spanish, Swedish, Turkish, and Vietnamese translations

# 19.3 (GNOME 3.1.3)
## Bug Fixes
- Fix crash on first launch
- Fix crash when cancelling an operation
- Only prompt about backing up every month, not every login after the first
- When restoring, let user know if they need to plug in external drive
- If user didn't tell us that the backup is encrypted but it is, ask for password
- Fix detection of Ubuntu One availability
- Workaround "CRC check failed" bug by clearing the cache if we hit it
- Don't restore all files when trying to just restore one
- Ask gpg1 to not use agent, working around some gpg-agent problems
## Polish
- Fix some layout issues with latest GTK+
- Don't show location preferences when restoring single files, just on full restore
- Show launcher icon in Unity during automatic backup again
## Translations
- New Persian translation
- Updated Basque, Croatian, Danish, Dutch, Finnish, French, German, Lithuanian, Polish, Russian, and Spanish translations

# 19.2.2
## Bug Fixes
- Fix a compilation issue with gio-unix-2.0
- Update mailing list links

# 19.2.1
## Bug Fixes
- Fix compilation issue for nautilus plugin

# 19.2 (GNOME 3.1.2)
## Features
- Turn on Ubuntu One support when using a newer duplicity
- Added monthly notification about backing up if user never used deja-dup
## Bug Fixes
- Don't ignore user's chosen external drive in preferences when it is plugged in
- Don't crash if file path setting is empty
## Polish
- Better support for GNOME Shell and its notification system
- Run Déjà Dup itself under ionice and nice instead of just duplicity
- Make volume chunk sizes larger, to reduce the number of files created
## Packaging
- Bring back man pages and a separate deja-dup-preferences executable
- Make libgnome-control-center an optional dependency
- Make python-boto and python-rackspace-cloudfiles optional dependencies
## Translations
- New Croatian, Greek, and Telugu translations
- Updated Basque, Brazilian Portuguese, Bulgarian, Catalan, Chinese (Traditional), Czech, Dutch, English (UK), Finnish, French, Galician, German, Hebrew, Hungarian, Italian, Norwegian Bokmal, Polish, Russian, Spanish, Ukrainian, and Vietnamese translations

# 19.1 (GNOME 3.1.1)
## Features
- Reworked interface to be a control center plugin
- Added overview page where last and next backup dates can be seen
## Polish
- Fleshed out and updated help documenation
- When restoring from a location that isn't your normal backup location, your location isn't changed
- When encryption password is bad, ask for it again
- Only show nautilus context menu item if file is in backup
## Packaging
- Require gtk+-3.0
- Require libgnome-control-center
- Drop libunique
- Interface shipped as a control center plugin now, not a launchable application
- Drop man pages, as all commands are in libexec now
## Translations
- Updated Basque, Bulgarian, Dutch, Finnish, French, Galician, German, Hungarian, Italian, Polish, Russian, and Spanish translations

# 18.1.1
## Bug Fixes
- Actually work with NetworkManager 0.9
## Translations
- Updated Basque translation

# 18.1 (GNOME 3.0.1)
## Bug Fixes
- Work with NetworkManager 0.9

# 18.0 (GNOME 3.0)
## Bug Fixes
- If using an older duplicity and it gives a certain bogus "time not moving forward" error, handle it instead of passing the error along
- Create backup location folder if it doesn't exist
- Don't show duplicate external hard drives
## Translations
- Updated Dutch and German translations

# 17.92 (GNOME 2.91.92)
## Features
- Re-enabled support for resuming a backup, if using the unreleased duplicity 0.6.13
## Polish
- New icon by Lapo Calamandrei
## Translations
- Updated Czech and German translations

# 17.91 (GNOME 2.91.91)
## Bug Fixes
- Fix a couple issues with Unity integration (like not showing in launcher)
- Fix some broken label mnemonics in the preferences
## Polish
- Rename Quit to Close
## Translations
- Updated Brazilian Portuguese, Chinese (Simplified), English (UK), Italian, Norwegian Bokmal, Spanish, and Ukrainian translations

# 17.90 (GNOME 2.91.90)
## Bug Fixes
- Fixed bug with remote locations that made it impossible to set a remote folder
- Fix a couple rare crashers
## Polish
- When entering an encryption password for the first time, it now needs to be confirmed to avoid typo mistakes
- First pass at optional Unity integration (instead of a status icon)
## Packaging
- Require the stable release of GTK+ 3.0 (if compiling against 3.0)
- If libunity is available, it will be used; control further with --with-unity or --without-unity
## Translations
- New Bulgarian translation
- Updated Catalan, Chinese (Traditional), Czech, French, German, Hebrew, Russian, Spanish, Turkish, and Ukranian translations

# 17.6 (GNOME 2.91.6)
## Bug Fixes
- Don't show error if both Déjà Dup and nautilus are trying to mount a volume at the same time
- Allow removing multiple folders from the preferences at the same time
- Handle more odd symlink-in-include-path situations
- Fix odd behavior (possibly a crash) when cancelling a backup or restore
## Polish
- Exclude Adobe flash cache directory by default
- Add documentation for how to get your data back even if Déjà Dup isn't working
## Packaging
- Have 'make check' run some tests inside of Xvfb.  This may not work 100% yet, if it doesn't, just don't run tests as part of the build
- If building in maintainer mode (and thus using valac), the minimum valac version is now 0.11.4
- Support libnautilus-extension-3.0

# 17.5 (GNOME 2.91.5)
## Features
- Add support for the Rackspace Cloud Files service
## Bug Fixes
- Fix crash when changing backup location on first startup
- When browsing for a local folder, start the dialog in the current folder setting
## Polish
- Use hostname in default Amazon S3 folder name
- Add Downloads folder to default exclude list
## Packaging
- Re-enable GTK+ 3.0 support using --with-gtk3, will use it by default if installed at build time
- Will need python-cloudfiles installed at run time to enable new Rackspace Cloud Files support
## Translations
- New Ukrainian translation
- Updated Basque, Czech, Danish, Dutch, English (UK), French, German, Japanese, Polish, Russian, Spanish, and Swedish translations

# 17.4 (GNOME 2.91.4)
## Polish
- Reorganize the backup location preferences to be more intuitive
## Translations
- New Chinese (Simplified) translation
- Updated Arabic, Brazilian Portuguese, Chinese (Traditional), Czech, Dutch, French, Indonesian, Norwegian Bokmal, Spanish, and Turkish translations

# 17.3 (GNOME 2.91.3)
## Bug Fixes
- Fix crash when changing backup location
- Fix date formats when restoring to be more consistent
## Packaging
- Drop accidental resurgence of gconf-2.0 dependency
- Require libnotify 0.7
## Translations
- New Basque and Norwegian Nynorsk translations
- Updated Arabic, Brazilian Portuguese, Catalan, Czech, Dutch, English (UK), Faroese, French, German, Hebrew, Italian, Japanese, Lithuanian, Norwegian Bokmal, Polish, Russian, Spanish, Swedish, and Turkish translations

# 17.2 (GNOME 2.91.2)
## Features
- Add a "Restore Missing Files" interface, accessed via nautilus
- Support GNOME Shell persistent notifications
## Polish
- Only calculate progress bar if a fresh backup is being made
- Adjust gsettings path, so previous 17.x settings changes may be lost
## Bug Fixes
- If Duplicity looks like it's hitting a common bad-metadata bug, clear cache and try again

# 17.1 (GNOME 2.91.1)
## Bug Fixes
- If backup destination does not report free size, just continue anyway
- Fix bug preventing sudo and encryption getting along
- Don't ask for root password when restoring into the user's home folder

# 17.0 (GNOME 2.91.0)
## Features
- Use gsettings and dconf instead of gconf
## Packaging
- Drop gconf-2.0
## Translations
- Updated Czech, French, German, Italian, and Japanese translations

# 16.0 (GNOME 2.32.0)
## Translations
- Updated Czech, Dutch, Finnish, French, Lithuanian, Polish, and Russian translations

# 15.92 (GNOME 2.31.92)
## Features
- Support ConnMan as well as NetworkManager
## Bug Fixes
- Disable explicit resume support as there are still bugs in duplicity's implementation
- Don't add excluded symlink targets to the include list
- If NetworkManager isn't running, assume connection is valid
## Packaging
- Drop libdbus-glib
- Require glib 2.25/2.26
## Translations
- Updated Brazilian Portuguese, Chinese (Traditional), Dutch, Finnish, French, German, Italian, Japanese, Lithuanian, Polish, and Russian translations

# 15.5 (GNOME 2.31.5)
## Bug Fixes
- Always leave at least one full backup, even if space seems too low for another
- Don't cancel operation when the window close button is pressed, just hide
## Polish
- Adjust symbolic panel icon to work with new GTK+ 3.0 symbolic color support
- Escape printed duplicity command lines to avoid errors when entering them manually
## Packaging
- Support gtk3 via --with-gtk3 configure argument that defaults to 'check'
## Translations
- New Brazilian Portuguese and Thai translations
- Updated Arabic, Dutch, English (UK), French, Galician, Italian, Japanese, Malayalam, Polish, Russian and Spanish translations

# 15.3 (GNOME 2.31.3)
## Features
- When the backup location is out of space, delete the oldest backup
## Bug Fixes
- Don't delete backups after 6 months if they are supposed to be kept forever
- Don't crash nautilus when trying to restore files twice
- Don't cause false-negative permission denied errors when entering password
- Allow going back at the restore confirmation dialog
- Don't duplicate the files-to-restore list in the restore confirmation dialog
- When a symlink is in the include/exclude list, also include/exclude its target
- Support better error messages for when the backup location is missing or full
## Polish
- Rearrange preferences dialog to use tabs
## Translations
- New Faroese translation
- Updated Dutch, English (UK), Hungarian, Polish, Slovenian, and Spanish translations
 
# 15.2 (GNOME 2.31.2)
## Polish
- Fix some spacing issues with dialog layouts
- When restoring, don't show time when there's only one backup on that day
## Translations
- New Catalan translation
- Updated Dutch, English (UK), Finnish, German, Russian, and Turkish translations

# 15.1 (GNOME 2.31.1)
## Polish
- Reorganize help documentation to use new mallard format
- Change terminology for 'backup' verb to 'back up'
## Translations
- New Bulgarian, Polish, and Romanian translations
- Updated English (UK), Finnish, Galacian, German, Italian, Japanese, Lithuanian, Russian, Slovak, Spanish, and Turkish translations

# 14.2 (GNOME 2.30.2)
## Bug Fixes
- Don't delete backups after 6 months if they are supposed to be kept forever
- Don't crash nautilus when trying to restore files twice
- Don't cause false-negative permission denied errors when entering password
- Allow going back at the restore confirmation dialog
- Don't duplicate the files-to-restore list in the restore confirmation dialog
## Translations
- New Catalan and Faroese translations
- Updated Dutch and Turkish translations

# 14.1 (GNOME 2.30.1)
## Bug Fixes
- Fix backing up to an external drive (broken since a glib update)
- Fix restoring a single directory that already exists
- Fix a deja-dup-monitor crash if there is an error reading the configuration
## Translations
- New Romanian translation
- Updated Dutch, German, Hungarian, Italian, Polish, and Turkish translations

# 14.0.3
## Bug Fixes
- Fix restoring to a non-empty directory (including to original locations).

# 14.0.2
## Bug Fixes
- Allow switching backup location away from an external drive

# 14.0.1
## Bug Fixes
- Do not use 100% CPU when backing up

# 14.0 (GNOME 2.30.0)
## Polish
- Make panel icon smaller to fit better
- Make main window non-resizable
## Bug Fixes
- Workaround crash bug in duplicity 0.6.08 and 0.6.08a
## Packaging
- Make nautilus extension optional (--without-nautilus)
## Translations
- New Polish translation
- Updated Finnish, German, Hungarian, and Turkish translations

# 13.92 (GNOME 2.29.92)
## Polish
- Don't try to run automated backups immediately after logging in.  Instead, wait 2 minutes to give NetworkManager a chance to connect.  (If it's still not ready, we will give normal warning about waiting for connection.)
## Bug Fixes
- Do the right thing if user asks us to include folder A/B but exclude A and vice versa.
## Translations
- Updated Dutch, English (UK), German, Hungarian, Japanese, Russian, Slovak, Slovenian, and Swedish translations

# 13.91 (GNOME 2.29.91)
## Polish
- Add a 'Show password' checkbox to password prompts, so you can see what you type
## Bug Fixes
- Fix a typo and some missing keys in gconf documentation
- Don't flash window on and off when canceling a backup
## Translations
- Updated English (UK), German, Japanese, Russian, Slovak, and Swedish translations

# 13.7 (GNOME 2.29.90)
## Polish
- Simplify applet menu (left-click and right-click are same, show/hide progress is now a check box, show percent done in menu itself)
## Bug Fixes
- Fix crash when backing up with SSH by compiling with latest valac
- Fix line endings in error messages
- If user hid progress dialog of a manual backup, pop up success screen when done
## Translations
- New Slovenian translation
- Updated Dutch, English (UK), Finnish, and Russian translations

# 13.6 (GNOME 2.29.6)
## Features
- Ask for root password when restoring into system folders
## Packaging
- Require gio-unix
## Translations
- Updated Arabic, Czech, Dutch, French, German, Hungarian, Japanese, Russian, Slovak, and Spanish translations

# 13.5 (GNOME 2.29.5)
## Features
- Supports libappindicator if available
## Bug Fixes
- If using duplicity 0.6.07, some issues with /tmp space when restoring are fixed
## Packaging
- New --with-appindicator configure option, defaults to on if libappindicator is installed
## Translations
- New Japanese translation
- Updated Arabic, English (UK), French, Russian, and Spanish translations

# 13.4 (GNOME 2.29.4)
## Bug Fixes
- Don't crash if user didn't install the gconf schema
## Translations
- New Hungarian translation
- Updated Dutch, English (UK), German, Indonesian, Russian, and Spanish
   translations

# 13.3 (GNOME 2.29.3)
## Features
- If a removable drive is not connected, notify the user and wait for it
## Bug Fixes
- Don't try to run a scheduled backup if a manual backup/restore is running
## Translations
- Updated Dutch, German, Italian, Russian, and Spanish translations
## Packaging
- Bumped required glib version to 2.20
- Add back libnotify dependency

# 11.1 (2009-11-16)
## Bug Fixes
- Don't download all backup files when restoring a single file
- Correctly restore files in read-only directories
## Translations
- Updated German translation

# 11.0 (2009-10-29)
## Features
- Allow deleting old backups past a certain date (e.g. 3 months ago)
- Will create fresh full backups occasionally to avoid backup corruption
- Support resuming an unfinished backup
## Bug Fixes
- Support duplicity's native gio handling, fixing some remote connection bugs
- Don't start an automatic backup if no network connection
- Don't ask for encryption passphrase twice during restore
- If a hostname mismatch occurs, allow the user to decide what to do
## Polish
- Allow turning on automatic backups after a successful manual backup
- Make backup chunk sizes much larger, as fewer files are easier to deal with
- Allow hiding progress window while backing up by clicking on the applet
- Ask for passwords in-window rather than popping up a new dialog
- Provide feedback about when we're uploading vs backing up
## Translations
- New Czech, Esperanto, Italian, Kurdish, Portuguese, Slovak, and Traditional Chinese translations
- Updated Dutch, French, Galacian, German, Norwegian Bokmal, Russian, Spanish, and Swedish translations
## Packaging
- Bumped required gtk+ version to 2.14
- Bumped required glib version to 2.18
- Dropped libgnomeui dependency
- Dropped libnotify dependency
- Dropped gfvs-fuse dependency (if you have duplicity 0.6.05 or later)
- Added a bunch of new tests

# 10.2 (2009-10-09)
- Fix an occasional crasher when manually backing up/restoring

# 10.1 (2009-06-13)
- Support caching backup metadata, which means Déjà Dup supports the recently
  released duplicity 0.6.00 which requires a cache
- Updated French, German, Russian, and Swedish translations

# 10.0 (2009-06-05)
- Use GIO, letting one backup to FTP, WebDAV, and Windows Networking servers.
- Add a 'Details' box when backing up or restoring.  This lets you see the
  full path of each file as it is touched (rather than just the filename).
- If the user tries to backup or restore for the first time, show the relevant
  preferences in the wizard directly.  Don't require that they first open the
  Preferences window.
- Add a more complete summary right before user approves a backup or restore.
- Bug fixes and UI tweaks
- New Indonesian and Turkish translations
- Updated Finnish, French, and Russian translations

# 9.3 (2009-05-30)
- Exclude ~/.Private, not ~/Private.  This means we no longer backup the
  encrypted version of ecryptfs files, but the unencrypted version.  So
  encrypt your backups appropriately.  This change lets us work more elegantly
  in all ecryptfs setups, especially when your whole home directory is
  encrypted.
- Update icons to Tango style ones
- Relicense help documentation from GFDL to GPL-3+
- Some minor bug fixes

# 9.2 (2009-05-09)
- Re-enable some kinder, specific messages for certain duplicity exceptions,
  including I/O errors and 'destination out of space' errors
- Enable translation of user documentation (man pages and manual)
- Updated English (UK), French, German, and Russian translations

# 9.1 (2009-04-27)
- Strip spaces from the ends of passwords, they are likely just cut+paste
  errors from web sites -- notably Amazon's S3 password page (LP: #362899).
- Make bleeding-edge GTK+ symbols introduced by vala 0.7 optional, so we now
  compile again with GTK+ 2.12.

# 9.0 (2009-04-26)
- Use 'nice' for duplicity subprocess to be less of a resource hog
- Make folder include/exclude lists scrollable if too large
- Add some additional default excludes and document all such defaults in the
  user help:
  ~/.xsession-errors
  ~/.recently-used.xbel
  ~/.recent-applications.xbel
  ~/Private (LP: #320019)
- Support recent duplicity feature that allows migrating vfat users to new
  filename scheme
- Show exception text if duplicity fails
- Fix crash if gconf schema isn't installed (LP: #318146)
- Let user cancel 'add directory' dialog (LP: #364690)
- New Finnish, Pashto, and Russian translations

# 8.1 (2009-04-03)
- Fix use of ionice program that prevent deja-dup from working on kernels
  versions less than 2.6.25.  LP: #352492

# 8.0 (2009-03-29)
- Support Ubuntu-9.10-style notifications without action buttons
- Don't backup the backup destination directory
- Don't forcibly migrate FAT32 users to new duplicity (>= 0.5.10) naming scheme
- Lower GTK+ requirement to 2.12 from 2.14
- Add test suite
- New Arabic, Danish, and English (United Kingdom) translations
- Updated Dutch, French, German, and Swedish translations

# 7.4 (2009-02-11)
- Don't ask for S3 bucket name (and default to deja-dup).  Buckets are
  S3-global and that default is certainly taken.  Instead, generate bucket name
  from user ID.  Ask user for an optional folder in the bucket instead.
- Fix bug that prevented cleanup on FAT32.
- If no passphrase is provided, turn off encryption.
- Add better errors for a couple cases (bad encryption password, not signed up
  for S3).
- New Dutch translation
- Updated French, Hebrew, and Spanish translations

# 7.3
- Fix SSH password problem, preventing the SSH backend from working

# 7.2
- Enforce volume size of 5M, regardless of duplicity's default
- New Norwegian Bokmal translation
- Updated German and Swedish translations

# 7.1
- Fix mangled German translation, whoops

# 7.0
- Add nautilus extension to restore files via a right click
- Fix crash when restoring from an empty folder or from FAT32
- Make backup progress bar more accurate for large backups
- Updated German and Swedish translations

# 6.0
- Allow restoring from any backup time point, not just the most recent
- Allow backing up to a Windows partition
- Clean up any leftover backend files from aborted previous runs
- Don't have scheduled backup start while a manual backup is happening
- Don't hang when non-UTF-8 characters appear in filenames
- Fix a bug with local folder selection when not using the file dialog
- Be more forceful about killing duplicity subprocesses, to avoid orphaned ones
- New Galician and German translations

# 5.2
- Don't backup ~/.gvfs
- Fix crash when cancelling while preparing a backup

# 5.1
- Fixed a bug that caused deja-dup to hang if encryption is requested
- Updated Swedish translation

# 5.0
- Use a (short) wizard for backing up too, just like restoring
- Progress during backup is now indicated by showing what file is being
  backed up and how much of the total is done
- Inhibit session to warn user about logging out while backing up
- New help documentation and man pages
- New Swedish translation

# 4.0
- New SSH backend
- Uses ionice if available to not fight with user for disk access
- Automatically excludes some common directories like /tmp, /proc, ~/.cache
- Add wizard for restoring, with better error reporting if certain files can't
  be restored.
- Fix crash when saving password in keyring
- Fix bug where cleaning up the backend actually kicked off another backup
  instead.
- Added Spanish translation
- Updated French translation

# 3.0
- Added ability to set a regular backup schedule (daily, weekly, biweekly, or
  monthly).
- Added --version
- Added French translation

# 2.1
- Finish reading all output from duplicity before closing -- this fixes the
  'silent failure' problem if an error occurs

# 2.0
- Fix typo that caused encryption preference to default to off
- Fix menu icon
- Show S3 ID field in preferences
- Cleanup backend if a backup is cancelled
- Use new duplicity output to present more accurate/precise errors
- Require duplicity 0.5.03
- New Hebrew and Lithuanian translations

# 1.0
- Initial release
- Supports backing up to Amazon S3 or a local directory
