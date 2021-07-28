/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class DejaDup.FileTree : Object
{
  public Node root {get; private set; default = null;}
  public string skipped_root {get; private set; default = null;}
  public string old_home {get; private set; default = null;}

  public class Node : Object {
    public weak Node parent {get; internal set;}
    public string filename {get; internal set;}
    public FileType kind {get; construct;}
    public HashTable<string, Node> children {get; internal set;}
    public string[] search_tokens; // empty, but can be filled in by consumers

    public Node(Node? parent, string filename, FileType kind) {
      Object(parent: parent, filename: filename, kind: kind);
    }

    construct {
      children = new HashTable<string, Node>(str_hash, str_equal);
    }
  }

  construct {
    root = new DejaDup.FileTree.Node(null, "", FileType.DIRECTORY);
  }

  // Undoes any translations we performed on path (like switching homes)
  public string original_path(string path)
  {
    if (old_home != null) {
      return path.replace(Environment.get_home_dir(), old_home);
    }
    return path;
  }

  public File node_to_file(Node node)
  {
    return File.new_for_path(Path.build_filename("/", node_to_path(node)));
  }

  public string node_to_path(Node node)
  {
    string filename = node.filename;
    Node iter = node.parent;
    while (iter != null && iter.parent != null) {
      filename = Path.build_filename(iter.filename, filename);
      iter = iter.parent;
    }

    if (skipped_root == null)
      return filename;
    else
      return Path.build_filename(skipped_root, filename);
  }

  public Node? file_to_node(File file, bool allow_partial = false)
  {
    string remainder;
    string prefix = "";
    if (skipped_root != null)
      prefix = skipped_root;

    // remove skipped_root prefix
    var prefix_file = File.new_for_path("/%s".printf(prefix));
    remainder = prefix_file.get_relative_path(file);
    if (remainder == null)
      return null;

    // split file path into lookup parts
    var parts = remainder.split("/");

    // find the node from those parts
    var node = root;
    foreach (var part in parts) {
      var child = node.children.lookup(part);
      if (child == null)
        return allow_partial ? node : null;
      node = child;
    }
    return node;
  }

  public Node add(string file, FileType kind, out bool created = null)
  {
    created = false;

    var parts = file.split("/");
    var iter = root;
    var parent = iter;

    for (int i = 0; i < parts.length; i++) {
      if (parts[i] == "")
        continue; // skip leading empty part from root '/' or doubled slashes

      parent = iter;
      iter = parent.children.lookup(parts[i]);
      if (iter == null) {
        var part_kind = (i == parts.length - 1) ? kind : FileType.DIRECTORY;
        iter = new Node(parent, parts[i], part_kind);
        parent.children.insert(parts[i], iter);
        created = true;
      }
    }

    return iter;
  }

  public void finish()
  {
    // Ignore our cache metadata file (and any empty parents) -- user shouldn't
    // need to know they exist.
    clear_metadir();

    rewrite_single_home();
    clear_metadir(); // clear again in case it came from new home

    var old_root = root; // keep reference for duration of this method

    // Set root based on first folder with more than one child
    while (root.children.length == 1) {
      var child = root.children.get_values().data;
      if (child.kind != FileType.DIRECTORY)
        break;
      root = child;
    }
    if (root.parent != null)
      skipped_root = node_to_path(root);
    root.filename = "";
    root.parent = null;
    old_root = null;
  }

  void erase_node_and_parents(Node node)
  {
    var iter = node;
    while (iter.parent != null) {
      var parent = iter.parent;
      if (iter.children.length == 0)
        parent.children.remove(iter.filename);
      if (parent.children.length > 0)
        break;
      iter = parent;
    }
  }

  void clear_metadir()
  {
    var metadir_node = file_to_node(DejaDup.get_metadir(), true);
    if (metadir_node != null)
      erase_node_and_parents(metadir_node);
  }

  // If a user is restoring into a new setup, their old username (and thus
  // home) might be different from their new one. If we only see a single old
  // home directory, we can stitch that up transparently for them.
  void rewrite_single_home()
  {
    Node[] homes = {};

    var slash_root = root.children.lookup("root");
    if (slash_root != null)
      homes += slash_root;

    var slash_home = root.children.lookup("home");
    if (slash_home != null)
      slash_home.children.get_values().@foreach((x) => {homes += x;});

    if (homes.length != 1)
      return;

    var single_home_file = node_to_file(homes[0]);
    var my_home_file = File.new_for_path(Environment.get_home_dir());
    if (single_home_file.equal(my_home_file))
      return;

    bool created;
    var my_home_node = add(my_home_file.get_path(), FileType.DIRECTORY, out created);
    if (!created)
      return;

    old_home = single_home_file.get_path();

    // OK, we have one home and it's not ours. Let's move nodes.
    // This doesn't try to handle crazy configs, like a home inside another.
    my_home_node.children = homes[0].children;
    foreach (var child in my_home_node.children.get_values()) {
      child.parent = my_home_node;
    }
    homes[0].children = null;
    erase_node_and_parents(homes[0]);
  }
}
