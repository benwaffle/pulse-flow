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
    Gtk.Scale volumescale;
    Gtk.Label volumelabel = new Gtk.Label ("100% (0.00dB)");
    CVolume vols;

    public PASink (Pulse pa) {
        this.pa = pa;
        sink = new GFlow.SimpleSink (0);
        sink.name = "input";
        (sink as GFlow.SimpleSink).max_sources = -1U;
        add_sink (sink);

        volumescale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL,
            PulseAudio.Volume.MUTED, PulseAudio.Volume.UI_MAX, PulseAudio.Volume.NORM/100.0);
        volumescale.set_value (PulseAudio.Volume.NORM);
        volumescale.draw_value = false;
        volumescale.add_mark (PulseAudio.Volume.NORM, Gtk.PositionType.BOTTOM, "100% (0dB)");
        volumescale.value_changed.connect (() => {
            for (var i=0; i<vols.channels; ++i)
                vols.values[i] = (uint32) volumescale.get_value ();
            pa.ctx.set_sink_volume_by_index (index, vols, null);
        });

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        box.pack_start (volumescale, true, true);
        box.pack_end (volumelabel, false, false);
        child.add (box);
    }

    public void update (SinkInfo info) {
        index = info.index;
        name = "(Sink #%u) %s".printf (index, info.description);
        vols = info.volume;
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

        // TODO handle multiple channels
        var volume = info.volume.values[0];
        volumelabel.label = "%s (%s)".printf (volume.sprint (), volume.sw_sprint_dB ());
        volumescale.set_value (volume);
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
        (sink as GFlow.SimpleSink).max_sources = -1U;
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
