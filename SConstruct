#!/usr/bin/env python
import os
import sys

env = Environment(ENV=os.environ)

opts = Variables()
opts.Add(EnumVariable('target', 'Target Build Type', 'template_debug', allowed_values=['template_debug', 'template_release']))
opts.Add(EnumVariable('platform', 'Target Platform', 'linux', allowed_values=['linux', 'windows', 'macos', 'android', 'ios']))
opts.Add(EnumVariable('arch', 'Target Architecture', 'x86_64', allowed_values=['x86_64', 'x86_32', 'arm64', 'arm32']))
opts.Update(env)

env.Append(CPPPATH=['godot-cpp/gdextension', 'godot-cpp/include', 'godot-cpp/gen/include', 'src', 'addons/imgui-godot/gdext/imgui', 'addons/imgui-godot/gdext/include'])

env.Append(CPPFLAGS=['-fPIC', '-std=c++17'])
env.Append(CPPDEFINES=['IMGUI_USER_CONFIG="\\"imconfig-godot.h\\""'])

if env['target'] == 'template_debug':
    env.Append(CPPFLAGS=['-g', '-O0'])
else:
    env.Append(CPPFLAGS=['-O3'])

if env['platform'] == 'linux':
    env.Append(LIBS=['pthread'])
    env.ParseConfig('pkg-config --cflags --libs lua5.4')

# Find sources
sources = Glob('src/*.cpp')
sources += Glob('addons/imgui-godot/gdext/imgui/*.cpp')

# Include godot-cpp
if env['platform'] == 'linux':
    env.Append(LIBPATH=['godot-cpp/bin'])
    env.Append(LIBS=['godot-cpp.linux.' + env['target'] + '.' + env['arch']])

# Build GDExtension library
lib = env.SharedLibrary('bin/aga.' + env['platform'] + '.' + env['target'] + '.' + env['arch'] + '.so', sources)
Default(lib)
