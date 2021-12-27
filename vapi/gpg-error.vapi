/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

[CCode (cheader_filename = "gpg-error.h")]
namespace GpgError {
  [CCode (cname = "gpg_err_code_t", cprefix = "GPG_ERR_", has_type_id = false)]
  public enum Code {
    NO_SECKEY = 17,
    BAD_KEY = 19,
  }

  // Really, this takes a gpg_error_t, but that's essentially a code_t above,
  // as long as we aren't interested in specifying a source.
  [CCode (cname = "gpg_strerror")]
  public unowned string strerror(GpgError.Code code);
}
