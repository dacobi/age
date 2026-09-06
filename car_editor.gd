extends Node3D

@onready var combiner = $CarCombiner
var mat_body = StandardMaterial3D.new()
var mat_red = StandardMaterial3D.new()
var mat_cyan = StandardMaterial3D.new()
var mat_green = StandardMaterial3D.new()

var lua_manager = null
var debug_parent = null
var swept_body: CSGMesh3D = null

var dragging_node = null
var drag_plane = Plane()
var drag_offset = Vector3()

var history_spine_undo = []
var history_spine_redo = []
var history_kf_undo = []
var history_kf_redo = []
var history_prim_undo = []
var history_prim_redo = []
var history_timer = 0.0

var prev_selected_mode = -1
var prev_selected_spine = -1
var prev_selected_kf = -1
var prev_selected_prim = -1
var prev_selected_vert = -1
var open_dialog: FileDialog
var save_dialog: FileDialog
var current_file_path: String = ""


var car_data = {}

func _ready():
    mat_body.albedo_color = Color(0.02, 0.08, 0.45)
    mat_body.metallic = 1.0
    mat_body.roughness = 0.05
    mat_body.clearcoat_enabled = true
    mat_body.clearcoat = 1.0
    mat_body.clearcoat_roughness = 0.05
    mat_red.albedo_color = Color(1, 0, 0)
    mat_cyan.albedo_color = Color(0, 1, 1)
    mat_green.albedo_color = Color(0, 1, 0)
    mat_red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat_cyan.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat_green.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    
    lua_manager = get_node_or_null("/root/LuaManager")
    open_dialog = FileDialog.new()
    open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    open_dialog.access = FileDialog.ACCESS_FILESYSTEM
    open_dialog.filters = ["*.json ; Car Files"]
    open_dialog.file_selected.connect(_on_file_opened)
    add_child(open_dialog)
    
    save_dialog = FileDialog.new()
    save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
    save_dialog.access = FileDialog.ACCESS_FILESYSTEM
    save_dialog.filters = ["*.json ; Car Files"]
    save_dialog.file_selected.connect(_on_file_saved)
    add_child(save_dialog)

    
    pass
    _push_state_to_lua()
    _build_car()

func _on_file_opened(path: String):
    current_file_path = path
    var f = FileAccess.open(path, FileAccess.READ)
    var text = f.get_as_text()
    var json = JSON.new()
    if json.parse(text) == OK:
        car_data = json.get_data()
        if typeof(car_data) == TYPE_DICTIONARY:
            lua_manager.set_global_float("ce_file_loaded", 1.0)
            lua_manager.set_global_float("ce_spine_count", car_data["spine"].size())
            lua_manager.set_global_float("ce_kf_count", car_data["keyframes"].size())
            lua_manager.set_global_float("ce_prim_count", car_data.get("primitives", []).size())
            _build_car()

func _on_file_saved(path: String):
    current_file_path = path
    var text = JSON.stringify(car_data, "  ")
    var f = FileAccess.open(path, FileAccess.WRITE)
    f.store_string(text)
    f.close()
func _generate_shape_rectangle(count: int) -> Array:
    var arr = []
    # Boxy: width 1.0, height 0.5 to -0.5
    for i in range(count):
        var t = float(i) / count
        var x = 0.0
        var y = 0.0
        if t < 0.25: # Top
            x = lerp(0.0, 1.0, t / 0.25)
            y = 0.5
        elif t < 0.5: # Right Side
            x = 1.0
            y = lerp(0.5, -0.5, (t - 0.25) / 0.25)
        elif t < 0.75: # Bottom
            x = lerp(1.0, 0.0, (t - 0.5) / 0.25)
            y = -0.5
        else: # Center seam (should not happen for full half-profile if we only generate one side, wait!
            # The original generates a half profile! X goes from 0 to 1 back to 0?
            pass
            
        # Actually original _generate_half_circle generates from bottom to top?
        # Let's check original!
    return arr

func _generate_shape_ellipsoid(count: int) -> Array:
    var arr = []
    for i in range(count):
        var angle = -PI/2.0 + PI * (float(i) / (count - 1))
        # angle goes from -PI/2 to PI/2 (right half)
        arr.append({"x": cos(angle) * 1.0, "y": sin(angle) * 0.5})
    return arr

func _generate_shape_pill(count: int) -> Array:
    var arr = []
    for i in range(count):
        var t = float(i) / (count - 1)
        var x = 0.0
        var y = 0.0
        if t < 0.25: # Bottom flat
            y = -0.5
            x = lerp(0.0, 0.8, t / 0.25)
        elif t < 0.75: # Round side
            var angle = -PI/2.0 + PI * ((t - 0.25) / 0.5)
            x = 0.8 + cos(angle) * 0.2
            y = sin(angle) * 0.5
        else: # Top flat
            y = 0.5
            x = lerp(0.8, 0.0, (t - 0.75) / 0.25)
        arr.append({"x": x, "y": y})
    return arr
    
func _generate_shape_rect(count: int) -> Array:
    var arr = []
    for i in range(count):
        var t = float(i) / (count - 1)
        var x = 0.0
        var y = 0.0
        if t < 0.333: # Bottom flat
            y = -0.5
            x = lerp(0.0, 1.0, t / 0.333)
        elif t < 0.666: # Right flat
            x = 1.0
            y = lerp(-0.5, 0.5, (t - 0.333) / 0.333)
        else: # Top flat
            y = 0.5
            x = lerp(1.0, 0.0, (t - 0.666) / 0.334)
        arr.append({"x": x, "y": y})
    return arr

