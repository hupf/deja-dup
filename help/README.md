<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: Michael Terry
-->

The meson yelp tooling assumes translation files and translated figure images
are in locale subdirectories.

The Launchpad translation system assumes po and pot files are in the same
directory.

So our solution is to have them all in the same directory. But we use a symlink
inside subdirectories as well, to trick meson.

