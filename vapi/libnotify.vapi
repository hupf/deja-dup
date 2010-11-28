/* libnotify.vapi generated by vapigen, do not modify. */

[CCode (cprefix = "Notify", lower_case_cprefix = "notify_")]
namespace Notify {
	[CCode (cheader_filename = "libnotify/notify.h")]
	public class Notification : GLib.Object {
		[CCode (has_construct_function = false)]
		public Notification (string summary, string? body, string? icon);
		public void add_action (string action, string label, owned Notify.ActionCallback callback);
		public void clear_actions ();
		public void clear_hints ();
		public bool close () throws GLib.Error;
		public int get_closed_reason ();
		public void set_category (string category);
		public void set_hint (string key, GLib.Variant value);
		public void set_hint_byte (string key, uchar value);
		public void set_hint_byte_array (string key, uchar[] value, size_t len);
		public void set_hint_double (string key, double value);
		public void set_hint_int32 (string key, int value);
		public void set_hint_string (string key, string value);
		public void set_hint_uint32 (string key, uint value);
		public void set_icon_from_pixbuf (Gdk.Pixbuf icon);
		public void set_image_from_pixbuf (Gdk.Pixbuf image);
		public void set_timeout (int timeout);
		public void set_urgency (Notify.Urgency urgency);
		public bool show () throws GLib.Error;
		public bool update (string summary, string body, string icon);
		[NoAccessorMethod]
		public string body { owned get; set construct; }
		public int closed_reason { get; }
		[NoAccessorMethod]
		public string icon_name { owned get; set construct; }
		[NoAccessorMethod]
		public int id { get; set construct; }
		[NoAccessorMethod]
		public string summary { owned get; set construct; }
		public virtual signal void closed ();
	}
	[CCode (cprefix = "NOTIFY_URGENCY_", cheader_filename = "libnotify/notify.h")]
	public enum Urgency {
		LOW,
		NORMAL,
		CRITICAL
	}
	[CCode (cheader_filename = "libnotify/notify.h")]
	public delegate void ActionCallback (Notify.Notification notification, string action);
	[CCode (cheader_filename = "libnotify/notify.h")]
	public const int EXPIRES_DEFAULT;
	[CCode (cheader_filename = "libnotify/notify.h")]
	public const int EXPIRES_NEVER;
	[CCode (cheader_filename = "libnotify/notify.h")]
	public const int VERSION_MAJOR;
	[CCode (cheader_filename = "libnotify/notify.h")]
	public const int VERSION_MICRO;
	[CCode (cheader_filename = "libnotify/notify.h")]
	public const int VERSION_MINOR;
	[CCode (cheader_filename = "libnotify/notify.h")]
	public static unowned string get_app_name ();
	[CCode (cheader_filename = "libnotify/notify.h")]
	public static unowned GLib.List get_server_caps ();
	[CCode (cheader_filename = "libnotify/notify.h")]
	public static bool get_server_info (out unowned string ret_name, out unowned string ret_vendor, out unowned string ret_version, out unowned string ret_spec_version);
	[CCode (cheader_filename = "libnotify/notify.h")]
	public static bool init (string app_name);
	[CCode (cheader_filename = "libnotify/notify.h")]
	public static bool is_initted ();
	[CCode (cheader_filename = "libnotify/notify.h")]
	public static void uninit ();
}
