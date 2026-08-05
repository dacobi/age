Silly little partially vibecoded Greeting Card Generator using "LSDML" (SDL3/ImGui/C++/ffmpeg)
Turned in to mostly vibecoded Accidental Game Engine, with Godot integration

## Build Instructions

### Building Godot (Local Library)

To build the local Godot library used by this project, run the following command from the `godot` directory:

```bash
scons p=linuxbsd target=template_release library_type=shared_library builtin_sdl=no builtin_libpng=no vulkan=yes disable_path_overrides=no -j8
```

### Building the Project (GDExtension)

To build the project's GDExtension library (`aga`), run the following command from the project root directory:

```bash
scons platform=linux target=template_release
```

*Note: The `imgui-godot` addon is compiled automatically as part of the GDExtension build above. After building, you simply need to enable the plugin in Godot via `Project > Project Settings > Plugins`.*

Available `scons` options for the extension:
- `target`: `template_debug` (default), `template_release`
- `platform`: `linux` (default), `windows`, `macos`, `android`, `ios`
- `arch`: `x86_64` (default), `x86_32`, `arm64`, `arm32`

## Lua Functions Documentation

### `asdfg.lua` & `invaders.lua`
These files implement game lifecycle hooks:
- `onLivesReset()`: Triggered when player lives are reset.
- `onGameOver()`: Triggered when the game reaches a game-over state.
- `onGameWon()`: Triggered when the player wins the game.
- `onLiveLost()`: Triggered when the player loses a single life.
- `onLoosing()`: Triggered during the losing sequence/animation.
- `onNewScore()`: Triggered when a new score is achieved.

### `car_common.lua`
Provides shared logic for vehicle physics and telemetry:
- `initCarPhysicsDefaults()`: Initializes default physical properties and constants for cars.
- `renderCarPhysicsUI()`: Renders the ImGui interface for tweaking car physics parameters.
- `updateCarControlsAndPhysics(supercar, joy_handle, track, reset_prop_name)`: Updates the car's state based on joystick input and applies physics logic against the track.
- `updateCarTelemetry(supercar, frame_count)`: Updates and tracks telemetry data for the given car per frame.

### `fract.lua` & `heart.lua`
Provides coroutine-based task management:
- `spawn(f)`: Spawns a new coroutine from function `f` and inserts it into the `tasks` list.
- `run()`: Executes the running coroutine tasks.


## C++ Lua API Bindings

The following functions are exposed from `src/luascripting.cpp` and available globally in Lua scripts.

### Godot Scene & Nodes
- `godotLoadScene(path)`: Loads a Godot scene from the given path.
- `godotGetNodePointer(path)`: Returns the integer object ID of the node at `path`, or `nil` if not found.
- `godotSelectRoot()`: Selects the root node of the current scene tree.
- `godotSelectNode(path)`: Selects the node at `path`. Returns `true` on success.
- `godotSearchNode(name)`: Searches for a node by `name` recursively. Returns `true` on success.
- `godotGetNodeType([id])`: Returns the class type string of the selected node or the node with the given `id`.
- `godotGetName([id])`: Returns the name string of the selected node or given `id`.
- `godotGetChildCount([id])`: Returns the number of children (integer).
- `godotPrintHierarchy()`: Prints the current node hierarchy to the console.
- `godotRenameNode(name, [id])`: Renames the node.
- `godotSetCamera()`: Sets the selected node as the active camera. Returns `true` on success.
- `godotGetPos([id])`: Returns 3 floats: `x, y, z` representing the position.
- `godotSetPos(x, y, z, [id])`: Sets the node's position.
- `godotSetVisible(visible, [id])`: Sets the node's visibility (`boolean`).
- `godotGetScale([id])`: Returns 3 floats: `x, y, z` representing the scale.
- `godotSetScale(x, y, z, [id])`: Sets the node's scale.
- `godotMoveX(val, [id])`, `godotMoveY(val, [id])`, `godotMoveZ(val, [id])`: Translates the node along the respective axis by `val`.
- `godotMoveAndCollide(x, y, z, [id])`: Moves the node by `x, y, z` and stops on collision. Returns `true` if a collision occurred.
- `godotGetOverlappingAreas([id])`: Returns a table of strings containing names of overlapping areas.
- `godotCreateNode(type)`: Creates a new node of `type`. Returns `true` on success.
- `godotLoadNode(path, [x, y, z, id])`: Instances a scene/node from `path`, optionally at position `x, y, z`. Returns `true` on success.
- `godotDeleteNode([id])`: Queues the node for deletion.
- `godotAttachScript(script_path)`: Attaches a script to the selected node. Returns `true` on success.
- `godotSetProperty(name, value, [id])`: Sets a property. `value` can be a number, string, or boolean.
- `godotGetProperty(name, [id])`: Gets a property. Returns a number, string, or boolean depending on the property type.
- `godotWatchProperty(node_path, prop_name, value, file_path, [mode])`: Watches a property for changes.
- `godotWatchSignal(signal_name, file_path, [id])`: Watches a signal. Returns `true` on success.
- `godotRegisterImpulseProperty(name)`: Registers a property name as an impulse (forces an update every time).

### Godot Input & Settings
- `godotInputGetAxis(neg_action, pos_action)`: Returns a float representing the axis value between two actions.
- `godotInputIsActionPressed(action)`: Returns `true` if the input action is currently pressed.
- `godotLoadCarSettings()`: Loads car settings from `~/.age/car.ini`.
- `godotSaveCarSettings()`: Saves current car settings to `~/.age/car.ini`.
- `godotIsHighScore(score)`: Returns `true` if `score` qualifies as a new high score.
- `godotAddHighScore(name, score, level)`: Submits a new high score.
- `godotLoadHighScore()`, `godotSaveHighScore()`: Loads and saves the high score table.

