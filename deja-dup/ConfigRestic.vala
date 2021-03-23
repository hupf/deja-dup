/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class ConfigRestic: ConfigSwitch
{
  construct {
    var settings = DejaDup.get_settings();
    settings.bind_with_mapping(DejaDup.TOOL_KEY,
                               this.toggle, "active",
                               SettingsBindFlags.DEFAULT,
                               get_mapping, set_mapping,
                               null, null);
  }

  static bool get_mapping(Value val, Variant variant, void *data)
  {
    var tool_name = variant.get_string();
    val.set_boolean(tool_name == "restic");
    return true;
  }

  static Variant set_mapping(Value val, VariantType expected_type, void *data)
  {
    var tool_name = val.get_boolean() ? "restic" : "duplicity";
    return new Variant.string(tool_name);
  }
}