func _generate_half_circle(count):
    var verts = []
    # We want a dome resting on a flat bottom (Y=0)
    # Right half: 48 vertices on quarter circle, 8 vertices on flat bottom
    var curve_pts = max(1, count - 8)
    var bottom_pts = count - curve_pts
    
    # Quarter circle from top (0, 1) to right edge (1, 0)
    for i in range(curve_pts):
        var theta = (float(i) / max(1, curve_pts - 1)) * (PI / 2.0)
        verts.append({"x": sin(theta), "y": cos(theta)})
        
    # Flat bottom from right edge (1, 0) to center (0, 0)
    for i in range(bottom_pts):
        var t = float(i + 1) / float(bottom_pts)
        verts.append({"x": lerp(1.0, 0.0, t), "y": 0.0})
        
    return verts

func _save_data():
    var f = FileAccess.open("res://car_editor_temp.json", FileAccess.WRITE)
    f.store_string(JSON.stringify(car_data, "  "))

func _build_car():
    for child in combiner.get_children():
        child.queue_free()
    if debug_parent:
        debug_parent.queue_free()
        debug_parent = null
        
    _build_sweep()
    for prim in car_data.get("primitives", []):
        _build_primitive(prim)
    _build_debug_visuals()

# ---------------------------------------------------------
# MOUSE DRAG LOGIC
# ---------------------------------------------------------
func _input(event):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                var cam = get_viewport().get_camera_3d()
                if not cam: return
                var space = get_world_3d().direct_space_state
                var origin = cam.project_ray_origin(event.position)
                var normal = cam.project_ray_normal(event.position)
                var q = PhysicsRayQueryParameters3D.create(origin, origin + normal * 1000.0)
                q.collide_with_areas = true
                var result = space.intersect_ray(q)
                if result and result.collider.has_meta("type"):
                    dragging_node = result.collider
                    drag_plane = Plane(cam.global_transform.basis.z, result.position)
                    drag_offset = dragging_node.global_position - result.position
                    
                    # Notify Lua of selection change
                    _handle_selection(dragging_node)
            else:
                if dragging_node:
                    _commit_history(int(lua_manager.get_global_float("ce_selected_mode")))
                    _save_data()
                    dragging_node = null
                    _build_car()

    elif event is InputEventMouseMotion and dragging_node:
        var cam = get_viewport().get_camera_3d()
        if not cam: return
        var ray_origin = cam.project_ray_origin(event.position)
        var ray_dir = cam.project_ray_normal(event.position)
        var intersect = drag_plane.intersects_ray(ray_origin, ray_dir)
        if intersect:
            var new_pos = intersect + drag_offset
            
            # Lock spine and handles to X=0
            var type = dragging_node.get_meta("type")
            if type == "spine" or type == "handle_in" or type == "handle_out":
                new_pos.x = 0.0
                
            _apply_drag(dragging_node, new_pos)
            _push_state_to_lua() # Update sliders in real-time
            
            # Fast rebuild during drag (avoids deleting nodes)
            _build_sweep()
            
            # Move the visual sphere
            if dragging_node.get_parent():
                for sibling in dragging_node.get_parent().get_children():
                    if sibling is CSGSphere3D and sibling.position.distance_to(dragging_node.position) < 0.01:
                        sibling.position = new_pos
                        break
            dragging_node.position = new_pos

func _handle_selection(node):
    if not lua_manager: return
    var type = node.get_meta("type")
    if type == "spine" or type == "handle_in" or type == "handle_out":
        lua_manager.set_global_float("ce_selected_mode", 1.0)
        lua_manager.set_global_float("ce_selected_spine", float(node.get_meta("index") + 1))
    elif type == "kf":
        lua_manager.set_global_float("ce_selected_mode", 2.0)
        lua_manager.set_global_float("ce_selected_kf", float(node.get_meta("kf_index") + 1))
        lua_manager.set_global_float("ce_selected_vert", float(node.get_meta("vert_index") + 1))
    _push_state_to_lua()
    
    # Update colors instantly
    _update_visual_colors()

func _apply_drag(node, pos: Vector3):
    var type = node.get_meta("type")
    if type == "spine":
        var pt = car_data["spine"][node.get_meta("index")]
        pt["px"] = pos.x; pt["py"] = pos.y; pt["pz"] = pos.z
    elif type == "handle_in":
        var pt = car_data["spine"][node.get_meta("index")]
        var sp_pos = Vector3(pt["px"], pt["py"], pt["pz"])
        var tin = (pos - sp_pos) * 2.0
        pt["in_x"] = tin.x; pt["in_y"] = tin.y; pt["in_z"] = tin.z
    elif type == "handle_out":
        var pt = car_data["spine"][node.get_meta("index")]
        var sp_pos = Vector3(pt["px"], pt["py"], pt["pz"])
        var tout = (pos - sp_pos) * 2.0
        pt["out_x"] = tout.x; pt["out_y"] = tout.y; pt["out_z"] = tout.z
    elif type == "kf":
        var kf = car_data["keyframes"][node.get_meta("kf_index")]
        var v = kf["verts"][node.get_meta("vert_index")]
        
        # We need to project the 3D mouse pos back into the 2D keyframe space!
        # The keyframe's Transform3D on the curve:
        var trans = node.get_meta("trans")
        var local_pos = trans.affine_inverse() * pos
        # Update 2D coords. Only positive X is allowed for the base curve.
        v["x"] = max(0.0, local_pos.x)
        v["y"] = local_pos.y

