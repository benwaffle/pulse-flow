using PulseAudio;

class Pulse : Object {
    public Context ctx;
    private GLibMainLoop loop;
    public HashTable<uint32, PANode> nodes;

    public signal void ready (Context ctx);

    public Pulse () {
        nodes = new HashTable<uint32, PANode> (direct_hash, direct_equal);
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
        Context.State state = ctx.get_state ();
        info (@"pa state = $state\n");

        if (ctx.get_state () == Context.State.READY) {
            ready (ctx);
        }
    }
}

abstract class PANode : GFlow.SimpleNode {
    public Gtk.Widget? child = null;
    public uint32 index = PulseAudio.INVALID_INDEX;
}

class PASource : PANode {
    public GFlow.Source src;

    public PASource (Pulse pa, SourceInfo i) {
        index = i.index;
        name = "(Input) " + i.description;

        src = new GFlow.SimpleSource (0);
        src.name = "output";
        add_source (src);

        // for (int x = 0; x < i.n_ports; ++x) {
        //     var src = new GFlow.SimpleSource (0);
        //     src.name = i.ports[x]->description;
        //     add_source (src);
        // }
    }
}

class PASink : PANode {
    uint32 monitor = PulseAudio.INVALID_INDEX;
    public GFlow.Sink sink;

    public PASink (Pulse pa, SinkInfo i) {
        index = i.index;
        name = "(Output) " + i.description;
        monitor = i.monitor_source;

        sink = new GFlow.SimpleSink (0);
        sink.name = "input";
        add_sink (sink);

        if (monitor != PulseAudio.INVALID_INDEX) {
            // get info for its monitor
            pa.ctx.get_sink_info_by_index (monitor, (ctx, i, eol) => {
                if (i == null)
                    return;
                var src = new GFlow.SimpleSource (0);
                src.name = "monitor";
                add_source (src);
            });
        }
    }
}

class PAApp : PANode {
    public PAApp (Pulse pa, SinkInputInfo i) {
        index = i.index;
        name = i.name;

        var src = new GFlow.SimpleSource (0);
        src.name = "output";
        add_source (src);

        var sink = pa.nodes.get (i.sink);
        if (sink is PASink) {
            src.link (((PASink)sink).sink);
        }
    }
}

class PAEnd : PANode {
    public PAEnd (Pulse pa, SourceOutputInfo i) {
        index = i.index;
        name = i.name;

        var sink = new GFlow.SimpleSink (0);
        sink.name = "input";
        add_sink (sink);

        var src = pa.nodes.get (i.source);
        if (src is PASource) {
            sink.link (((PASource)src).src);
        }
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
        sw.add (nodeview);
        win.add (sw);

        win.set_default_size (800, 600);
        win.show_all ();

        pa.ready.connect (ctx => {
            ctx.get_source_info_list ((ctx, i, eol) => {
                if (i == null)
                    return;
                // don't show monitors as separate nodes
                if (i.monitor_of_sink != PulseAudio.INVALID_INDEX)
                    return;
                add (new PASource (pa, i));
            });
            ctx.get_sink_info_list ((ctx, i, eol) => {
                if (i == null)
                    return;
                add (new PASink (pa, i));
            });
            ctx.get_sink_input_info_list ((ctx, i, eol) => {
                if (i == null)
                    return;
                add (new PAApp (pa, i));
            });
            ctx.get_source_output_info_list ((ctx, i, eol) => {
                if (i == null)
                    return;
                add (new PAEnd (pa, i));
            });

            ctx.set_subscribe_callback ((ctx, ev, idx) => {
                print (@"$ev #$idx\n");
            });
            ctx.subscribe (Context.SubscriptionMask.ALL, null);
        });
    }

    private void add (PANode node) {
        pa.nodes.insert (node.index, node);
        nodeview.add_node (node);
    }
}

int main (string[] args) {
    return new App ().run (args);
}
