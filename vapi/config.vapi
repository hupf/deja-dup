/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

[CCode (cprefix = "", lower_case_cprefix = "")]
namespace Config {
	public const string GETTEXT_PACKAGE;
	public const string LOCALE_DIR;
	public const string PKG_LIBEXEC_DIR;
	public const string PACKAGE_NAME;
	public const string PACKAGE_VERSION;
	public const string PACKAGE;
	public const string VERSION;
	public const string PROFILE;
	public const string APPLICATION_ID;
	public const string ICON_NAME;

	public const string BORG_COMMAND;
	public const string DUPLICITY_COMMAND;
	public const string RESTIC_COMMAND;

	public const string BORG_PACKAGES;
	public const string DUPLICITY_PACKAGES;
	public const string RESTIC_PACKAGES;
	public const string GVFS_PACKAGES;

	public const string RCLONE_COMMAND;
	public const string RCLONE_PACKAGES;

	public const string GOOGLE_CLIENT_ID;
	public const string MICROSOFT_CLIENT_ID;
}