### Application, Window & Flow Control
- `appQuit()`: Signals the application to terminate.
- `luaClearAndRun(filename)`: Clears the current script state and runs `filename`.
- `delay(ms)`: Blocks the Lua script for `ms` milliseconds.
- `delayKb(ms)`: Blocks the Lua script for `ms` milliseconds, but yields if keyboard activity is detected.
- `ioResizeEnabled(enabled)`: Enables or disables window resizing (`boolean`).
- `ioMaximizeWindow()`: Maximizes the OS window.
- `ioMouseCapture()`: Captures the mouse cursor within the window.
- `ioMouseRelease()`: Releases the captured mouse cursor.
- `setBG(bg_name)`: Sets the background visualizer mode.

### Global Variables & Synchronization
- `regGlobalVar(name, val)` / `unregGlobalVar(name)`: Registers or unregisters a global integer variable.
- `setGlobalVar(name, val)` / `getGlobalVar(name)`: Sets or gets a global integer variable.
- `regGlobalFloat(name, val)` / `unregGlobalFloat(name)`: Registers or unregisters a global float variable.
- `setGlobalFloat(name, val)` / `getGlobalFloat(name)`: Sets or gets a global float variable.
- `luaCreateMutex()`: Creates a mutex and returns an integer handle.
- `luaGetMutex(handle)`: Blocks until the mutex is locked.
- `luaTryMutex(handle)`: Attempts to lock the mutex. Returns `true` if successful.
- `luaCheckMutex(handle)`: Returns `true` if the mutex is currently locked.
- `luaReleaseMutex(handle)`: Unlocks the mutex.

### Audio & Recording
- `setAudio(path)`: Sets the audio file. Returns `true` on success.
- `playAudio()`: Plays the loaded audio.
- `stopAudio()`: Stops audio playback.
- `rewindAudio()`: Rewinds audio to the beginning.
- `skipAudio(seconds)`: Skips audio by `seconds`.
- `setAudioVolume(vol)`: Sets the volume (0 to 100).
- `startRecord(path)`: Starts video recording to `path`.
- `stopRecord([wait_frames])`: Stops video recording.
- `setRecordMax(max_seconds)`: Sets the maximum number of seconds to record.

### ImGui Integration
- `imguiBegin(title)`: Begins a new ImGui window with `title`.
- `imguiEnd()`: Ends the current ImGui window.
- `imguiRemoveWindow(title)`: Removes an ImGui window.
- `imguiText(text)`: Displays text.
- `imguiSeparator()`: Draws a horizontal separator.
- `imguiCheckbox(label, var_name)`: Draws a checkbox linked to a global float variable (1.0 = true, 0.0 = false).
- `imguiSliderFloat(label, var_name, min, max)`: Draws a float slider linked to a global float.
- `imguiButton(label, var_name)`: Draws a button. Sets the global float `var_name` to 1.0 when clicked.
- `imguiProgressBar(overlay_text, var_name)`: Draws a progress bar linked to a global float.
- `imguiSameLine()`: Places the next widget on the same horizontal line.
- `imGuiShow()` / `imGuiHide()`: Shows or hides the entire ImGui UI layer.

### Inputs (Keyboard, Mouse, Joystick)
- `ioKBClicked(key_str)`: Returns `true` if the key was just pressed (e.g., "w", "Space").
- `ioKBDown(key_str)`: Returns `true` if the key is held down.
- `ioKBUp(key_str)`: (Stubbed) Returns `false`.
- `ioMouseGetMotion()`: Returns 2 floats: `dx, dy` for mouse motion since the last check.
- `ioMouseBTNClicked(btn)`: Returns `true` if the mouse button (0=Left, 1=Right, 2=Middle) was just clicked.
- `ioMouseBTNDown(btn)`: Returns `true` if the mouse button is held down.
- `ioMouseBTNUp(btn)`: Returns `true` if the mouse button was just released.
- `ioMousePos()`, `ioMouseMoved()`, `ioMouseWheelMotion()`: (Stubbed).
- `ioJoystickOpen(device)`: Opens the joystick. Returns device ID or -1 on failure.
- `ioJoystickClose()`: (Stubbed).
- `ioJoystickGetAxis(device, axis)`: Returns the axis value (-1.0 to 1.0).
- `ioJoystickGetButtonDown(device, button)`: Returns `true` if the joy button is held.
- `ioJoystickGetButtonHit(device, button)`: Returns `true` if the joy button was just pressed.
- `ioJoystickGetHat(device, hat)`: Returns a bitmask for the D-pad (1=Up, 2=Right, 4=Down, 8=Left).
- `ioJoystickGetNumAxes()`, `ioJoystickGetNumButtons()`, `ioJoystickGetNumHats()`: Returns maximum capabilities.

### Visualizers (Plasma, Fractal, USD)
- `addBouncer(syntax)`: Adds a bouncer object.
- `delBouncer(index)`: Deletes a bouncer by index.
- `setParam(index, name, val)`: Sets a parameter on a bouncer.
- `selectPlasma(index)` / `selectFractal(index)` / `selectUSD(index)` / `selectGodot(index)`: Switches the active renderer mode.
- `setPlasmaParam(name, val)` / `setFractalParam(name, val)` / `setUSDParam(name, val)`: Sets parameters for the respective visualizer.
- `randomizePlasmaPalette()`, `randomizePlasmaXY()`, `randomizeFractalPalette()`: Randomizes visualizer parameters.
