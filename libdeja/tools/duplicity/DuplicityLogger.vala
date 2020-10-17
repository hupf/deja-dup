/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class DejaDup.DuplicityLogger : Object
{
  public signal void message(string[] control_line, List<string>? data_lines,
                             string user_text);

  public DataInputStream reader {get; construct;}
  public bool print_to_console {get; set;}

  public DuplicityLogger.for_fd(int fd)
  {
    InputStream stream = new UnixInputStream(fd, true);
    Object(reader: new DataInputStream(stream));
  }

  public DuplicityLogger.for_stream(InputStream stream)
  {
    Object(reader: new DataInputStream(stream));
  }

  public static DuplicityLogger? from_cache_log()
  {
    var cachefile = get_cachefile();
    if (cachefile == null)
      return null;

    try {
      var stream = File.new_for_path(cachefile).read();
      return new DuplicityLogger.for_stream(stream);
    }
    catch (Error e) {
      warning("%s\n", e.message);
      return null;
    }
  }

  public async void read(Cancellable? cancellable = null)
  {
    // As reader returns lines that are outputed by duplicity, let's
    // makes sure that data is processed at right speed and passes that data
    // along the chain of functions.
    List<string> stanza_lines = new List<string>();
    while (true) {
      try {
        var line = yield reader.read_line_async(Priority.DEFAULT, cancellable, null);
        if (line == null) // EOF
          break;

        process_stanza_line(line, ref stanza_lines);
      }
      catch (Error err) {
        warning("%s\n", err.message);
        break;
      }
    }
  }

  public void read_sync()
  {
    List<string> stanza_lines = new List<string>();
    while (true) {
      try {
        var line = reader.read_line();
        if (line == null) // EOF
          break;

        process_stanza_line(line, ref stanza_lines);
      }
      catch (Error err) {
        warning("%s\n", err.message);
        break;
      }
    }
  }

  void process_stanza_line(string line, ref List<string> stanza_lines)
  {
    if (line != "") {
      if (print_to_console)
        print("DUPLICITY: %s\n", line);
      stanza_lines.append(line);
    }
    else if (stanza_lines != null) {
      if (print_to_console)
        print("\n"); // breather

      var stanza = Stanza.parse_stanza(stanza_lines);
      add_to_tail(stanza);
      message(stanza.control_line, stanza.data, stanza.text);

      stanza_lines = new List<string>();
    }
  }

  // Write tail of log to a cache file for user's benefit
  public void write_tail_to_cache()
  {
    var cachefile = get_cachefile();
    if (cachefile == null)
      return;

    var contents = "";
    foreach (var stanza in tail.head)
      contents += stanza.original_text + "\n";

    try {
      FileUtils.set_contents(cachefile, contents);
    }
    catch (Error e) {
      warning("%s\n", e.message);
    }
  }

  public string get_obscured_tail(DejaDup.LogObscurer obscurer)
  {
    var contents = "";

    foreach (var stanza in tail.head)
      contents += stanza.obscured(obscurer) + "\n\n";
    return contents;
  }

  // ******************

  Queue<Stanza> tail; // last X stanzas of log output

  construct {
    tail = new Queue<Stanza>();
  }

  static string? get_cachefile()
  {
    var cachedir = Environment.get_user_cache_dir();
    if (cachedir == null)
      return null;

    return Path.build_filename(cachedir, Config.PACKAGE, "duplicity.log");
  }

  void add_to_tail(Stanza stanza)
  {
    tail.push_tail(stanza);
    while (tail.get_length() > 50) {
      tail.pop_head();
    }
  }
}


class Stanza : Object
{
  public string original_text;
  public bool[] control_is_path;
  public string[] control_line;
  public List<string>? data;
  public string text;

