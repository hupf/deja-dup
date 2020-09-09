/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

// Used to obfuscate paths and sensitive information in logs
public class DejaDup.LogObscurer : Object
{
  HashTable<string, string> replacements;

  construct {
    replacements = new HashTable<string, string>(str_hash, str_equal);

    // Add some known words that are more helpful to leave alone
    replacements.insert(Config.PACKAGE, Config.PACKAGE);
    replacements.insert(".cache", ".cache");
    replacements.insert("home", "home");
    replacements.insert("lockfile", "lockfile");
    replacements.insert("metadata", "metadata");
    replacements.insert("README", "README");
    replacements.insert("tmp", "tmp");
  }

  string random_str(string input)
  {
    var str = "";
    for (int i = 0; i < input.length; i++) {
      var sub = input[i];
      if (sub.isalnum())
        sub = (char)Random.int_range((int)'a', (int)'z');
      str = "%s%c".printf(str, sub);
    }
    return str;
  }

  public string replace_path(string path)
  {
    var pieces = path.split("/");
    for (int i = 0; i < pieces.length; i++) {
      var piece = pieces[i];
      if (piece == "" || piece[0] == '$' || piece.has_prefix("duplicity-"))
        continue;

      var replacement = replacements.lookup(piece);
      if (replacement == null) {
        replacement = random_str(piece);
        replacements.insert(piece, replacement);
      }
      pieces[i] = replacement;
    }

    return string.joinv("/", pieces);
  }

  public string[] replace_paths(string[] paths)
  {
    for (int i = 0; i < paths.length; i++) {
      paths[i] = replace_path(paths[i]);
    }
    return paths;
  }

  public string replace_word_if_present(string word)
  {
    var replacement = replacements.lookup(word);
    if (replacement == null)
      return word;
    else
      return replacement;
  }

  public string replace_uri(string uri)
  {
    var scheme = Uri.parse_scheme(uri);
    if (scheme == null)
      return replace_path(uri);

    return scheme + replace_path(uri.substring(scheme.length));
  }
}
