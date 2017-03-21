project('pulse-flow', 'vala', 'c',
        default_options: ['default_library=static']) # link to gtkflow statically

flow = subproject('libgtkflow', default_options: ['enable_valadoc=false'])

deps = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gtk+-3.0'),

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
            include_directories: [
              flow.get_variable('gflow_inc'),
              flow.get_variable('gtkflow_inc')
            ],
            link_with: [
              flow.get_variable('gflow'),
              flow.get_variable('gtkflow')
            ],
            vala_args: ['--vapidir=' + meson.current_source_dir()],
            install: true)
