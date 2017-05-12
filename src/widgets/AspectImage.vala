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

class AspectImage : Gtk.Widget {
  public Gdk.Pixbuf pixbuf  {
    set {
      if (value != null) {

        if (value != Twitter.no_banner) {
          start_animation ();
        }

        if (this.pixbuf_surface != null)
          this.old_surface = this.pixbuf_surface;

        this.pixbuf_surface = (Cairo.ImageSurface)Gdk.cairo_surface_create_from_pixbuf (value, 1,
                                                                                        this.get_window ());
        bg_color.alpha = 0.0;
      }
      this.queue_draw ();
    }
  }
  public string color_string {
    set {
      bg_color.parse (value);
    }
  }

  private Gdk.RGBA bg_color;
  private Cairo.Surface? old_surface;
  private Cairo.ImageSurface? pixbuf_surface = null;


  public AspectImage () {}

  construct {
    set_has_window (false);
  }

  private void start_animation () {
    if (!this.get_realized ())
      return;

    alpha = 0.0;
    in_transition = true;
    this.start_time = this.get_frame_clock ().get_frame_time ();
    this.add_tick_callback (fade_in_cb);
  }

  private double alpha = 0.0;
  private int64 start_time;
  private bool in_transition = false;
  private bool fade_in_cb (Gtk.Widget widget, Gdk.FrameClock frame_clock) {
    int64 now = frame_clock.get_frame_time ();
    double t = (double)(now - start_time) / TRANSITION_DURATION;

    if (t >= 1.0) {
      t = 1.0;
      in_transition = false;
    }

    this.alpha = ease_out_cubic (t);
    this.queue_draw ();

    return t < 1.0;
  }

  public override void get_preferred_height_for_width (int width,
                                                       out int min_height,
                                                       out int nat_height) {
    if (pixbuf_surface == null) {
      min_height = 0;
      nat_height = 1;
      return;
    }

    min_height = pixbuf_surface.get_height ();
    nat_height = pixbuf_surface.get_height ();
  }


  public override Gtk.SizeRequestMode get_request_mode () {
    return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
  }

  public override bool draw (Cairo.Context ct) {
    int width  = get_allocated_width ();
    int height = get_allocated_height ();

    double scale_x = 1.0;
    if (bg_color.alpha == 0.0)
      scale_x = width  / (double)pixbuf_surface.get_width ();

    scale_x = double.max (scale_x, 1.0);

    ct.rectangle (0, 0, width, height);
    ct.scale (scale_x, 1.0);


    ct.push_group ();

    if (this.old_surface != null) {
      ct.set_source_surface (this.old_surface, 0, 0);
      ct.paint ();
    } else if (bg_color.alpha > 0.0) {
      ct.set_source_rgba (bg_color.red, bg_color.green, bg_color.blue, bg_color.alpha);
      ct.fill ();
    }else
      alpha = 1.0;


    if (bg_color.alpha == 0.0) {
      int x = (int)(width - (pixbuf_surface.get_width () * scale_x)) / 2;
      ct.set_source_surface (this.pixbuf_surface, x, 0);
    } else
      ct.set_source_rgba (bg_color.red, bg_color.green, bg_color.blue, bg_color.alpha);

    if (in_transition)
      ct.paint_with_alpha (alpha);
    else
      ct.paint ();

    ct.pop_group_to_source ();

    ct.set_operator (Cairo.Operator.OVER);
    ct.paint ();

    return Gdk.EVENT_PROPAGATE;
  }
}
