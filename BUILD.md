# AGE Project Build Guide

This document outlines how to initialize the submodules, build the Godot engine, build the Godot C++ bindings, and compile the custom extensions for this project on a fresh machine.

## 1. System Dependencies

Before compiling, ensure you have the required build tools and libraries installed.

**Arch Linux (Pacman):**
```bash
sudo pacman -S --needed base-devel scons freetype2 libpng bzip2 brotli zlib pkgconf
```

**Ubuntu/Debian (APT):**
```bash
sudo apt-get update
sudo apt-get install build-essential scons libfreetype-dev libpng-dev libbz2-dev libbrotli-dev zlib1g-dev pkg-config
```

## 2. Clone and Initialize Submodules

When checking out the project for the first time, you need to pull in the git submodules (`godot` and `addons/imgui-godot`):

```bash
git submodule update --init --recursive
```

### 2.1 ImGui-Godot Submodule Restructuring
The `imgui-godot` plugin is nested inside a subfolder in its repository. To ensure Godot can find the files correctly at `res://addons/imgui-godot/`, you must merge the nested plugin directory upwards:
```bash
rsync -a addons/imgui-godot/addons/imgui-godot/ addons/imgui-godot/
```

### 2.2 Patching ImGui-Godot for Linux
By default, the `imgui-godot` build script tries to download dependencies via `vcpkg`. If you prefer to use system libraries (as installed in Step 1), you need to patch `addons/imgui-godot/gdext/SConstruct` to use `pkg-config` instead of `vcpkg`. (Note: We have currently patched it locally on this machine).

## 3. Build Godot

First, you must compile the Godot engine library since this project links against it:

```bash
cd godot
scons p=linuxbsd target=template_release library_type=shared_library builtin_sdl=no builtin_libpng=no vulkan=yes disable_path_overrides=no -j8
cd ..
```

## 4. Build godot-cpp Bindings

Next, compile the C++ bindings that the extensions rely on:

```bash
cd godot-cpp
scons platform=linux target=template_release -j8
cd ..
```

## 5. Build GDExtensions

Now compile both the main game extension (`aga`) and the `imgui-godot` plugin extension:

```bash
# Build the main 'aga' extension
scons platform=linux target=template_release -j8

# Build the imgui-godot extension
cd addons/imgui-godot/gdext
scons platform=linux target=template_release -j8
cd ../../../
```

## 6. Install FMOD Libraries

The FMOD audio plugin requires proprietary binaries that are not included in source control. 
You must obtain the FMOD Engine Linux binaries and place them into the `addons/fmod/libs/linux/` directory.

Required files include:
- `libfmod.so` / `libfmodL.so`
- `libfmodstudio.so` / `libfmodstudioL.so`
- `libGodotFmod.linux.template_release.x86_64.so` (and debug variants)

Once placed, Godot will be able to load the FMOD extension properly.