# ---------------------------------------------------------
# LUA -> GODOT SYNC
# ---------------------------------------------------------
func _process(delta):

    # File Menu Triggers
    if lua_manager.get_global_float("ce_trigger_open") > 0.5:
        lua_manager.set_global_float("ce_trigger_open", 0.0)
        open_dialog.popup_centered_ratio(0.5)
        
    if lua_manager.get_global_float("ce_trigger_save_as") > 0.5:
        lua_manager.set_global_float("ce_trigger_save_as", 0.0)
        save_dialog.popup_centered_ratio(0.5)
        
    if lua_manager.get_global_float("ce_trigger_save") > 0.5:
        lua_manager.set_global_float("ce_trigger_save", 0.0)
        if current_file_path == "":
            save_dialog.popup_centered_ratio(0.5)
        else:
            _on_file_saved(current_file_path)
            
    if lua_manager.get_global_float("ce_trigger_new_car") > 0.5:
        lua_manager.set_global_float("ce_trigger_new_car", 0.0)
        var count = lua_manager.get_global_int("ce_new_car_verts")
        var shape = lua_manager.get_global_int("ce_new_car_shape")
        var verts = []
        if shape == 0: verts = _generate_shape_rect(count)
        elif shape == 1: verts = _generate_shape_ellipsoid(count)
        elif shape == 2: verts = _generate_shape_pill(count)
        else: verts = _generate_half_circle(count)
        
        car_data = {
            "spine": [
                {"px": 0, "py": 0, "pz": 3, "in_x": 0, "in_y": 0, "in_z": 1, "out_x": 0, "out_y": 0, "out_z": -1},
                {"px": 0, "py": 0, "pz": 0, "in_x": 0, "in_y": 0, "in_z": 1, "out_x": 0, "out_y": 0, "out_z": -1},
                {"px": 0, "py": 0, "pz": -3, "in_x": 0, "in_y": 0, "in_z": 1, "out_x": 0, "out_y": 0, "out_z": -1}
            ],
            "keyframes": [
                {"t": 0.0, "verts": verts.duplicate(true)},
                {"t": 0.5, "verts": verts.duplicate(true)},
                {"t": 1.0, "verts": verts.duplicate(true)}
            ],
            "primitives": [],
            "vertices_per_curve": count
        }
        current_file_path = ""
        lua_manager.set_global_float("ce_file_loaded", 1.0)
        lua_manager.set_global_float("ce_spine_count", 3.0)
        lua_manager.set_global_float("ce_kf_count", 3.0)
        lua_manager.set_global_float("ce_prim_count", 0.0)
        _build_car()

    # Keyframe tools triggers
    if lua_manager.get_global_float("ce_trigger_copy_kf") > 0.5:
        lua_manager.set_global_float("ce_trigger_copy_kf", 0.0)
        var k_idx = int(lua_manager.get_global_float("ce_selected_kf")) - 1
        if k_idx > 0 and k_idx < car_data["keyframes"].size():
            car_data["keyframes"][k_idx]["verts"] = car_data["keyframes"][k_idx-1]["verts"].duplicate(true)
            _commit_history(2)
            _push_state_to_lua()
            _build_car()
            
    if lua_manager.get_global_float("ce_trigger_scale_kf") > 0.5:
        lua_manager.set_global_float("ce_trigger_scale_kf", 0.0)
        var scale_x = lua_manager.get_global_float("ce_kf_scale_x")
        var scale_y = lua_manager.get_global_float("ce_kf_scale_y")
        lua_manager.set_global_float("ce_kf_scale_x", 1.0)
        lua_manager.set_global_float("ce_kf_scale_y", 1.0)
        
        var k_idx = int(lua_manager.get_global_float("ce_selected_kf")) - 1
        if k_idx >= 0 and k_idx < car_data["keyframes"].size():
            for v in car_data["keyframes"][k_idx]["verts"]:
                v["x"] = max(0.0, v["x"] * scale_x)
                v["y"] *= scale_y
            _commit_history(2)
            _push_state_to_lua()
            _build_car()

    if Engine.get_process_frames() == 10:
        lua_manager.set_global_float("ce_selected_mode", 2.0)
    if not lua_manager: return
    
    if not car_data.has("spine"): return
    var rebuild = false
    
    # 1. Update counts in Lua
    var v_per_curve = float(car_data.get("vertices_per_curve", 56))
    lua_manager.set_global_float("ce_spine_count", float(car_data["spine"].size()))
    lua_manager.set_global_float("ce_kf_count", float(car_data["keyframes"].size()))
    lua_manager.set_global_float("ce_prim_count", float(car_data["primitives"].size()))
    
    if lua_manager.get_global_float("ce_cmd_undo") > 0.5:
        lua_manager.set_global_float("ce_cmd_undo", 0.0)
        _undo(int(lua_manager.get_global_float("ce_selected_mode")))
        rebuild = true
    if lua_manager.get_global_float("ce_cmd_redo") > 0.5:
        lua_manager.set_global_float("ce_cmd_redo", 0.0)
        _redo(int(lua_manager.get_global_float("ce_selected_mode")))
        rebuild = true
        
    # 2. Check Commands from Lua
    if lua_manager.get_global_float("ce_cmd_add_spine") > 0.5:
        lua_manager.set_global_float("ce_cmd_add_spine", 0.0)
        _commit_history(1)
        car_data["spine"].append({"px":0, "py":0, "pz":0, "in_x":0, "in_y":0, "in_z":1, "out_x":0, "out_y":0, "out_z":-1})
        lua_manager.set_global_float("ce_selected_spine", float(car_data["spine"].size()))
        rebuild = true
        
    if lua_manager.get_global_float("ce_cmd_del_spine") > 0.5:
        lua_manager.set_global_float("ce_cmd_del_spine", 0.0)
        if car_data["spine"].size() > 2:
            var idx = int(lua_manager.get_global_float("ce_selected_spine")) - 1
            if idx >= 0 and idx < car_data["spine"].size():
                _commit_history(1)
                car_data["spine"].remove_at(idx)
                rebuild = true
                
    if lua_manager.get_global_float("ce_cmd_add_kf") > 0.5:
        lua_manager.set_global_float("ce_cmd_add_kf", 0.0)
        _commit_history(2)
        car_data["keyframes"].append({"t": 0.5, "verts": _generate_half_circle(car_data["vertices_per_curve"])})
        lua_manager.set_global_float("ce_selected_kf", float(car_data["keyframes"].size()))
        rebuild = true
        
    if lua_manager.get_global_float("ce_cmd_del_kf") > 0.5:
        lua_manager.set_global_float("ce_cmd_del_kf", 0.0)
        if car_data["keyframes"].size() > 1:
            var idx = int(lua_manager.get_global_float("ce_selected_kf")) - 1
            if idx >= 0 and idx < car_data["keyframes"].size():
                _commit_history(2)
                car_data["keyframes"].remove_at(idx)
                rebuild = true
                
    if lua_manager.get_global_float("ce_cmd_add_box") > 0.5:
        lua_manager.set_global_float("ce_cmd_add_box", 0.0)
        _commit_history(3)
        car_data["primitives"].append({"type": "box", "op": 0, "px": 0, "py": 0, "pz": 0, "rx": 0, "ry": 0, "rz": 0, "sx": 1, "sy": 1, "sz": 1})
        lua_manager.set_global_float("ce_selected_prim", float(car_data["primitives"].size()))
        rebuild = true
        
    if lua_manager.get_global_float("ce_cmd_add_cyl") > 0.5:
        lua_manager.set_global_float("ce_cmd_add_cyl", 0.0)
        _commit_history(3)
        car_data["primitives"].append({"type": "cylinder", "op": 0, "px": 0, "py": 0, "pz": 0, "rx": 0, "ry": 0, "rz": 0, "r": 0.5, "h": 1, "sides": 32})
        lua_manager.set_global_float("ce_selected_prim", float(car_data["primitives"].size()))
        rebuild = true
        
    if lua_manager.get_global_float("ce_cmd_add_sph") > 0.5:
        lua_manager.set_global_float("ce_cmd_add_sph", 0.0)
        _commit_history(3)
        car_data["primitives"].append({"type": "sphere", "op": 0, "px": 0, "py": 0, "pz": 0, "rx": 0, "ry": 0, "rz": 0, "r": 0.5})
        lua_manager.set_global_float("ce_selected_prim", float(car_data["primitives"].size()))
        rebuild = true
        
    if lua_manager.get_global_float("ce_cmd_del_prim") > 0.5:
        lua_manager.set_global_float("ce_cmd_del_prim", 0.0)
        if car_data["primitives"].size() > 0:
            var idx = int(lua_manager.get_global_float("ce_selected_prim")) - 1
            if idx >= 0 and idx < car_data["primitives"].size():
                _commit_history(3)
                car_data["primitives"].remove_at(idx)
                rebuild = true

    # 3. Pull Slider edits from Lua
    if not car_data.has("spine"): return
    var mode = int(lua_manager.get_global_float("ce_selected_mode"))
    
    var selection_changed = false
    if mode != prev_selected_mode:
        prev_selected_mode = mode
        selection_changed = true
        
    var idx = -1
    var v_idx = -1
    if mode == 1:
        idx = int(lua_manager.get_global_float("ce_selected_spine")) - 1
        if idx != prev_selected_spine:
            prev_selected_spine = idx
            selection_changed = true
    elif mode == 2:
        idx = int(lua_manager.get_global_float("ce_selected_kf")) - 1
        if idx != prev_selected_kf:
            prev_selected_kf = idx
            selection_changed = true
            
        v_idx = int(lua_manager.get_global_float("ce_selected_vert")) - 1
        if v_idx != prev_selected_vert:
            prev_selected_vert = v_idx
            selection_changed = true
    elif mode == 3:
        idx = int(lua_manager.get_global_float("ce_selected_prim")) - 1
        if idx != prev_selected_prim:
            prev_selected_prim = idx
            selection_changed = true

    if selection_changed:
        _push_state_to_lua()
    else:
        if mode == 1:
            if idx >= 0 and idx < car_data["spine"].size():
                var pt = car_data["spine"][idx]
                var keys = ["px", "py", "pz", "in_x", "in_y", "in_z", "out_x", "out_y", "out_z"]
                var fnames = ["ce_spine_px", "ce_spine_py", "ce_spine_pz", "ce_spine_inx", "ce_spine_iny", "ce_spine_inz", "ce_spine_outx", "ce_spine_outy", "ce_spine_outz"]
                for i in range(keys.size()):
                    var fval = lua_manager.get_global_float(fnames[i])
                    if abs(fval - pt[keys[i]]) > 0.001:
                        pt[keys[i]] = fval
                        rebuild = true
        elif mode == 2:
            if idx >= 0 and idx < car_data["keyframes"].size():
                var kf = car_data["keyframes"][idx]
                var tval = lua_manager.get_global_float("ce_kf_t")
                if abs(tval - kf["t"]) > 0.001:
                    kf["t"] = tval
                    rebuild = true
                    
                if v_idx >= 0 and v_idx < kf["verts"].size():
                    var vx = lua_manager.get_global_float("ce_sel_v_x")
                    var vy = lua_manager.get_global_float("ce_sel_v_y")
                    if abs(vx - kf["verts"][v_idx]["x"]) > 0.001:
                        kf["verts"][v_idx]["x"] = vx
                        rebuild = true
                    if abs(vy - kf["verts"][v_idx]["y"]) > 0.001:
                        kf["verts"][v_idx]["y"] = vy
                        rebuild = true
        elif mode == 3:
            if idx >= 0 and idx < car_data["primitives"].size():
                var p = car_data["primitives"][idx]
                var keys = ["px", "py", "pz", "rx", "ry", "rz"]
                var fnames = ["ce_prim_px", "ce_prim_py", "ce_prim_pz", "ce_prim_rx", "ce_prim_ry", "ce_prim_rz"]
                for i in range(keys.size()):
                    var fval = lua_manager.get_global_float(fnames[i])
                    if abs(fval - p.get(keys[i], 0)) > 0.001:
                        p[keys[i]] = fval
                        rebuild = true
                
                var op_val = lua_manager.get_global_int("ce_prim_op")
                if op_val != p.get("op", 0):
                    p["op"] = op_val
                    rebuild = true
                    
                if p["type"] == "box":
                    var keys_box = ["sx", "sy", "sz"]
                    var fnames_box = ["ce_prim_sx", "ce_prim_sy", "ce_prim_sz"]
                    for i in range(keys_box.size()):
                        var fval = lua_manager.get_global_float(fnames_box[i])
                        if abs(fval - p.get(keys_box[i], 1)) > 0.001:
                            p[keys_box[i]] = fval
                            rebuild = true
                elif p["type"] == "cylinder":
                    var fval_r = lua_manager.get_global_float("ce_prim_r")
                    if abs(fval_r - p.get("r", 0.5)) > 0.001:
                        p["r"] = fval_r; rebuild = true
                    var fval_h = lua_manager.get_global_float("ce_prim_h")
                    if abs(fval_h - p.get("h", 1.0)) > 0.001:
                        p["h"] = fval_h; rebuild = true
                elif p["type"] == "sphere":
                    var fval_r = lua_manager.get_global_float("ce_prim_r")
                    if abs(fval_r - p.get("r", 0.5)) > 0.001:
                        p["r"] = fval_r; rebuild = true
    
    if rebuild:
        history_timer = 0.5
        _save_data()
        _push_state_to_lua() # Optional, just makes sure things are locked in sync
        _build_car()
    else:
        if history_timer > 0.0:
            history_timer -= delta
            if history_timer <= 0.0:
                history_timer = 0.0
                _commit_history(int(lua_manager.get_global_float("ce_selected_mode")))


