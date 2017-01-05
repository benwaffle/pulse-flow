using PulseAudio;

/**
 * A class to represent a node in our app
 */
abstract class PANode : GFlow.SimpleNode {
    public Pulse pa;
    public Gtk.Box child = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
    public uint32 index = PulseAudio.INVALID_INDEX;

    construct {
        this.deletable = false;
        this.resizable = false;
    }
}

class PASource : PANode {
    public GFlow.Source src;

    public PASource (Pulse pa) {
        this.pa = pa;
        src = new GFlow.SimpleSource (0);
        src.name = "output";
        add_source (src);
    }

    public void update (SourceInfo info) {
        index = info.index;
        name = "(Source #%u) %s".printf (index, info.description);
    }
}

class PASink : PANode {
    uint32 monitor = PulseAudio.INVALID_INDEX;
    public GFlow.Sink sink;

    public PASink (Pulse pa) {
        this.pa = pa;
        sink = new GFlow.SimpleSink (0);
        sink.name = "input";
        add_sink (sink);
    }

    public void update (SinkInfo info) {
        index = info.index;
        name = "(Sink #%u) %s".printf (index, info.description);
        if (monitor != info.monitor_source) {
            monitor = info.monitor_source;

            if (monitor != PulseAudio.INVALID_INDEX) {
                // get info for its monitor
                pa.ctx.get_sink_info_by_index (monitor, (ctx, i, eol) => {
                    if (i == null)
                        return;
                    var src = new GFlow.SimpleSource (0);
                    src.name = "monitor";
                    add_source (src);
                });
            } else {
                // delete monitor
            }
        }
    }
}

class PASinkInput : PANode {
    GFlow.Source src;
    Gtk.Image img;

    public PASinkInput (Pulse pa) {
        this.pa = pa;
        img = new Gtk.Image.from_icon_name ("dialog-question", Gtk.IconSize.BUTTON);
        child.pack_start (img, false, false);
        src = new GFlow.SimpleSource (0);
        src.name = "output";
        add_source (src);
    }

    public void update (SinkInputInfo info) {
        index = info.index;
        name = "(Sink Input #%u) %s".printf (index, info.name);

        if (Proplist.PROP_APPLICATION_ICON_NAME in info.proplist) {
            img.set_from_icon_name (info.proplist.gets (Proplist.PROP_APPLICATION_ICON_NAME), Gtk.IconSize.BUTTON);
        }

        var sink = pa.sinks[info.sink];
        src.unlink_all ();
        src.link (sink.sink);
    }
}

class PASourceOutput : PANode {
    GFlow.Sink sink;

    public PASourceOutput (Pulse pa) {
        this.pa = pa;
        sink = new GFlow.SimpleSink (0);
        sink.name = "input";
        add_sink (sink);
    }

    public void update (SourceOutputInfo info) {
        index = info.index;
        name = "(Source Output #%u) %s".printf (index, info.name);

        var src = pa.sources[info.source];
        src.unlink_all ();
        sink.link (src.src);
    }
}
