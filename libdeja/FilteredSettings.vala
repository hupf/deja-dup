/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

namespace DejaDup {

/* This is a very simple class that just proxies calls to a Settings object.
   Its one difference is that it won't set a value that is already set to the
   requested value.  This prevents us from causing unnecessary 'changed'
   signals and generally from doing lots writes every time something in the UI
   is adjusted.

   Additionally, doing lots of simultaneous reads & writes sometimes confuses
   dconf, so it's nice to be able to avoid those.
 */

public class FilteredSettings : Settings
{
  public bool read_only {get; construct;}

  public FilteredSettings(string? schema = null, bool ro = false)
  {
    string full_schema = Config.APPLICATION_ID;
    if (schema != null && schema != "")
      full_schema += "." + schema;

    Object(schema_id: full_schema, read_only: ro);

    if (ro)
      delay(); // never to be apply()'d again
  }

  public new void apply() {if (!read_only) base.apply();}

  public new void set_string(string k, string v) {
    if (get_string(k) != v)
     base.set_string(k, v);
  }
  public new void set_boolean(string k, bool v) {
    if (get_boolean(k) != v)
      base.set_boolean(k, v);
  }
  public new void set_int(string k, int v) {
    if (get_int(k) != v)
      base.set_int(k, v);
  }
  public new void set_value(string k, Variant v) {
    if (!get_value(k).equal(v))
      base.set_value(k, v);
  }

  // May be uri, or may be a File's parsed path for historical reasons
  public new string get_uri(string k) {
    // If we are reading a URI, replace some special keywords.
    var val = get_string(k);
    var result = parse_keywords(val);
    if (result == null)
      return "";
    else
      return result;
  }

  public new File[] get_file_list(string k) {
    // If we are reading a file path, replace some special keywords.
    var val = get_value(k);
    return parse_dir_list(val.get_strv());
  }

  // TODO: bytestring, strv
}

}
