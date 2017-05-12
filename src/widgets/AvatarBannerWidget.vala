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

public class AvatarBannerWidget : Gtk.Container {
  private const int MIN_HEIGHT      = 200;
  private const int MAX_HEIGHT      = 250;
  private const double BANNER_RATIO = 0.5; /* 320/640 */
  private const int AVATAR_SIZE     = 48;

  private unowned Account account;

  private PixbufButton set_banner_button;
  private PixbufButton set_avatar_button;

  public signal void avatar_changed (Gdk.Pixbuf new_avatar);
  public signal void banner_changed (Gdk.Pixbuf new_banner);

  public signal void avatar_clicked ();
  public signal void banner_clicked ();

  construct {
    this.set_has_window (false);
    get_style_context ().add_class ("avatar");

    /* set_banner_button */
    this.set_banner_button = new PixbufButton ();
    set_banner_button.show_all ();
    set_banner_button.clicked.connect (banner_clicked_cb);
    this.add (set_banner_button);

    /* set_avatar_button */
    this.set_avatar_button = new PixbufButton ();
    set_avatar_button.show_all ();
    set_avatar_button.clicked.connect (avatar_clicked_cb);
    this.add (set_avatar_button);
    Settings.get ().bind ("round-avatars", set_avatar_button, "round",
                          GLib.SettingsBindFlags.DEFAULT);

  }

  public void set_account (Account account) {
    this.account = account;
    fetch_banner.begin ();
    this.queue_draw ();
    set_avatar_button.set_bg ((Cairo.ImageSurface)account.avatar);
  }

  public override bool draw (Cairo.Context ct) {
    this.propagate_draw (set_banner_button, ct);
    this.propagate_draw (set_avatar_button, ct);

    return Gdk.EVENT_PROPAGATE;
  }

  private int get_avatar_x () {
    return (get_allocated_width () / 2) - (AVATAR_SIZE / 2);
  }

  private int get_avatar_y () {
    return get_allocated_height () - AVATAR_SIZE;
  }


  public override Gtk.SizeRequestMode get_request_mode () {
    return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
  }

  public override void get_preferred_width (out int min,
                                            out int nat) {
    min = AVATAR_SIZE + 40; // 20px margin on either side
    nat = (int)(MIN_HEIGHT * (1 / BANNER_RATIO));
  }

  public override void get_preferred_height_for_width (int width,
                                                       out int min,
                                                       out int nat) {
    min = (AVATAR_SIZE / 3) + MIN_HEIGHT;
    nat = int.max (min, int.min (MAX_HEIGHT, (int)(width * BANNER_RATIO) + (AVATAR_SIZE / 3)));
  }

  private async void fetch_banner () {
    if (account.banner_url == null) {
      set_banner_button.set_pixbuf (Twitter.no_banner);
      return;
    }

    var pixbuf = yield Utils.download_pixbuf (account.banner_url + "/600x200");
    this.set_banner_button.set_pixbuf (pixbuf);
  }

  public override void size_allocate (Gtk.Allocation allocation) {
    base.size_allocate  (allocation);

    Gtk.Requisition child_requisition;
    Gtk.Allocation child_allocation = Gtk.Allocation();

    /* set_banner_button */
    set_banner_button.get_preferred_size (out child_requisition, null);
    child_allocation.x = allocation.x;
    child_allocation.y = allocation.y;
    child_allocation.width = int.max (allocation.width, child_requisition.width);
    child_allocation.height = (int)(allocation.width * BANNER_RATIO);
    child_allocation.height = int.max (allocation.height - (AVATAR_SIZE / 2), child_requisition.height);
    set_banner_button.size_allocate (child_allocation);


    /* set_avatar_button */
    set_avatar_button.get_preferred_size (out child_requisition, null);
    child_allocation.x = get_avatar_x () + allocation.x;
    child_allocation.y = get_avatar_y () + allocation.y;
    child_allocation.width = AVATAR_SIZE;
    child_allocation.height = AVATAR_SIZE;
    set_avatar_button.size_allocate (child_allocation);
  }

  public override void add (Gtk.Widget w) {
    w.set_parent (this);
  }

  public override void remove (Gtk.Widget w) {
    w.unparent ();
  }

  public override void forall_internal (bool include_internals, Gtk.Callback cb) {
    cb (set_banner_button);
    cb (set_avatar_button);
  }

  private void banner_clicked_cb () {
    this.banner_clicked ();
  }

  private void avatar_clicked_cb () {
    this.avatar_clicked ();
  }

  public void set_avatar (Gdk.Pixbuf avatar) {
    set_avatar_button.set_pixbuf (avatar);
  }

  public void set_banner (Gdk.Pixbuf banner) {
    set_banner_button.set_pixbuf (banner);
  }
}
