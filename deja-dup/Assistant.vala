/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 2 -*-
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: Canonical Ltd
 * SPDX-FileCopyrightText: Michael Terry
 */

using GLib;

/**
 * Yes, this is a silly reimplementation of Gtk.Assistant.
 * But Gtk.Assistant has some ridiculous map/unmap logic that resets the page
 * history when unmapped and generally doesn't work when unmapped.  Since
 * continuing to work when hidden is important for us, this is a
 * reimplementation of just the bits we use.
 */
public class Assistant : Hdy.Window
{
  public signal void response(int response);
  public signal void canceled();
  public signal void closed();
  public signal void resumed();
  public signal void prepare(Gtk.Widget page);
  public signal void forward();
  public signal void backward();
  public bool last_op_was_back {get; private set; default = false;}

  public enum Type {
    NORMAL, INTERRUPT, CHECK, PROGRESS, FINISH
  }

  protected string default_title;
  Hdy.HeaderBar header_bar;
  Gtk.Widget back_button;
  protected Gtk.Widget forward_button;
  Gtk.Widget cancel_button;
  Gtk.Widget close_button;
  Gtk.Widget resume_button;
  Gtk.Widget apply_button;
  protected Gtk.Box page_box;
  uint inhibit_id;

  public class PageInfo {
    public Gtk.Widget page;
    public string title = "";
    public Type type;
    public string forward_text = "";
  }

  bool interrupt_can_continue = true;
  bool interrupted_from_hidden = false;
  weak List<PageInfo> interrupted;

  protected bool can_resume = false;

  public weak List<PageInfo> first_shown = null;
  public weak List<PageInfo> current;
  List<PageInfo> infos;

  protected const int CUSTOM_RESPONSE = -1;
  protected const int APPLY = 1;
  protected const int BACK = 2;
  protected const int FORWARD = 3;
  protected const int CANCEL = 4;
  protected const int CLOSE = 5;
  protected const int RESUME = 6;

  construct
  {
    add_css_class("dialog");

    deletable = false;
    infos = new List<PageInfo>();

    var dialog_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
    set_child(dialog_box);

    header_bar = new Hdy.HeaderBar();
    header_bar.show_title_buttons = false;
    dialog_box.append(header_bar);

    page_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
    page_box.hexpand = true;
    page_box.vexpand = true;
    dialog_box.append(page_box);

    response.connect(handle_response);

    application = DejaDupApp.get_instance();
  }

  ~Assistant()
  {
    debug("Finalizing Assistant\n");
    set_inhibited(false);
  }

  public void allow_forward(bool allow)
  {
    if (current != null && forward_button != null)
      forward_button.sensitive = allow;
  }

  void handle_response(int resp)
  {
    switch (resp) {
    case BACK: go_back(); break;
    case APPLY:
    case FORWARD: go_forward(); break;
    default:
    case CANCEL: canceled(); break;
    case CLOSE: closed(); break;
    case RESUME: resumed(); break;
    case CUSTOM_RESPONSE: break;
    }
  }

  public bool is_interrupted()
  {
    return interrupted != null;
  }

  public void skip()
  {
    // During prepare, if a page wants to be skipped, it calls this.
    if (last_op_was_back)
      go_back();
    else
      go_forward();
  }

  static bool is_interrupt_type(Type type)
  {
    return type == Type.INTERRUPT || type == Type.CHECK;
  }

  public void go_back()
  {
    weak List<PageInfo> next;
    if (interrupted != null)
      next = interrupted.prev;
    else {
      next = current.prev;
      while (next != null && is_interrupt_type(next.data.type))
        next = next.prev;
    }

    if (next != null) {
      last_op_was_back = true;
      current = next;
      page_changed();
      backward();
    }
  }

  public void go_forward()
  {
    weak List<PageInfo> next;
    if (interrupted != null) {
      next = interrupted;
      if (interrupted_from_hidden)
        hide();
    }
    else {
      next = (current == null) ? infos : current.next;
      while (next != null && is_interrupt_type(next.data.type))
        next = next.next;
    }

    if (next != null) {
      last_op_was_back = false;
      current = next;
      page_changed();
      forward();
    }
  }

  public void go_to_page(Gtk.Widget page)
  {
    weak List<PageInfo> i = infos;
    while (i != null) {
      if (i.data.page == page) {
        current = i;
        page_changed();
        break;
      }
      i = i.next;
    }
  }

  public void interrupt(Gtk.Widget page, bool can_continue = true, bool stay_visible = false)
  {
    weak List<PageInfo> was = current;
    interrupt_can_continue = can_continue;
    go_to_page(page);
    if (!visible && !stay_visible) { // If we are interrupting from a hidden mode
      interrupted_from_hidden = true;
    }
    interrupted = was;
  }

  void use_title(PageInfo info)
  {
    if (info.title == "")
      title = default_title;
    else
      title = info.title;
  }

