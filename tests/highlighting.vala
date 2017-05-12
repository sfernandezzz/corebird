

// UTIL {{{

Gtk.TextBuffer create_buffer () {
  Gtk.TextBuffer buffer = new Gtk.TextBuffer (null);
  buffer.create_tag ("mention", null);
  buffer.create_tag ("link", null);
  buffer.create_tag ("hashtag", null);
  buffer.create_tag (TweetUtils.NO_SPELL_CHECK, null);

  return buffer;
}


// }}}

void normal () {
  Gtk.TextBuffer buffer = create_buffer ();
  buffer.set_text ("foobar @blabla");

  buffer.apply_tag.connect ((buffer, tag, start, end) => {
    string mention = buffer.get_text (start, end, false);
    assert (mention == "@blabla");
    assert (tag.name == "mention" || tag.name == TweetUtils.NO_SPELL_CHECK);
  });

  TweetUtils.annotate_text (buffer);
}

void mention () {
  Gtk.TextBuffer buffer = create_buffer ();
  buffer.apply_tag.connect ((buffer, tag, start, end) => {
    string s = buffer.get_text (start, end, false);
    assert (s == "@bla");
  });
  buffer.set_text ("A @bla B");
  TweetUtils.annotate_text (buffer);
}

void underline_mention () {
  Gtk.TextBuffer buffer = create_buffer ();
  buffer.apply_tag.connect ((buffer, tag, start, end) => {
    string s = buffer.get_text (start, end, false);
    message ("Underline mention: %s", s);
    assert (s == "@bla_foo");
  });
  buffer.set_text ("A @bla_foo B");
  TweetUtils.annotate_text (buffer);
}

void hashtag () {
  Gtk.TextBuffer buffer = create_buffer ();
  buffer.set_text ("foobar #hash.");

  int num = 0;
  buffer.apply_tag.connect ((buffer, tag, start, end) => {
    string mention = buffer.get_text (start, end, false);
    assert (mention == "#hash");
    assert (tag.name == "hashtag" || tag.name == TweetUtils.NO_SPELL_CHECK);
    num ++;
  });

  TweetUtils.annotate_text (buffer);
  assert (num == 2); // Actual tag AND no-spell-check tag
}

/* Sorry for this name. */
void non_default_mention () {

  Gtk.TextBuffer buffer = create_buffer ();
  buffer.set_text ("“@foobar");

  int num = 0;
  buffer.apply_tag.connect ((buffer, tag, start, end) => {
    string mention = buffer.get_text (start, end, false);
    assert (mention == "@foobar");
    assert (tag.name == "mention" || tag.name == TweetUtils.NO_SPELL_CHECK);
    num ++;
  });

  TweetUtils.annotate_text (buffer);
  assert (num == 2); // Actual tag AND no-spell-check tag
}


void main (string[] args) {
  GLib.Test.init (ref args);
  Gtk.init (ref args);
  new Corebird ();
  GLib.Test.add_func ("/highlighting/normal", normal);
  GLib.Test.add_func ("/highlighting/mention", mention);
  GLib.Test.add_func ("/highlighting/underline", underline_mention);
  GLib.Test.add_func ("/highlighting/hashtag", hashtag);
  GLib.Test.add_func ("/highlighting/non-default-mention", non_default_mention);

  GLib.Test.run ();
}
