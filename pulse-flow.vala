using PulseAudio;

class Pulse : Object {
    Context ctx;
    GLibMainLoop loop;

    public signal void ready (Context ctx);

    public Pulse () {
        loop = new PulseAudio.GLibMainLoop ();
        ctx = new PulseAudio.Context (loop.get_api (), "me.iofel.pulse-flow");
        ctx.set_state_callback (this.state_cb);

        if (ctx.connect (null, PulseAudio.Context.Flags.NOFAIL) < 0) {
            print ("pa_context_connect() failed: %s\n", PulseAudio.strerror (ctx.errno ()));
        }
    }

    ~Pulse () {
        ctx.disconnect ();
    }

    public void state_cb (Context ctx) {
        Context.State state = ctx.get_state();
        info (@"pa state = $state\n");

        if (ctx.get_state () == Context.State.READY) {
            ready (ctx);
            /*
            ctx.get_sink_info_list ((ctx, i, eol) => {
                if (eol == 1)
                    return;
                print (@"Sink: $(i.description)\n");
            });
            ctx.get_source_info_list ((ctx, i, eol) => {
                if (eol == 1)
                    return;
                print (@"Source: $(i.description)\n");
            });
            */
        }
    }
}

class PASource : GFlow.SimpleNode {
    public Gtk.Widget child;

    public PASource (SourceInfo i) {
        name = i.description;
        var src = new GFlow.SimpleSource (0);
        src.name = "output";
        add_source (src);

        child = new Gtk.Label (name);
    }
}

class PASink : GFlow.SimpleNode {
    public Gtk.Widget child;

    public PASink (SinkInfo i) {
        name = i.description;
        var sink = new GFlow.SimpleSink (0);
        sink.name = "input";
        add_sink (sink);

        child = new Gtk.Label (name);
    }
}

class App : Gtk.Application {
    Pulse pa = new Pulse ();

    public App () {
        Object (application_id: "me.iofel.pulse-flow",
                flags: ApplicationFlags.FLAGS_NONE);
    }

    public override void activate () {
        var win = new Gtk.ApplicationWindow (this);
        var sw = new Gtk.ScrolledWindow (null, null);
        var nodeview = new GtkFlow.NodeView ();
        nodeview.editable = true;
        nodeview.show_types = true;
        sw.add (nodeview);
        win.add (sw);

        win.set_default_size (800, 600);
        win.show_all ();

        pa.ready.connect (ctx => {
            ctx.get_source_info_list ((ctx, i, eol) => {
                if (eol == 1)
                    return;
                var w = new PASource (i);
                nodeview.add_with_child (w, w.child);
            });
            ctx.get_sink_info_list ((ctx, i, eol) => {
                if (eol == 1)
                    return;
                var w = new PASink (i);
                nodeview.add_with_child (w, w.child);
            });
        });
    }
}

int main (string[] args) {
    return new App ().run (args);
}