  void page_changed()
  {
    return_if_fail(current != null);

    interrupted = null;
    interrupted_from_hidden = false;
    weak PageInfo info = current.data;

    prepare(info.page);

    // Listeners of prepare may have changed current on us, so only proceed
    // if they haven't.
    if (current.data.page == info.page) {
      if (first_shown == null && info.type != Type.PROGRESS)
        first_shown = current;

      use_title(info);
      set_buttons();
      set_inhibited(info.type == Type.PROGRESS);

      var child = page_box.get_first_child();
      if (child != null) {
        child.hide();
        page_box.remove(child);
      }
      page_box.append(info.page);
      info.page.show();

      reset_size(info.page);

      var w = get_focus();
      if (w != null && w.get_type() == typeof(Gtk.Label))
        ((Gtk.Label)w).select_region(-1, -1);
    }
  }
  void button_clicked(Gtk.Button button)
  {
    response(button.get_data("response-id"));
  }

  protected Gtk.Button add_button(string label, int response_id)
  {
    var btn = new Gtk.Button.with_mnemonic(label);
    btn.receives_default = true;
    btn.set_data("response-id", response_id);
    btn.clicked.connect(button_clicked);
    if (response_id == CANCEL)
      header_bar.pack_start(btn);
    else
      header_bar.pack_end(btn);
    return btn;
  }

  protected void make_button_default(Gtk.Widget button)
  {
    set_default_widget(button);
    button.add_css_class("default");
    button.add_css_class("suggested-action");
  }

  protected virtual void set_buttons()
  {
    return_if_fail(current != null);

    weak PageInfo info = current.data;

    bool show_cancel = false, show_back = false, show_forward = false,
         show_close = false, show_resume = false;
    bool has_default = false;
    string forward_text = info.forward_text;

    switch (info.type) {
    default:
    case Type.NORMAL:
      show_cancel = true;
      show_back = current.prev != null && current != first_shown;
      show_forward = true;
      break;
    case Type.INTERRUPT:
      show_cancel = true;
      if (interrupt_can_continue) {
        show_forward = true;
        forward_text = _("Co_ntinue");
      }
      break;
    case Type.CHECK:
      show_cancel = true;
      show_forward = true;
      forward_text = C_("verb", "_Test");
      break;
    case Type.PROGRESS:
      show_cancel = true;
      if (can_resume)
        show_resume = true;
      break;
    case Type.FINISH:
      show_close = true;
      break;
    }

    var area = header_bar;
    if (cancel_button != null) {
      area.remove(cancel_button); cancel_button = null;}
    if (close_button != null) {
      area.remove(close_button); close_button = null;}
    if (back_button != null) {
      area.remove(back_button); back_button = null;}
    if (resume_button != null) {
      area.remove(resume_button); resume_button = null;}
    if (forward_button != null) {
      area.remove(forward_button); forward_button = null;}
    if (apply_button != null) {
      area.remove(apply_button); apply_button = null;}

    if (show_forward) {
      forward_button = add_button(info.forward_text, FORWARD);
      if (!has_default)
        make_button_default(forward_button);
      has_default = true;
    }
    if (show_resume) {
      resume_button = add_button(_("_Resume Later"), RESUME);
      if (!has_default)
        make_button_default(resume_button);
      has_default = true;
    }
    if (show_back)
      back_button = add_button(_("_Back"), BACK);
    if (show_close) {
      close_button = add_button(_("_Close"), CLOSE);
      if (!has_default)
        make_button_default(close_button);
      has_default = true;
    }
    if (show_cancel)
      cancel_button = add_button(_("_Cancel"), CANCEL);
  }

  bool set_first_page()
  {
    current = null;
    go_forward();
    return false;
  }

  Gtk.Requisition page_box_req;
  public void append_page(Gtk.Widget page, Type type = Type.NORMAL, string forward_text = _("_Forward"))
  {
    var was_empty = infos == null;

    // enforce some sizing rules for pages
    page.hexpand = true;
    page.vexpand = true;

    var info = new PageInfo();
    info.page = page;
    info.type = type;
    info.forward_text = forward_text;
    infos.append(info);

    if (was_empty)
      page_box.get_preferred_size(null, out page_box_req);

    reset_size(page);

    if (was_empty)
      Idle.add(set_first_page);
  }

  void reset_size(Gtk.Widget page)
  {
    Gtk.Requisition pagereq;
    int boxw, boxh;
    page_box.get_size_request(out boxw, out boxh);
    page.get_preferred_size(null, out pagereq);
    page_box.set_size_request(int.max(boxw, pagereq.width + page_box_req.width),
                              int.max(boxh, pagereq.height + page_box_req.height));
  }

  public void set_page_title(Gtk.Widget page, string title)
  {
    foreach (PageInfo info in infos) {
      if (info.page == page) {
        info.title = title;
        if (current != null && current.data.page == page)
          use_title(info);
        break;
      }
    }
  }

  protected virtual uint inhibit(Gtk.Application app)
  {
    return 0;
  }

  void set_inhibited(bool inhibited)
  {
    var app = DejaDupApp.get_instance();

    if (inhibited && inhibit_id == 0)
      inhibit_id = this.inhibit(app);
    else if (!inhibited && inhibit_id > 0) {
      app.uninhibit(inhibit_id);
      inhibit_id = 0;
    }
  }
}
