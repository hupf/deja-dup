/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class FileStore : Gtk.ListStore
{
  public bool can_go_up {get; private set; default = false;}
  public string search_filter {get; set; default = null;}

  // If you reorder these, you might need to update the ui files that hardcode
  // these column numbers.
  public enum Column {
    FILENAME = 0,
    SORT_KEY,
    ICON, // never set, but left blank as an aid to Browser, which does some iconview tricks
    GICON,
    MODIFIED,
    PATH,
  }

  public void register_operation(DejaDup.OperationFiles op)
  {
    root = new FileNode(null, "", "dir", null);
    set_current(root);

    op.listed_current_files.connect(handle_listed_files);
    op.done.connect(handle_done);
  }

  public bool go_down(Gtk.TreePath path)
  {
    Gtk.TreeIter iter;
    if (!get_iter(out iter, path))
      return false;

    string filename;
    @get(iter, Column.FILENAME, out filename);

    var child = current.children.lookup(filename);
    if (child == null || child.type != "dir")
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

  class FileNode {
    public weak FileNode parent;
    public string filename;
    public string type;
    public DateTime modified;
    public HashTable<string, FileNode> children;
    public string[] search_tokens;

    public FileNode(FileNode? parent_in, string filename_in, string type_in, DateTime? modified_in) {
      filename = filename_in;
      parent = parent_in;
      type = type_in;
      modified = modified_in;
      children = new HashTable<string, FileNode>(str_hash, str_equal);
    }
  }

  FileNode root;
  FileNode current;
  string skipped_root = null;

  construct {
    set_column_types({typeof(string), typeof(string), typeof(Gdk.Pixbuf),
                      typeof(Icon), typeof(DateTime), typeof(string)});

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
      return Path.build_filename(get_full_path_from_node(current), filename);
    else
      return Path.build_filename(get_full_path_from_node(current), rel_path, filename);
  }

  string get_full_path_from_node(FileNode node)
  {
    string filename = node.filename;
    FileNode iter = node.parent;
    while (iter != null && iter.parent != null) {
      filename = Path.build_filename(iter.filename, filename);
      iter = iter.parent;
    }

    if (skipped_root == null)
      return filename;
    else
      return Path.build_filename(skipped_root, filename);
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

  void recursive_search(string[] needle_tokens, FileNode node)
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
          ascii_tokens[unicode_tokens.length + i] = ascii_tokens[i];
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

  void set_current(FileNode node)
  {
    clear();
    current = node;
    can_go_up = current != root;
    current.children.for_each((name, child) => {
      insert_file(child);
    });
  }

  string collate_key(FileNode node) {
    var prefix = node.type == "dir" ? "0:" : "1:";
    var key = node.filename.collate_key_for_filename();
    return prefix + key;
  }

  void insert_file(FileNode node)
  {
    var content_type = node.type == "dir" ? ContentType.from_mime_type("inode/directory")
                                          : ContentType.guess(node.filename, null, null);
    var gicon = ContentType.get_icon(content_type);

    // Get relative path to current node
    FileNode iter = node;
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
                       Column.MODIFIED, node.modified,
                       Column.PATH, path);
  }

  void handle_listed_files(DejaDup.OperationFiles op, string date, string file, string type)
  {
    var parts = file.split("/");
    var iter = root;
    var parent = iter;
    var datetime = new DateTime.from_iso8601(date, new TimeZone.utc());

    for (int i = 0; i < parts.length; i++) {
      parent = iter;
      iter = parent.children.lookup(parts[i]);
      if (iter == null) {
        var part_type = (i == parts.length - 1) ? type : "dir";
        iter = new FileNode(parent, parts[i], part_type, datetime);
        parent.children.insert(parts[i], iter);
      }
    }
  }

  void clear_metadir()
  {
    // parse metadir path
    var part_iter = DejaDup.get_metadir();
    List<string> parts = null;
    while (part_iter.has_parent(null)) {
      parts.prepend(part_iter.get_basename());
      part_iter = part_iter.get_parent();
    }

    // find the metadir node
    var metadir_node = root;
    foreach (var part in parts) {
      metadir_node = metadir_node.children.lookup(part);
      if (metadir_node == null)
        return;
    }

    // now delete the first (metadir) node, then all parents that are empty
    var node_iter = metadir_node;
    while (node_iter.parent != null) {
      var parent = node_iter.parent;
      parent.children.remove(node_iter.filename);
      if (parent.children.length > 0)
        break;
      node_iter = parent;
    }
  }

  void handle_done(DejaDup.Operation op, bool success, bool cancelled, string? detail)
  {
    if (!success || cancelled)
      return;

    // Ignore our cache metadata file (and any empty parents) -- user shouldn't
    // need to know they exist.
    clear_metadir();

    // Set root based on first folder with more than one child
    while (root.children.length == 1) {
      var child = root.children.get_values().data;
      if (child.type != "dir")
        break;
      root = child;
    }
    if (root.parent != null)
      skipped_root = get_full_path_from_node(root.parent);
    root.parent = null;

    set_current(root);
  }
}
