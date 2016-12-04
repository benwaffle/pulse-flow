class App : Gtk.Application {
    Pulse pa;
    GtkFlow.NodeView nodeview;

    public App () {
        Object (application_id: "me.iofel.pulse-flow",
                flags: ApplicationFlags.FLAGS_NONE);
    }

    public override void activate () {
        var win = new Gtk.ApplicationWindow (this);
        var sw = new Gtk.ScrolledWindow (null, null);
        nodeview = new GtkFlow.NodeView ();
        sw.add (nodeview);
        win.add (sw);

        win.set_default_size (1000, 600);
        win.show_all ();

        pa = new Pulse ();
        pa.new_node.connect (this.add);
        pa.delete_node.connect (this.delete);
    }

    // positioning
    int srcx = 20;
    int sinkx = 500;
    int srcy = 20;
    int sinky = 20;

    private void add (PANode node) {
        nodeview.add_with_child (node, node.child);

        // position the nodes
        int x, y;
        if (node is PASource || node is PASinkInput) {
            x = srcx;
            y = srcy;
            srcy += 150;
        } else {
            x = sinkx;
            y = sinky;
            sinky += 150;
        }

        nodeview.set_node_position (node, x, y);
    }

    private void delete (PANode node) {
        if (node is PASource || node is PASinkInput) {
            srcy -= 150;
        } else {
            sinky -= 150;
        }
        nodeview.remove_node (node);
    }
}

int main (string[] args) {
    return new App ().run (args);
}