# ---------------------------------------------------------
# GODOT -> LUA SYNC
# ---------------------------------------------------------
func _push_state_to_lua():
    if not lua_manager: return
    if not car_data.has("spine"): return
    
    if not car_data.has("spine"): return
    var mode = int(lua_manager.get_global_float("ce_selected_mode"))
    if mode == 1:
        var idx = int(lua_manager.get_global_float("ce_selected_spine")) - 1
        if idx >= 0 and idx < car_data["spine"].size():
            var pt = car_data["spine"][idx]
            lua_manager.set_global_float("ce_spine_px", pt["px"])
            lua_manager.set_global_float("ce_spine_py", pt["py"])
            lua_manager.set_global_float("ce_spine_pz", pt["pz"])
            lua_manager.set_global_float("ce_spine_inx", pt["in_x"])
            lua_manager.set_global_float("ce_spine_iny", pt["in_y"])
            lua_manager.set_global_float("ce_spine_inz", pt["in_z"])
            lua_manager.set_global_float("ce_spine_outx", pt["out_x"])
            lua_manager.set_global_float("ce_spine_outy", pt["out_y"])
            lua_manager.set_global_float("ce_spine_outz", pt["out_z"])
    elif mode == 2:
        var idx = int(lua_manager.get_global_float("ce_selected_kf")) - 1
        if idx >= 0 and idx < car_data["keyframes"].size():
            var kf = car_data["keyframes"][idx]
            lua_manager.set_global_float("ce_kf_t", kf["t"])
            
            var v_idx = int(lua_manager.get_global_float("ce_selected_vert")) - 1
            if v_idx >= 0 and v_idx < kf["verts"].size():
                lua_manager.set_global_float("ce_sel_v_x", kf["verts"][v_idx]["x"])
                lua_manager.set_global_float("ce_sel_v_y", kf["verts"][v_idx]["y"])
    elif mode == 3:
        var idx = int(lua_manager.get_global_float("ce_selected_prim")) - 1
        if idx >= 0 and idx < car_data["primitives"].size():
            var p = car_data["primitives"][idx]
            lua_manager.set_global_float("ce_prim_px", p.get("px", 0))
            lua_manager.set_global_float("ce_prim_py", p.get("py", 0))
            lua_manager.set_global_float("ce_prim_pz", p.get("pz", 0))
            lua_manager.set_global_float("ce_prim_rx", p.get("rx", 0))
            lua_manager.set_global_float("ce_prim_ry", p.get("ry", 0))
            lua_manager.set_global_float("ce_prim_rz", p.get("rz", 0))
            lua_manager.set_global_int("ce_prim_op", p.get("op", 0))
            
            if p["type"] == "box":
                lua_manager.set_global_float("ce_prim_sx", p.get("sx", 1))
                lua_manager.set_global_float("ce_prim_sy", p.get("sy", 1))
                lua_manager.set_global_float("ce_prim_sz", p.get("sz", 1))
            elif p["type"] == "cylinder":
                lua_manager.set_global_float("ce_prim_r", p.get("r", 0.5))
                lua_manager.set_global_float("ce_prim_h", p.get("h", 1.0))
            elif p["type"] == "sphere":
                lua_manager.set_global_float("ce_prim_r", p.get("r", 0.5))

