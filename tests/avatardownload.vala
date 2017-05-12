

void simple () {
  var loop = new GLib.MainLoop ();
  Twitter.get ().init ();

  var avatar_widget = new AvatarWidget ();
  Twitter.get ().get_avatar.begin (10, "http://i.imgur.com/GzdoOMu.jpg",
                                             avatar_widget, 48, false, () => {
    assert (avatar_widget.surface != null);

    loop.quit ();
  });

  loop.run ();
}

void cached () {
  var loop = new GLib.MainLoop ();
  Twitter.get ().init ();

  var avatar_widget = new AvatarWidget ();
  var avatar_widget2 = new AvatarWidget ();
  Twitter.get ().get_avatar.begin (10, "http://i.imgur.com/GzdoOMu.jpg",
                                   avatar_widget, 48, false, () => {
    assert (avatar_widget.surface != null);

    Twitter.get ().get_avatar.begin (10, "http://i.imgur.com/GzdoOMu.jpg",
                                     avatar_widget2, 48, false, () => {

      assert (avatar_widget2.surface != null);
      assert (avatar_widget2.surface == avatar_widget.surface);
      loop.quit ();
    });
  });

  loop.run ();
}

void double_download ()
{
  var loop = new GLib.MainLoop ();
  Twitter.get ().init ();

  var avatar_widget = new AvatarWidget ();
  var avatar_widget2 = new AvatarWidget ();
  Twitter.get ().get_avatar.begin (10, "http://i.imgur.com/GzdoOMu.jpg",
                                   avatar_widget, 48, false, () => {
    assert (avatar_widget.surface != null);
    loop.quit ();
  });

  Twitter.get ().get_avatar.begin (10, "http://i.imgur.com/GzdoOMu.jpg",
                                   avatar_widget2, 48, false, () => {
    assert (avatar_widget2.surface != null);
  });

  loop.run ();
}

int main (string[] args) {
  GLib.Test.init (ref args);
  Gtk.init (ref args);
  Settings.init ();
  Utils.init_soup_session ();

  GLib.Test.add_func ("/avatar-download/simple", simple);
  GLib.Test.add_func ("/avatar-download/cached", cached);
  GLib.Test.add_func ("/avatar-download/double_download", double_download);

  /* We can't test load_avatar_for_user_id here since we can't
     properly use Accounts and their proxies... */


  return GLib.Test.run ();
}
