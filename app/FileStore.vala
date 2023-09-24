/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class FileStore : Object, ListModel
{
  public DejaDup.FileTree tree {get; private set; default = null;}
  public bool can_go_up {get; private set; default = false;}
  public string search_filter {get; set; default = null;}

  public void clear() {
    var removed = clear_full();
    items_changed(0, removed, 0);
  }

  public void register_operation(DejaDup.OperationFiles op)
  {
    current = null;
    tree = null;

    clear();
    op.listed_current_files.connect(handle_listed_files);
  }

  public bool go_down(uint position)
  {
    var child = items.get(position).node;
    if (child.kind != FileType.DIRECTORY)
      return false;

    set_current(child);
    return true;
  }

  public bool go_up()
  {
    if (!can_go_up)
      return false;

    set_current(current.parent);
    return true;
  }

  public File get_file(uint position)
  {
    return File.new_for_path(get_full_path(position));
  }

  // ListModel interface

  public Type get_item_type() {
    return typeof(DejaDup.FileTree.Node);
  }

  public uint get_n_items() {
    return items.length;
  }

  public GLib.Object? get_item(uint position) {
    return items.get(position);
  }

  public class Item : Object {
    public DejaDup.FileTree.Node node {get; construct;}
    public string filename {get { return node.filename; }}
    public string collate_key {get; construct;}
    public string path {get; construct;}
    public Icon icon {get; construct;}
    public Icon emblem {get; construct;}
    public string description {get; construct;}

    internal Item(DejaDup.FileTree.Node node, string collate_key,
                  string? path, Icon icon, Icon? emblem, string? description)
    {
      Object(node: node, collate_key: collate_key, path: path, icon: icon,
             emblem: emblem, description: description);
    }
  }

  ////

  DejaDup.FileTree.Node current;
  GenericArray<Item> items;

  construct {
    items = new GenericArray<Item>();

    notify["search-filter"].connect(update_search);
  }

  int clear_full() {
    var old_len = items.length;
    items.remove_range(0, old_len);
    return old_len;
  }

  string get_full_path(uint position)
  {
    var item = items.get(position);
    var node_path = tree.node_to_path(tree.root);
    return Path.build_filename("/", node_path, item.path, item.filename);
  }

  void update_search()
  {
    if (search_filter == null || search_filter == "") {
      set_current(current);
      return;
    }

    var needle_tokens = search_filter.tokenize_and_fold("", null);

    var removed = clear_full();
    recursive_search(needle_tokens, tree.root); // per HIG, search globally
    sort();
    items_changed(0, removed, items.length);
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
    var removed = clear_full();
    items_changed(0, removed, 0);
    current = node;
    can_go_up = current != tree.root;
    current.children.for_each((name, child) => {
      insert_file(child);
    });
    sort();
    items_changed(0, 0, items.length);
  }

  void sort() {
    items.sort((a, b) => {
      return strcmp(a.collate_key, b.collate_key);
    });
  }

  void insert_file(DejaDup.FileTree.Node node)
  {
    var prefix = node.kind == FileType.DIRECTORY ? "0:" : "1:";
    var key = node.filename.casefold().collate_key_for_filename();
    var collate_key = prefix + key;

    // icon
    var content_type = node.kind == FileType.DIRECTORY ?
                       ContentType.from_mime_type("inode/directory") :
                       ContentType.guess(node.filename, null, null);
    var icon = ContentType.get_icon(content_type);

    Icon emblem = null;
    if (node.kind == FileType.SYMBOLIC_LINK) {
      emblem = new ThemedIcon("emblem-symbolic-link");
    }

    string description = _("File");
    if (node.kind == FileType.SYMBOLIC_LINK) {
      description = _("Link");
    } else if (node.kind == FileType.DIRECTORY) {
      description = _("Folder");
    }

    // Get relative path from root node
    unowned var iter = node;
    string path = "";
    while (iter.parent != tree.root) {
      if (path == "")
        path = iter.parent.filename;
      else
        path = Path.build_filename(iter.parent.filename, path);
      iter = iter.parent;
    }

    items.add(new Item(node, collate_key, path, icon, emblem, description));
  }

  void handle_listed_files(DejaDup.OperationFiles op, DejaDup.FileTree tree) {
    this.tree = tree;
    set_current(tree.root);
  }
}