func _get_curve_transform(curve: Curve3D, offset: float) -> Transform3D:
    var pos = curve.sample_baked(offset)
    var pos_next = curve.sample_baked(min(offset + 0.01, curve.get_baked_length()))
    var pos_prev = curve.sample_baked(max(offset - 0.01, 0.0))
    var tangent = (pos_next - pos_prev).normalized()
    if tangent.length() < 0.001:
        return Transform3D(Basis(), pos)
        
    var right = Vector3(1, 0, 0)
    var up = right.cross(tangent).normalized()
    if up.length() < 0.001:
        up = Vector3(0, 1, 0)
        
    var actual_right = tangent.cross(up).normalized()
    
    # We want the car's local Z to be the tangent, Y to be up, X to be right
    return Transform3D(Basis(actual_right, up, tangent), pos)

func _build_sweep():
    var curve = Curve3D.new()
    curve.up_vector_enabled = false
    var spine = car_data.get("spine", [])
    for pt in spine:
        curve.add_point(
            Vector3(pt.get("px", 0.0), pt.get("py", 0.0), pt.get("pz", 0.0)),
            Vector3(pt.get("in_x", 0.0), pt.get("in_y", 0.0), pt.get("in_z", 0.0)),
            Vector3(pt.get("out_x", 0.0), pt.get("out_y", 0.0), pt.get("out_z", 0.0))
        )
        
    var keyframes = car_data.get("keyframes", [])
    if keyframes.size() < 1 or spine.size() < 2: return
    
    keyframes.sort_custom(func(a, b): return a["t"] < b["t"])
    
    var st = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.set_smooth_group(1)
    
    var segments = 64
    var path_length = curve.get_baked_length()
    if path_length < 0.001: return
    
    var prev_loop = []
    
    for i in range(segments + 1):
        var s = float(i) / segments
        var offset = s * path_length
        var trans = _get_curve_transform(curve, offset)
        
        var kf0 = keyframes[0]
        var kf1 = keyframes[keyframes.size() - 1]
        
        if s <= kf0["t"]: kf1 = kf0
        elif s >= kf1["t"]: kf0 = kf1
        else:
            for j in range(keyframes.size() - 1):
                if s >= keyframes[j]["t"] and s <= keyframes[j+1]["t"]:
                    kf0 = keyframes[j]
                    kf1 = keyframes[j+1]
                    break
                    
        var local_t = 0.0
        if kf1["t"] > kf0["t"]:
            local_t = (s - kf0["t"]) / (kf1["t"] - kf0["t"])
            
        var right_verts = []
        var vcount = min(kf0["verts"].size(), kf1["verts"].size())
        for v in range(vcount):
            var v0 = Vector2(kf0["verts"][v]["x"], kf0["verts"][v]["y"])
            var v1 = Vector2(kf1["verts"][v]["x"], kf1["verts"][v]["y"])
            right_verts.append(v0.lerp(v1, local_t))
            
        var loop_2d = PackedVector2Array()
        for p in right_verts: loop_2d.append(p)
        for j in range(right_verts.size() - 1, -1, -1):
            var p = right_verts[j]
            if abs(p.x) > 0.001:
                loop_2d.append(Vector2(-p.x, p.y))
                
        var current_loop = []
        for p2d in loop_2d:
            current_loop.append(trans * Vector3(p2d.x, p2d.y, 0))
            
        if i == 0 and current_loop.size() >= 3:
            var indices = Geometry2D.triangulate_polygon(loop_2d)
            if indices.size() > 0:
                for j in range(0, indices.size(), 3):
                    st.add_vertex(current_loop[indices[j+2]])
                    st.add_vertex(current_loop[indices[j+1]])
                    st.add_vertex(current_loop[indices[j]])
                    
        if i == segments and current_loop.size() >= 3:
            var indices = Geometry2D.triangulate_polygon(loop_2d)
            if indices.size() > 0:
                for j in range(0, indices.size(), 3):
                    st.add_vertex(current_loop[indices[j]])
                    st.add_vertex(current_loop[indices[j+1]])
                    st.add_vertex(current_loop[indices[j+2]])
                    
        if prev_loop.size() == current_loop.size():
            var n = current_loop.size()
            for j in range(n):
                var next_j = (j + 1) % n
                st.add_vertex(prev_loop[j])
                st.add_vertex(current_loop[next_j])
                st.add_vertex(prev_loop[next_j])
                st.add_vertex(prev_loop[j])
                st.add_vertex(current_loop[j])
                st.add_vertex(current_loop[next_j])
                
        prev_loop = current_loop
        
    st.generate_normals()
    var mesh = st.commit()
    
    if swept_body == null or not is_instance_valid(swept_body):
        swept_body = CSGMesh3D.new()
        swept_body.name = "SweptBody"
        swept_body.material = mat_body
        combiner.add_child(swept_body)
    
    swept_body.mesh = mesh

