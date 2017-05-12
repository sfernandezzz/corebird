/*  This file is part of corebird, a Gtk+ linux Twitter client.
 *  Copyright (C) 2013 Timm Bäder
 *
 *  corebird is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  corebird is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with corebird.  If not, see <http://www.gnu.org/licenses/>.
 */

class MediaVideoWidget : Gtk.Stack {
#if VIDEO
  private Gst.Element src;
  private Gst.Element sink;
  private Gtk.Widget area;
#endif
  private GLib.Cancellable cancellable;
  private Gtk.Label error_label = new Gtk.Label ("");
  private Gtk.ProgressBar video_progress = new Gtk.ProgressBar ();
  private uint video_progress_id = 0;

  private SurfaceProgress surface_progress;
  private string? media_url = null;

  public MediaVideoWidget (Cb.Media media) {
    GLib.return_val_if_fail (media.surface != null, null);

    this.cancellable = new GLib.Cancellable ();
    var image_surface = (Cairo.ImageSurface) media.surface;
    video_progress.show ();
    int h;
    video_progress.get_preferred_height (out h, null);
    this.set_size_request (image_surface.get_width (), image_surface.get_height () + h);
#if VIDEO

    debug ("Media type: %d", media.type);

    switch (media.type) {
      case Cb.MediaType.TWITTER_VIDEO:
      case Cb.MediaType.INSTAGRAM_VIDEO:
        this.media_url = media.url;
        /* Video will be started in init() */
      break;

      case Cb.MediaType.ANIMATED_GIF:
        fetch_real_url.begin (media.url, "<source video-src=\"(.*?)\" type=\"video/mp4\"");
      break;

      default:
        GLib.warn_if_reached ();
      break;
    }
#endif

    // set up error label
    error_label.margin = 20;
    error_label.wrap = true;
    error_label.selectable = true;
    error_label.show ();

    surface_progress = new SurfaceProgress ();
    surface_progress.surface = media.surface;
    surface_progress.show ();

    this.add (surface_progress);
    this.add (error_label);

    this.visible_child = surface_progress;
  }

  private bool progress_timeout_cb () {
#if VIDEO
    int64 duration_ns;
    int64 position_ns;

    this.src.query_duration (Gst.Format.TIME, out duration_ns);
    if (duration_ns > 0) {
      this.src.query_position (Gst.Format.TIME, out position_ns);
      double fraction = (double) position_ns / (double) duration_ns;
      this.video_progress.set_fraction (fraction);
    }
#endif

    return GLib.Source.CONTINUE;
  }

  private void start_progress_timeout () {
    this.video_progress_id = GLib.Timeout.add (100, progress_timeout_cb);
  }

  private void start_video () {
#if VIDEO
    assert (this.media_url != null);
    this.src.set ("uri", this.media_url);
    /* We will set it to PLAYING once we get an ASYNC_DONE message */
    this.src.set_state (Gst.State.PAUSED);
#endif
  }

  public void init () {
#if VIDEO
    var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
    this.src = Gst.ElementFactory.make ("playbin", "video");
    this.sink = Gst.ElementFactory.make ("gtksink", "gtksink");
    if (sink == null) {
      this.show_error ("Could not create a gtksink. Need gst-plugins-bad >= 1.6");
      critical ("Could not create a gtksink. Need gst-plugins-bad >= 1.6");
      return;
    }
    this.sink.get ("widget", out this.area);
    assert (this.area != null);
    assert (this.area is Gtk.DrawingArea);
    this.area.hexpand = true;
    this.area.vexpand = true;
    /* We will switch to the "video" child later after getting
       an ASYNC_DONE message from gstreamer */

    var bus = this.src.get_bus ();
    bus.add_watch (GLib.Priority.DEFAULT, watch_cb);

    this.src.set ("video-sink", this.sink);
    this.src.set ("ring-buffer-max-size", (10 * 1024 * 1024)); // 10 mb, ¯\_(ツ)_/¯
    uint flags;
    this.src.get ("flags",  out flags);
    this.src.set ("flags",  flags | (1 << 7)); // (1 << 7) = GST_PLAY_FLAG_DOWNLOAD


    box.add (this.area);
    video_progress.get_style_context ().add_class ("embedded-progress");
    box.add (this.video_progress);

    this.add_named (box, "video");

    if (this.media_url != null) {
      /* Set in constructor */
      this.start_video ();
    }

#endif
  }

  private void show_error (string error_message) {
    error_label.label = error_message;
    this.visible_child = error_label;
  }

  public override bool key_press_event (Gdk.EventKey evt) {
    stop ();
    return Gdk.EVENT_STOP;
  }

  private void stop () {
    cancellable.cancel ();
    if (video_progress_id != 0) {
      GLib.Source.remove (video_progress_id);
      video_progress_id = 0;
    }
#if VIDEO
    src.set_state (Gst.State.NULL);
#endif
  }

  public override void destroy () {
    stop ();
    base.destroy ();
  }

#if VIDEO
  private bool watch_cb (Gst.Bus bus, Gst.Message msg) {
    switch (msg.type) {
      case Gst.MessageType.BUFFERING:
        int percent;
        msg.parse_buffering (out percent);
        debug ("Buffering: %d%%", percent);
        this.surface_progress.progress = double.max (percent / 100.0, this.surface_progress.progress);
      break;

      case Gst.MessageType.EOS:
        this.src.seek (1.0, Gst.Format.TIME, Gst.SeekFlags.FLUSH,
                       Gst.SeekType.SET, 0,
                       Gst.SeekType.NONE, (int64)Gst.CLOCK_TIME_NONE);
      break;

      case Gst.MessageType.ASYNC_DONE:
        debug ("ASYNC DONE");
        this.visible_child_name = "video";
        start_progress_timeout ();
        this.src.set_state (Gst.State.PLAYING);
      break;

      case Gst.MessageType.ERROR:
        GLib.Error error;
        string debug;
        msg.parse_error (out error, out debug);
        show_error (debug);
        critical ("%s: %s", error.message, debug);
      break;
    }

    return true;
  }
#endif

  private async void fetch_real_url (string first_url, string regex_str) {
    var msg = new Soup.Message ("GET", first_url);
    cancellable.cancelled.connect (() => {
      SOUP_SESSION.cancel_message (msg, Soup.Status.CANCELLED);
    });
    SOUP_SESSION.queue_message (msg, (s, _msg) => {
      if (_msg.status_code != Soup.Status.OK) {
        if (_msg.status_code != Soup.Status.CANCELLED) {
          warning ("Status Code %u", _msg.status_code);
          show_error ("%u %s".printf (_msg.status_code, Soup.Status.get_phrase (_msg.status_code)));
        }
        fetch_real_url.callback ();
        return;
      }
      unowned string back = (string)_msg.response_body.data;
      try {
        var regex = new GLib.Regex (regex_str, 0);
        MatchInfo info;
        regex.match (back, 0, out info);
        string? real_url = info.fetch (1);
        debug ("Real url: %s", real_url);
        if (real_url == null) {
          this.show_error ("Error: Could not get real URL");
        } else {
          this.media_url = real_url;
          this.start_video ();
        }
      } catch (GLib.RegexError e) {
        warning ("Regex error: %s", e.message);
        this.show_error ("Regex error: %s".printf (e.message));
      }
      fetch_real_url.callback ();
    });
    yield;
  }

}