  // Split the line/stanza that was echoed by stream and pass it forward in a
  // more structured way via a signal.
  public static Stanza parse_stanza(List<string> stanza_lines)
  {
    var stanza = new Stanza();

    // Reassemble lines to a string for archival purposes
    stanza.original_text = "";
    foreach (var line in stanza_lines)
      stanza.original_text += line + "\n";

    split_line(stanza_lines.data, out stanza.control_is_path,
               out stanza.control_line);
    stanza.data = grab_stanza_data(stanza_lines);
    stanza.text = grab_stanza_text(stanza_lines);

    return stanza;
  }

  public string obscured(DejaDup.LogObscurer obscurer)
  {
    string val = "";

    // First, reconstruct control line
    for (int i = 0; i < control_line.length; i++) {
      if (control_is_path[i])
        val += obscurer.replace_path(control_line[i]) + " ";
      else
        val += control_line[i] + " ";
    }

    if (this.data != null) {
      foreach (var line in this.data)
        val += "\n" + obscured_freeform_text(obscurer, line);
    }

    foreach (var line in this.text.split("\n")) {
      val += "\n. " + obscured_freeform_text(obscurer, line);
    }

    return val;
  }

  // *****************

  static string obscured_freeform_text(DejaDup.LogObscurer obscurer, string input)
  {
    // We do not have to be brilliant. Err on the side of caution and obscure
    // more than we need.
    // Examples of duplicity output that we have to handle:
    // . Writing xxx of type reg
    // . Deleting /tmp/duplicity-6hlzxj66-tempdir/mktemp-g_blz8bm-2
    // . Releasing lockfile b'/.../lockfile'
    // . Ignoring file (rejected by backup set) 'xxx'

    // doesn't perfectly handle embedded quotes, but that's mostly fine
    var tokens = input.split_set(" '\"");
    string[] result = {};
    foreach (var token in tokens) {
      if (token.contains("/") ||
          (token != "." && !token.has_suffix(".") && token.contains(".")))
        result += obscurer.replace_path(token);
      else
        result += obscurer.replace_word_if_present(token);
    }
    return string.joinv(" ", result);
  }

  // If start is < 0, starts at word.length - 1.
  static int num_suffix(string word, char ch, long start = -1)
  {
    int rv = 0;

    if (start < 0)
      start = (long)word.length - 1;

    for (long i = start; i >= 0; --i, ++rv)
      if (word[i] != ch)
        break;

    return rv;
  }

  static string validated_string(string s)
  {
    var rv = new StringBuilder();
    weak string p = s;

    while (p[0] != 0) {
      unichar ch = p.get_char_validated();
      if (ch == (unichar)(-1) || ch == (unichar)(-2)) {
        rv.append("�"); // the 'replacement character' in unicode
        p = (string)((char*)p + 1);
      }
      else {
        rv.append_unichar(ch);
        p = p.next_char();
      }
    }

    return rv.str;
  }

  static string compress_string(string s_in)
  {
    var rv = new StringBuilder.sized(s_in.length);
    weak char[] s = (char[])s_in;

    int i = 0;
    while (s[i] != 0) {
      if (s[i] == '\\' && s[i + 1] != 0) {
        bool bare_escape = false;

        // http://docs.python.org/reference/lexical_analysis.html
        switch (s[i + 1]) {
        case 'b': rv.append_c('\b'); i += 2; break; // backspace
        case 'f': rv.append_c('\f'); i += 2; break; // form feed
        case 't': rv.append_c('\t'); i += 2; break; // tab
        case 'n': rv.append_c('\n'); i += 2; break; // line feed
        case 'r': rv.append_c('\r'); i += 2; break; // carriage return
        case 'v': rv.append_c('\xb'); i += 2; break; // vertical tab
        case 'a': rv.append_c('\x7'); i += 2; break; // bell
        case 'U': // start of a hex number
          var val = DejaDup.strtoull(((string)s).substring(i + 2, 8), null, 16);
          rv.append_unichar((unichar)val);
          i += 10;
          break;
        case 'u': // start of a hex number
          var val = DejaDup.strtoull(((string)s).substring(i + 2, 4), null, 16);
          rv.append_unichar((unichar)val);
          i += 6;
          break;
        case 'x': // start of a hex number
          var val = DejaDup.strtoull(((string)s).substring(i + 2, 2), null, 16);
          rv.append_unichar((unichar)val);
          i += 4;
          break;
        case '0':
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
          // start of an octal number
          if (s[i + 2] != 0 && s[i + 3] != 0 && s[i + 4] != 0) {
            char[] tmpstr = new char[4];
            tmpstr[0] = s[i + 2];
            tmpstr[1] = s[i + 3];
            tmpstr[2] = s[i + 4];
            var val = DejaDup.strtoull((string)tmpstr, null, 8);
            rv.append_unichar((unichar)val);
            i += 5;
          }
          else
            bare_escape = true;
          break;
        default:
          bare_escape = true; break;
        }
        if (bare_escape) {
          rv.append_c(s[i + 1]); i += 2;
        }
      }
      else
        rv.append_c(s[i++]);
    }

    return rv.str;
  }