func _build_primitive(prim):
    var csg = null
    var type = prim.get("type", "box")
    if type == "box":
        csg = CSGBox3D.new()
        csg.size = Vector3(prim.get("sx", 1.0), prim.get("sy", 1.0), prim.get("sz", 1.0))
    elif type == "cylinder":
        csg = CSGCylinder3D.new()
        csg.radius = prim.get("r", 0.5)
        csg.height = prim.get("h", 1.0)
        csg.sides = prim.get("sides", 32)
    elif type == "sphere":
        csg = CSGSphere3D.new()
        csg.radius = prim.get("r", 0.5)
        
    if not csg: return
    csg.name = prim.get("name", type)
    csg.position = Vector3(prim.get("px", 0.0), prim.get("py", 0.0), prim.get("pz", 0.0))
    csg.rotation_degrees = Vector3(prim.get("rx", 0.0), prim.get("ry", 0.0), prim.get("rz", 0.0))
    var op = prim.get("op", 0)
    if op == 1: csg.operation = CSGShape3D.OPERATION_SUBTRACTION
    elif op == 2: csg.operation = CSGShape3D.OPERATION_INTERSECTION
    else: csg.operation = CSGShape3D.OPERATION_UNION
    combiner.add_child(csg)

func _draw_line_3d(parent, p0: Vector3, p1: Vector3, mat: Material, radius: float):
    var d = p1.distance_to(p0)
    if d < 0.001: return
    var cyl = CSGCylinder3D.new()
    cyl.radius = radius
    cyl.height = d
    cyl.material = mat
    cyl.position = (p0 + p1) / 2.0
    var up = Vector3.UP
    var dir = (p1 - p0).normalized()
    var axis = up.cross(dir)
    if axis.length() > 0.001:
        cyl.transform.basis = Basis(axis.normalized(), acos(up.dot(dir)))
    elif up.dot(dir) < 0:
        cyl.transform.basis = Basis(Vector3.RIGHT, PI)
    parent.add_child(cyl)

