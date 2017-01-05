using PulseAudio;

/**
 * A class to handle connections to pulseaudio and updates to info
 */
class Pulse : Object {
    public PulseAudio.Context ctx;
    private PulseAudio.GLibMainLoop loop;
    public HashTable<uint32, PASink> sinks = new HashTable<uint32, PASink> (direct_hash, direct_equal);
    public HashTable<uint32, PASource> sources = new HashTable<uint32, PASource> (direct_hash, direct_equal);
    public HashTable<uint32, PASinkInput> sinkinputs = new HashTable<uint32, PASinkInput> (direct_hash, direct_equal);
    public HashTable<uint32, PASourceOutput> sourceoutputs = new HashTable<uint32, PASourceOutput> (direct_hash, direct_equal);

    public signal void ready (Context ctx);
    public signal void new_node (PANode node);
    public signal void delete_node (PANode node);

    public Pulse () {
        loop = new PulseAudio.GLibMainLoop ();
        ctx = new PulseAudio.Context (loop.get_api (), "me.iofel.pulse-flow");
        ctx.set_state_callback (this.state_cb);
        ctx.set_subscribe_callback (this.subscribe_cb);

        if (ctx.connect (null, PulseAudio.Context.Flags.NOFAIL) < 0) {
            print ("pa_context_connect() failed: %s\n", PulseAudio.strerror (ctx.errno ()));
        }
    }

    ~Pulse () {
        ctx.disconnect ();
    }

    /**
     * Handle pulseaudio state changes
     */
    void state_cb (Context ctx) {
        Context.State state = ctx.get_state ();
        info (@"pa state = $state\n");

        if (ctx.get_state () == Context.State.READY) {
            ready (ctx);
            ctx.subscribe (Context.SubscriptionMask.ALL, null);
            ctx.get_sink_info_list (this.sink_cb);
            ctx.get_source_info_list (this.source_cb);
            ctx.get_sink_input_info_list (this.sink_input_cb);
            ctx.get_source_output_info_list (this.source_output_cb);
        }
    }

    /**
     * Handle any changes from pulseaudio
     */
    void subscribe_cb (Context ctx, Context.SubscriptionEventType ev, uint32 idx) {
        print (@"$ev $idx\n");

        var type = ev & Context.SubscriptionEventType.TYPE_MASK; // type (new, change, remove)
        var facility = ev & Context.SubscriptionEventType.FACILITY_MASK; // facility (sink, source, ...)

        if (type == Context.SubscriptionEventType.NEW || type == Context.SubscriptionEventType.CHANGE) {
            if (facility == Context.SubscriptionEventType.SINK)
                ctx.get_sink_info_by_index (idx, this.sink_cb);
            if (facility == Context.SubscriptionEventType.SOURCE)
                ctx.get_source_info_by_index (idx, this.source_cb);
            if (facility == Context.SubscriptionEventType.SINK_INPUT)
                ctx.get_sink_input_info (idx, this.sink_input_cb);
            if (facility == Context.SubscriptionEventType.SOURCE_OUTPUT)
                ctx.get_source_output_info (idx, this.source_output_cb);
        } else if (type == Context.SubscriptionEventType.REMOVE) {
            PANode? node = null;
            if (facility == Context.SubscriptionEventType.SINK) {
                node = this.sinks[idx];
                this.sinks.remove (idx);
            }
            if (facility == Context.SubscriptionEventType.SOURCE) {
                node = this.sources[idx];
                this.sources.remove (idx);
            }
            if (facility == Context.SubscriptionEventType.SINK_INPUT) {
                node = this.sinkinputs[idx];
                this.sinkinputs.remove (idx);
            }
            if (facility == Context.SubscriptionEventType.SOURCE_OUTPUT) {
                node = this.sourceoutputs[idx];
                this.sourceoutputs.remove (idx);
            }

            if (node != null) {
                node.index = PulseAudio.INVALID_INDEX;
                node.unlink_all ();
                delete_node (node);
            }
        }
    }

    void sink_cb (Context ctx, SinkInfo? info, int eol) {
        if (eol < 0) error (PulseAudio.strerror (ctx.errno ()));
        if (eol > 0) return;

        var sink = sinks[info.index];
        if (sink == null) {
            sink = new PASink (this);
            sinks[info.index] = sink;
            new_node (sink);
        }

        sink.update (info);
    }

    void source_cb (Context ctx, SourceInfo? info, int eol) {
        if (eol < 0) error (PulseAudio.strerror (ctx.errno ()));
        if (eol > 0) return;

        // monitors should not be their own nodes
        if (info.monitor_of_sink != PulseAudio.INVALID_INDEX)
            return;

        PASource source = sources[info.index];
        if (source == null) {
            source = new PASource (this);
            sources[info.index] = source;
            new_node (source);
        }

        source.update (info);
    }

    void sink_input_cb (Context ctx, SinkInputInfo? info, int eol) {
        if (eol < 0) error (PulseAudio.strerror (ctx.errno ()));
        if (eol > 0) return;

        // don't show nodes that play the volume changed sound
        if (info.name == "audio-volume-change");
            return;

        PASinkInput sinkinput = sinkinputs[info.index];
        if (sinkinput == null) {
            sinkinput = new PASinkInput (this);
            sinkinputs[info.index] = sinkinput;
            new_node (sinkinput);
        }

        sinkinput.update (info);
    }

    void source_output_cb (Context ctx, SourceOutputInfo? info, int eol) {
        if (eol < 0) error (PulseAudio.strerror (ctx.errno ()));
        if (eol > 0) return;

        // don't show pavucontrol's peak detect nodes
        if (Proplist.PROP_MEDIA_NAME in info.proplist &&
            info.proplist.gets (Proplist.PROP_MEDIA_NAME) == "Peak detect")
                return;

        PASourceOutput sourceoutput = sourceoutputs[info.index];
        if (sourceoutput == null) {
            sourceoutput = new PASourceOutput (this);
            sourceoutputs[info.index] = sourceoutput;
            new_node (sourceoutput);
        }

        sourceoutput.update (info);
    }
}
