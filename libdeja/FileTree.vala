/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

public class DejaDup.FileTree : Object
{
  public Node root {get; private set; default = null;}
  string skipped_root {get; private set; default = null;}

  public class Node : Object {
    public weak Node parent {get; internal set;}
    public string filename {get; internal set;}
    public string kind {get; construct;}
    public HashTable<string, Node> children {get; construct;}
    public string[] search_tokens; // empty, but can be filled in by consumers

    public Node(Node? parent, string filename, string kind) {
      Object(parent: parent, filename: filename, kind: kind);
    }

    construct {
      children = new HashTable<string, Node>(str_hash, str_equal);
    }
  }

  construct {
    root = new DejaDup.FileTree.Node(null, "", "dir");
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

  public Node? file_to_node(File file)
  {
    string remainder;

    // remove skipped_root prefix
    if (skipped_root != null) {
      var skipped_file = File.new_for_path("/%s".printf(skipped_root));
      remainder = skipped_file.get_relative_path(file);
      if (remainder == null)
        return null;
    } else {
      remainder = file.get_path();
    }

    // split file path into lookup parts
    var parts = remainder.split("/");

    // find the node from those parts
    var node = root;
    foreach (var part in parts) {
      node = node.children.lookup(part);
      if (node == null)
        return null;
    }
    return node;
  }

  public void add(string file, string kind)
  {
    var parts = file.split("/");
    var iter = root;
    var parent = iter;

    for (int i = 0; i < parts.length; i++) {
      parent = iter;
      iter = parent.children.lookup(parts[i]);
      if (iter == null) {
        var part_kind = (i == parts.length - 1) ? kind : "dir";
        iter = new Node(parent, parts[i], part_kind);
        parent.children.insert(parts[i], iter);
      }
    }
  }

  public void finish()
  {
    // Ignore our cache metadata file (and any empty parents) -- user shouldn't
    // need to know they exist.
    clear_metadir();

    var old_root = root; // keep reference for duration of this method

    // Set root based on first folder with more than one child
    while (root.children.length == 1) {
      var child = root.children.get_values().data;
      if (child.kind != "dir")
        break;
      root = child;
    }
    if (root.parent != null)
      skipped_root = node_to_path(root);
    root.filename = "";
    root.parent = null;
    old_root = null;
  }

  void clear_metadir()
  {
    var metadir_node = file_to_node(DejaDup.get_metadir());
    if (metadir_node == null)
      return;

    // Delete the first (metadir) node, then all parents that are empty
    var node_iter = metadir_node;
    while (node_iter.parent != null) {
      var parent = node_iter.parent;
      parent.children.remove(node_iter.filename);
      if (parent.children.length > 0)
        break;
      node_iter = parent;
    }
  }
}
