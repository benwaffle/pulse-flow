project('pulse-flow', ['vala', 'c'])

deps = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gtk+-3.0'),

    dependency('gflow-0.2'),
    dependency('gtkflow-0.2'),

    dependency('libpulse'),
    dependency('libpulse-mainloop-glib'),
]

src = files([
    'src/Pulse.vala',
    'src/Nodes.vala',
    'src/App.vala'
])

executable('pulse-flow',
            src,
            dependencies: deps,
            vala_args: ['--vapidir=' + meson.current_source_dir()])