func _create_draggable(parent, pos: Vector3, radius: float, meta_dict: Dictionary):
    var area = Area3D.new()
    area.position = pos
    var col = CollisionShape3D.new()
    var shape = SphereShape3D.new()
    shape.radius = radius * 1.5 # generous hitbox
    col.shape = shape
    area.add_child(col)
    for k in meta_dict:
        area.set_meta(k, meta_dict[k])
    parent.add_child(area)
    return area

func _build_debug_visuals():
    debug_parent = Node3D.new()
    debug_parent.name = "DebugVisuals"
    add_child(debug_parent)
    
    var curve = Curve3D.new()
    curve.up_vector_enabled = false
    var spine = car_data.get("spine", [])
    for i in range(spine.size()):
        var pt = spine[i]
        var pos = Vector3(pt.get("px", 0.0), pt.get("py", 0.0), pt.get("pz", 0.0))
        var tin = Vector3(pt.get("in_x", 0.0), pt.get("in_y", 0.0), pt.get("in_z", 0.0))
        var tout = Vector3(pt.get("out_x", 0.0), pt.get("out_y", 0.0), pt.get("out_z", 0.0))
        curve.add_point(pos, tin, tout)
        
        var sel_mode = int(lua_manager.get_global_float("ce_selected_mode"))
        var sel_sp_idx = int(lua_manager.get_global_float("ce_selected_spine")) - 1
        var is_sel = (sel_mode == 1 and i == sel_sp_idx)
        var s = CSGSphere3D.new()
        s.radius = 0.06
        s.material = mat_red if is_sel else mat_cyan # Let's use red for selected, cyan for others
        s.position = pos
        debug_parent.add_child(s)
        _create_draggable(debug_parent, pos, 0.06, {"type": "spine", "index": i})
        
        if tin.length() > 0.01:
            var p_in = pos + tin / 2.0
            _draw_line_3d(debug_parent, pos, p_in, mat_cyan, 0.01)
            var c_in = CSGCylinder3D.new()
            c_in.radius = 0.03
            c_in.height = 0.03
            c_in.material = mat_cyan
            c_in.position = p_in
            debug_parent.add_child(c_in)
            _create_draggable(debug_parent, p_in, 0.04, {"type": "handle_in", "index": i})
            
        if tout.length() > 0.01:
            var p_out = pos + tout / 2.0
            _draw_line_3d(debug_parent, pos, p_out, mat_cyan, 0.01)
            var c_out = CSGCylinder3D.new()
            c_out.radius = 0.03
            c_out.height = 0.03
            c_out.material = mat_cyan
            c_out.position = p_out
            debug_parent.add_child(c_out)
            _create_draggable(debug_parent, p_out, 0.04, {"type": "handle_out", "index": i})
            
    if spine.size() >= 2:
        var baked_pts = curve.get_baked_points()
        for i in range(baked_pts.size() - 1):
            _draw_line_3d(debug_parent, baked_pts[i], baked_pts[i+1], mat_red, 0.015)
            
        var path_length = curve.get_baked_length()
        if path_length < 0.001: return
        var keyframes = car_data.get("keyframes", [])
        for k_idx in range(keyframes.size()):
            var kf = keyframes[k_idx]
            var offset = kf["t"] * path_length
            var trans = _get_curve_transform(curve, offset)
            
            var loop_2d = PackedVector2Array()
            for v in kf["verts"]: loop_2d.append(Vector2(v["x"], v["y"]))
            for j in range(kf["verts"].size() - 1, -1, -1):
                var v = kf["verts"][j]
                if abs(v["x"]) > 0.001: loop_2d.append(Vector2(-v["x"], v["y"]))
                    
            var loop_3d = []
            for p2d in loop_2d:
                loop_3d.append(trans * Vector3(p2d.x, p2d.y, 0))
                
            for v_idx in range(kf["verts"].size()):
                var p2d = Vector2(kf["verts"][v_idx]["x"], kf["verts"][v_idx]["y"])
                var pos3d = trans * Vector3(p2d.x, p2d.y, 0)
                var sel_mode = int(lua_manager.get_global_float("ce_selected_mode"))
                var sel_kf_idx = int(lua_manager.get_global_float("ce_selected_kf")) - 1
                var sel_v_idx = int(lua_manager.get_global_float("ce_selected_vert")) - 1
                var is_sel = (sel_mode == 2 and k_idx == sel_kf_idx and v_idx == sel_v_idx)
                
                var gs = CSGSphere3D.new()
                gs.radius = 0.04
                var dyn_mat = StandardMaterial3D.new()
                dyn_mat.albedo_color = Color(1, 0, 0) if is_sel else Color(1, 1, 0)
                dyn_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                gs.material = dyn_mat
                gs.position = pos3d
                debug_parent.add_child(gs)
                _create_draggable(debug_parent, pos3d, 0.04, {"type": "kf", "kf_index": k_idx, "vert_index": v_idx, "trans": trans})
                    
            for i in range(loop_3d.size()):
                var next_i = (i + 1) % loop_3d.size()
                _draw_line_3d(debug_parent, loop_3d[i], loop_3d[next_i], mat_green, 0.015)