  static void split_line(string line, out bool[] is_path, out string[] split)
  {
    var firstsplit = line.chomp().split(" ");
    var splitlist = new List<string>();
    bool[] splitlist_is_path = {};

    // Special workaround for a duplicity issue. Not ideal, as it only covers
    // one instance of it, but it's the most important instance: file stat.
    // https://gitlab.com/duplicity/duplicity/-/issues/21
    int group_ends_on = -1;
    if (line.has_prefix("INFO 10 ")) {
      // format is INFO 10 <date> <file name> <filetype>
      group_ends_on = firstsplit.length - 2; // second to last word
    }

    int i;
    bool in_group = false;
    string group_word = "";
    for (i = 0; firstsplit[i] != null; ++i) {
      string word = firstsplit[i];

      // Merge word groupings like 'hello \'goodbye' as one word.
      // Assumes that duplicity is helpful and gives us well formed groupings
      // so we only check for apostrophe at beginning and end of words.  We
      // won't crash if duplicity is mean, but we won't correctly group words.
      if (!in_group && word.has_prefix("\'"))
        in_group = true;

      if (in_group) {
        if (group_ends_on >= 0 && group_ends_on == i)
          in_group = false;
        else if (group_ends_on < 0 && word.has_suffix("\'") &&
            // OK, word ends with '...  But is it a *real* ' or a fake one?
            // i.e. is it escaped or not?  Test this by seeing if it has an even
            // number of backslashes before it.
            num_suffix(word, '\\', (long)word.length - 2) % 2 == 0)
          in_group = false;
        // Else...  If it ends with just a backslash, the backslash was
        // supposed to be for the space.  So just drop it.
        else if (num_suffix(word, '\\') % 2 == 1)
          // Chop off last backslash.
          word = word.substring(0, word.length - 2);

        // get rid of any other escaping backslashes and translate octals
        word = compress_string(word);

        // Now join to rest of group.
        if (group_word == "")
          group_word = word;
        else
          group_word += " " + word;

        if (!in_group) {
          // add to list, but drop single quotes
          splitlist.append(group_word.substring(1, group_word.length - 2));
          splitlist_is_path += true;
          group_word = "";
        }
      }
      else {
        splitlist.append(word);
        splitlist_is_path += false;
      }
    }

    // Now make it nice array for ease of random access
    split = new string[splitlist.length()];
    i = 0;
    foreach (string s in splitlist)
      split[i++] = s;

    is_path = splitlist_is_path;
  }

  static List<string> grab_stanza_data(List<string> stanza)
  {
    // Return only data from stanza that was returned by stream
    var list = new List<string>();
    stanza = stanza.next; // skip first control line
    foreach (string line in stanza) {
      if (!line.has_prefix(". "))
        list.append(validated_string(line.chomp())); // drop endline
    }
    return list;
  }

  static string grab_stanza_text(List<string> stanza)
  {
    string text = "";
    foreach (string line in stanza) {
      if (line.has_prefix(". ")) {
        var split = line.split(". ", 2);
        text = "%s%s\n".printf(text, validated_string(split[1]));
      }
    }
    return text.chomp();
  }
}
