/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class FileStore : Gtk.ListStore
{
  public DejaDup.FileTree tree {get; private set; default = null;}
  public bool can_go_up {get; private set; default = false;}
  public string search_filter {get; set; default = null;}

  // If you reorder these, you might need to update the ui files that hardcode
  // these column numbers.
  public enum Column {
    FILENAME = 0,
    SORT_KEY,
    ICON, // never set, but left blank as an aid to Browser, which does some iconview tricks
    GICON,
    PATH,
  }

  public void register_operation(DejaDup.OperationFiles op)
  {
    current = null;
    tree = null;
    clear();

    op.listed_current_files.connect(handle_listed_files);
  }

  public bool go_down(Gtk.TreePath path)
  {
    Gtk.TreeIter iter;
    if (!get_iter(out iter, path))
      return false;

    string filename;
    @get(iter, Column.FILENAME, out filename);

    var child = current.children.lookup(filename);
    if (child == null || child.kind != "dir")
      return false;

    set_current(child);
    return true;
  }

  public void go_up()
  {
    if (can_go_up)
      set_current(current.parent);
  }

  public File? get_file(Gtk.TreePath path)
  {
    var filepath = get_full_path_from_path(path);
    if (filepath == null)
      return null;
    return File.new_for_path("/" + filepath);
  }

  ////

  DejaDup.FileTree.Node current;

  construct {
    set_column_types({typeof(string), typeof(string), typeof(Gdk.Pixbuf),
                      typeof(Icon), typeof(string)});

    set_sort_column_id(Column.FILENAME, Gtk.SortType.ASCENDING);
    set_sort_func(Column.FILENAME, (m, a, b) => {
      string akey, bkey;
      @get(a, Column.SORT_KEY, out akey);
      @get(b, Column.SORT_KEY, out bkey);
      return strcmp(akey, bkey);
    });

    notify["search-filter"].connect(update_search);
  }

  string? get_full_path_from_path(Gtk.TreePath path)
  {
    Gtk.TreeIter iter;
    if (!get_iter(out iter, path))
      return null;

    string filename, rel_path;
    @get(iter, Column.FILENAME, out filename, Column.PATH, out rel_path);

    if (rel_path == null)
      return Path.build_filename(tree.node_to_path(current), filename);
    else
      return Path.build_filename(tree.node_to_path(current), rel_path, filename);
  }

  void update_search()
  {
    if (search_filter == null || search_filter == "") {
      set_current(current);
      return;
    }

    var needle_tokens = search_filter.tokenize_and_fold("", null);

    clear();
    recursive_search(needle_tokens, current);
  }

  void recursive_search(string[] needle_tokens, DejaDup.FileTree.Node node)
  {
    node.children.for_each((name, child) => {
      // Calculate and cache search tokens if we haven't done that yet
      if (child.search_tokens == null) {
        string[] unicode_tokens, ascii_tokens;
        unicode_tokens = child.filename.tokenize_and_fold("", out ascii_tokens);
        string[] all_tokens = new string[unicode_tokens.length + ascii_tokens.length];
        for (int i = 0; i < unicode_tokens.length; i++)
          all_tokens[i] = unicode_tokens[i];
        for (int i = 0; i < ascii_tokens.length; i++)
          all_tokens[unicode_tokens.length + i] = ascii_tokens[i];
        child.search_tokens = all_tokens;
      }

      bool all_matched = true;
      foreach (var needle in needle_tokens) {
        bool needle_matched = false;
        foreach (var token in child.search_tokens) {
          if (token.contains(needle)) {
            needle_matched = true;
            break;
          }
        }
        if (!needle_matched) {
          all_matched = false;
          break;
        }
      }

      if (all_matched)
        insert_file(child);

      recursive_search(needle_tokens, child);
    });
  }

  void set_current(DejaDup.FileTree.Node node)
  {
    clear();
    current = node;
    can_go_up = current != tree.root;
    current.children.for_each((name, child) => {
      insert_file(child);
    });
  }

  string collate_key(DejaDup.FileTree.Node node) {
    var prefix = node.kind == "dir" ? "0:" : "1:";
    var key = node.filename.collate_key_for_filename();
    return prefix + key;
  }

  void insert_file(DejaDup.FileTree.Node node)
  {
    var content_type = node.kind == "dir" ? ContentType.from_mime_type("inode/directory")
                                          : ContentType.guess(node.filename, null, null);
    var gicon = ContentType.get_icon(content_type);

    // Add symbolic link emblem if appropriate
    if (node.kind == "sym") {
      var emblem = new Emblem(new ThemedIcon("emblem-symbolic-link"));
      gicon = new EmblemedIcon(gicon, emblem);
    }

    // Get relative path to current node
    DejaDup.FileTree.Node iter = node;
    string path = null;
    while (iter.parent != current) {
      if (path == null)
        path = iter.parent.filename;
      else
        path = Path.build_filename(iter.parent.filename, path);
      iter = iter.parent;
    }

    insert_with_values(null, -1,
                       Column.FILENAME, node.filename,
                       Column.SORT_KEY, collate_key(node),
                       Column.GICON, gicon,
                       Column.PATH, path);
  }

  void handle_listed_files(DejaDup.OperationFiles op, DejaDup.FileTree tree)
  {
    this.tree = tree;
    set_current(tree.root);
  }
}