func _commit_history(mode: int):
    if mode == 1:
        history_spine_undo.append(car_data["spine"].duplicate(true))
        history_spine_redo.clear()
    elif mode == 2:
        history_kf_undo.append(car_data["keyframes"].duplicate(true))
        history_kf_redo.clear()
    elif mode == 3:
        history_prim_undo.append(car_data["primitives"].duplicate(true))
        history_prim_redo.clear()

func _undo(mode: int):
    if mode == 1 and history_spine_undo.size() > 0:
        history_spine_redo.append(car_data["spine"].duplicate(true))
        car_data["spine"] = history_spine_undo.pop_back()
    elif mode == 2 and history_kf_undo.size() > 0:
        history_kf_redo.append(car_data["keyframes"].duplicate(true))
        car_data["keyframes"] = history_kf_undo.pop_back()
    elif mode == 3 and history_prim_undo.size() > 0:
        history_prim_redo.append(car_data["primitives"].duplicate(true))
        car_data["primitives"] = history_prim_undo.pop_back()

func _redo(mode: int):
    if mode == 1 and history_spine_redo.size() > 0:
        history_spine_undo.append(car_data["spine"].duplicate(true))
        car_data["spine"] = history_spine_redo.pop_back()
    elif mode == 2 and history_kf_redo.size() > 0:
        history_kf_undo.append(car_data["keyframes"].duplicate(true))
        car_data["keyframes"] = history_kf_redo.pop_back()
    elif mode == 3 and history_prim_redo.size() > 0:
        history_prim_undo.append(car_data["primitives"].duplicate(true))
        car_data["primitives"] = history_prim_redo.pop_back()

func _update_visual_colors():
    if not debug_parent: return
    var sel_mode = int(lua_manager.get_global_float("ce_selected_mode"))
    var sel_sp_idx = int(lua_manager.get_global_float("ce_selected_spine")) - 1
    var sel_kf_idx = int(lua_manager.get_global_float("ce_selected_kf")) - 1
    var sel_v_idx = int(lua_manager.get_global_float("ce_selected_vert")) - 1
    
    for area in debug_parent.get_children():
        if area is Area3D and area.has_meta("type"):
            var t = area.get_meta("type")
            var is_sel = false
            if t == "spine" and sel_mode == 1 and area.get_meta("index") == sel_sp_idx:
                is_sel = true
            elif t == "kf" and sel_mode == 2 and area.get_meta("kf_index") == sel_kf_idx and area.get_meta("vert_index") == sel_v_idx:
                is_sel = true
                
            # Find the visual sphere sibling at the same position
            for sibling in debug_parent.get_children():
                if sibling is CSGSphere3D and sibling.position.distance_to(area.position) < 0.01:
                    if t == "spine":
                        sibling.material.albedo_color = Color(1, 0, 0) if is_sel else Color(0, 1, 1)
                    elif t == "kf":
                        sibling.material.albedo_color = Color(1, 0, 0) if is_sel else Color(1, 1, 0)
