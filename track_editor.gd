extends Node3D

var track_data: Array = []
var history_stack: Array = []
var last_params = {}
var track_after_hole: Array = []
var hole_anchor_transform: Transform3D = Transform3D.IDENTITY
var is_hole_mode: bool = false
var build_direction: int = 1
var hovered_piece_index: int = -1

var built_nodes: Array = []
var is_showing_final = false
var final_parent: Node3D

@onready var track_root = $TrackRoot
var lua_manager = null

func _ready():
    Engine.max_fps = 60
    final_parent = Node3D.new()
    add_child(final_parent)
    final_parent.visible = false
    lua_manager = get_tree().root.get_node_or_null("LuaManager")
    if not lua_manager:
        lua_manager = get_node_or_null("/root/LuaManager")
    

    rebuild_track()

func _process(_delta):
    if not lua_manager:
        return
        
    var clear_btn = lua_manager.get_global_float("editor_clear")
    if clear_btn > 0.5:
        lua_manager.set_global_float("editor_clear", 0.0)
        track_data.clear()
        rebuild_track()
        return

    var show_final = lua_manager.get_global_float("editor_show_final") > 0.5
    if show_final != is_showing_final:
        is_showing_final = show_final
        if is_showing_final:
            track_root.visible = false
            final_parent.visible = true
            preload("res://track_generator.gd").generate(track_data, final_parent)
        else:
            track_root.visible = true
            final_parent.visible = false
            
    if is_showing_final:
        return
        
    var action = lua_manager.get_global_float("editor_action")
    var p_length = lua_manager.get_global_float("editor_param_length")
    var p_angle = lua_manager.get_global_float("editor_param_angle")
    var p2 = lua_manager.get_global_float("editor_param_2")
    var p3 = lua_manager.get_global_float("editor_param_3")
    var p_incline = lua_manager.get_global_float("editor_param_incline")
    var p_drop = lua_manager.get_global_float("editor_param_drop")
    var p5 = lua_manager.get_global_float("editor_param_5")
    var p6 = lua_manager.get_global_float("editor_param_6")
    var p_gap_length = lua_manager.get_global_float("editor_param_gap_length")
    var p_ramp_size = lua_manager.get_global_float("editor_param_ramp_size")
    
    var current_params = {
        "length": p_length,
        "angle": p_angle,
        "width_start": p2,
        "width_end": p5,
        "radius": p3,
        "incline": p_incline,
        "drop": p_drop,
        "ramp_angle": p6,
        "gap_length": p_gap_length,
        "ramp_size": p_ramp_size
    }
    
    var param_changed = false
    if last_params.size() > 0:
        for k in current_params.keys():
            if abs(current_params[k] - last_params[k]) > 0.001:
                param_changed = true
                break
                
    last_params = current_params.duplicate()
    
    if param_changed and track_data.size() > 0 and action == 0.0:
        var last_idx = track_data.size() - 1
        var p = track_data[last_idx]
        var t = p.get("type", "")
        if t == "straight":
            p["length"] = p_length
            p["width"] = p2
            p["incline"] = p_incline
        elif t == "curve":
            p["angle"] = p_angle
            p["radius"] = p3
            p["width"] = p2
        elif t == "drop":
            p["drop_distance"] = p_drop
        elif t == "transition":
            p["length"] = p_length
            p["start_width"] = p2
            p["end_width"] = p5
        elif t == "gate":
            p["length"] = p_length
            p["track_width"] = p2
            p["gate_width"] = p5
        elif t == "gap":
            p["gap_length"] = p_gap_length
            p["ramp_size"] = p_ramp_size
            p["width"] = p2
            p["ramp_angle"] = p6
        elif t == "close_loop":
            p["width"] = p2
            
        rebuild_track()

    if action > 0.0:

        
        var piece_to_add = {}
        if action == 1.0:
            piece_to_add = {"type": "straight", "length": p_length, "width": p2, "incline": p_incline}
        elif action == 2.0:
            piece_to_add = {"type": "curve", "angle": p_angle, "radius": p3, "width": p2}
        elif action == 3.0:
            piece_to_add = {"type": "drop", "drop_distance": p_drop}
        elif action == 4.0:
            piece_to_add = {"type": "transition", "length": p_length, "start_width": p2, "end_width": p5}
        elif action == 5.0:
            piece_to_add = {"type": "gate", "length": p_length, "track_width": p2, "gate_width": p5}
        elif action == 6.0:
            piece_to_add = {"type": "gap", "gap_length": p_gap_length, "ramp_size": p_ramp_size, "width": p2, "ramp_angle": p6}
        elif action == 7.0:
            piece_to_add = {"type": "close_loop", "width": p2}
        elif action == 9.0:
            piece_to_add = {"type": "bank_transition", "length": p_length, "width": p2}
        elif action == 13.0:
            piece_to_add = {"type": "right_angle", "radius": p3, "width": p2, "is_left": true}
        elif action == 14.0:
            piece_to_add = {"type": "right_angle", "radius": p3, "width": p2, "is_left": false}
            
        if piece_to_add.size() > 0:
            _add_new_piece(piece_to_add)
            
        if action == 8.0:
            pass # clear track is handled elsewhere? Actually clear is handled directly in lua? No, 8 is clear track!
        elif action == 10.0:
            lua_manager.set_global_float("editor_action", 0.0)
            _show_file_dialog(false)
            return
        elif action == 11.0:
            lua_manager.set_global_float("editor_action", 0.0)
            _show_file_dialog(true)
            return
        elif action == 12.0:
            if is_hole_mode:
                if history_stack.size() > 0 and typeof(history_stack.back()) == TYPE_DICTIONARY:
                    var state = history_stack.pop_back()
                    track_data = state["d"].duplicate(true)
                    track_after_hole = state["a"].duplicate(true)
                    hole_anchor_transform = state["anc"]
                    is_hole_mode = state["hole"]
                    build_direction = state["dir"]
                else:
                    if build_direction == 1 and track_data.size() > 0:
                        track_data.pop_back()
                    elif build_direction == -1 and track_after_hole.size() > 0:
                        track_after_hole.pop_front()
            else:
                if history_stack.size() > 0:
                    var state = history_stack.pop_back()
                    if typeof(state) == TYPE_DICTIONARY and state.has("d"):
                        track_data = state["d"].duplicate(true)
                        track_after_hole = state["a"].duplicate(true)
                        hole_anchor_transform = state["anc"]
                        is_hole_mode = state["hole"]
                        build_direction = state["dir"]
                    elif typeof(state) == TYPE_ARRAY:
                        track_data = state.duplicate(true)
                        track_after_hole = []
                        is_hole_mode = false
                        build_direction = 1
        elif action == 15.0:
            if is_hole_mode:
                build_direction = -build_direction
                hovered_piece_index = -1
        elif action == 16.0:
            if is_hole_mode:
                var p = {"type": "spline_transition", "width": p2}
                p["target_pos_x"] = hole_anchor_transform.origin.x
                p["target_pos_y"] = hole_anchor_transform.origin.y
                p["target_pos_z"] = hole_anchor_transform.origin.z
                var rot = hole_anchor_transform.basis.get_euler()
                p["target_rot_x"] = rot.x
                p["target_rot_y"] = rot.y
                p["target_rot_z"] = rot.z
                history_stack.append({"d": track_data.duplicate(true), "a": track_after_hole.duplicate(true), "anc": hole_anchor_transform, "hole": is_hole_mode, "dir": build_direction})
                track_data.append(p)
                track_data.append_array(track_after_hole)
                track_after_hole = []
                is_hole_mode = false
                build_direction = 1
                hovered_piece_index = -1
                
        lua_manager.set_global_float("editor_action", 0.0)
        rebuild_track()


    var select_undo_mode = lua_manager.get_global_float("editor_select_undo_mode") > 0.5
    if select_undo_mode:
        _handle_raycast()
    else:
        if hovered_piece_index != -1:
            hovered_piece_index = -1
            rebuild_track()

func _show_file_dialog(is_load: bool):
    var fd = FileDialog.new()
    fd.access = FileDialog.ACCESS_FILESYSTEM
    fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE if is_load else FileDialog.FILE_MODE_SAVE_FILE
    fd.use_native_dialog = true
    fd.add_filter("*.json", "Track JSON")
    fd.current_dir = ProjectSettings.globalize_path("user://")
    
    if is_load:
        fd.file_selected.connect(_on_load_file)
    else:
        fd.file_selected.connect(_on_save_file)
        
    add_child(fd)
    fd.popup_centered(Vector2(600, 400))

func _on_save_file(path: String):
    var file = FileAccess.open(path, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(track_data, "    "))
        file.close()

func _on_load_file(path: String):
    var file = FileAccess.open(path, FileAccess.READ)
    if file:
        var text = file.get_as_text()
        var data = JSON.parse_string(text)
        if typeof(data) == TYPE_ARRAY:
            track_data = data
            
            # Setup history stack so user can step-by-step undo the loaded track
            history_stack.clear()
            var temp_data = []
            for piece in data:
                history_stack.append(temp_data.duplicate(true))
                temp_data.append(piece)
                
            rebuild_track()
        file.close()

func clear_track():
    for child in built_nodes:
        child.queue_free()
    built_nodes.clear()

func rebuild_track():
    if is_showing_final:
        preload("res://track_generator.gd").generate(track_data, final_parent)

    clear_track()
    var current_transform = Transform3D.IDENTITY
    

    var render_data = track_data.duplicate(true)
    if is_hole_mode:
        render_data.append({"type": "teleport", "transform": hole_anchor_transform})
        render_data.append_array(track_after_hole)

    var curve_start_t = []
    var curve_end_t = []
    var curve_banked = []
    curve_start_t.resize(render_data.size())
    curve_end_t.resize(render_data.size())
    curve_banked.resize(render_data.size())
    
    var i_idx = 0
    while i_idx < render_data.size():
        var piece = render_data[i_idx]
        var type = piece.get("type", "straight")
        if type == "curve":
            var sign_dir = sign(float(piece.get("angle", 90.0)))
            var block_end = i_idx
            var total_angle = abs(float(piece.get("angle", 90.0)))
            
            for j in range(i_idx + 1, render_data.size()):
                if render_data[j].get("type", "straight") == "curve" and sign(float(render_data[j].get("angle", 90.0))) == sign_dir:
                    block_end = j
                    total_angle += abs(float(render_data[j].get("angle", 90.0)))
                else:
                    break
                    
            var is_banked = false
            if i_idx > 0 and render_data[i_idx - 1].get("type", "") == "bank_transition":
                is_banked = true
                
            var current_accum = 0.0
            for j in range(i_idx, block_end + 1):
                curve_banked[j] = is_banked
                var p_ang = abs(float(render_data[j].get("angle", 90.0)))
                curve_start_t[j] = current_accum / total_angle
                current_accum += p_ang
                curve_end_t[j] = current_accum / total_angle
                
            i_idx = block_end + 1
        else:
            curve_start_t[i_idx] = 0.0
            curve_end_t[i_idx] = 1.0
            curve_banked[i_idx] = false
            i_idx += 1

    var piece_index = 0
    for i in range(render_data.size()):
        var piece = render_data[i]
        var type = piece.get("type", "straight")
        
        if type == "teleport":
            current_transform = piece["transform"]
            continue
            
        var piece_node = Node3D.new()
        piece_node.name = "Piece_" + str(piece_index)
        piece_index += 1
        track_root.add_child(piece_node)
        built_nodes.append(piece_node)
        
        piece_node.global_transform = current_transform
        var end_transform = current_transform
        
        if type == "straight":
            var length = float(piece.get("length", 100.0))
            var width = float(piece.get("width", 104.0))
            
            var incline = float(piece.get("incline", 0.0))
            var render_len = length
            
            if abs(incline) >= 0.1:
                var theta = deg_to_rad(incline)
                var R = length / abs(theta)
                var sign_pitch = 1.0 if incline > 0 else -1.0
                var y = (R - R * cos(abs(theta))) * sign_pitch
                var z = -R * sin(abs(theta))
                render_len = max(0.1, sqrt(y*y + z*z))
            
            var road = _create_straight_csg(render_len, width, 0.0)
            piece_node.add_child(road)
            var border_l = _create_straight_border(render_len, -width/2.0)
            piece_node.add_child(border_l)
            var border_r = _create_straight_border(render_len, width/2.0)
            piece_node.add_child(border_r)
            
            var ai_vision = _create_straight_csg(render_len, width, -2.0, 128) 
            piece_node.add_child(ai_vision)
            piece_node.add_child(_create_ai_sidewall(render_len, -width/2.0 - 2.0))
            piece_node.add_child(_create_ai_sidewall(render_len, width/2.0 + 2.0))
            
            if abs(incline) < 0.1:
                end_transform = end_transform.translated_local(Vector3(0, 0, -length))
            else:
                piece_node.rotate_object_local(Vector3(1, 0, 0), deg_to_rad(incline) / 2.0)
                var theta = deg_to_rad(incline)
                var R = length / abs(theta)
                var sign_pitch = 1.0 if incline > 0 else -1.0
                var y = (R - R * cos(abs(theta))) * sign_pitch
                var z = -R * sin(abs(theta))
                end_transform = current_transform.translated_local(Vector3(0, y, z))
                end_transform.basis = end_transform.basis.rotated(current_transform.basis.x, theta)
            
        elif type == "curve":
            var raw_angle = float(piece.get("angle", 90.0))
            if abs(raw_angle) < 1.0: raw_angle = 1.0 if raw_angle >= 0 else -1.0
            var angle = raw_angle
            var radius = max(1.0, float(piece.get("radius", 100.0)))
            var width = float(piece.get("width", 104.0))
            
            var forward = -current_transform.basis.z
            var pitch = atan2(forward.y, Vector2(forward.x, forward.z).length())
            var flat_forward = Vector3(forward.x, 0, forward.z).normalized()
            if flat_forward.length_squared() < 0.01: flat_forward = -current_transform.basis.y
            var flat_right = flat_forward.cross(Vector3.UP).normalized()
            var flat_basis = Basis(flat_right, Vector3.UP, -flat_forward)
            var flat_transform = Transform3D(flat_basis, current_transform.origin)
            
            piece_node.global_transform = flat_transform
            
            var curve_data = _create_curve_csg(angle, radius, width, piece_node, curve_start_t[i], curve_end_t[i], pitch, curve_banked[i])
            
            var angle_rad = deg_to_rad(abs(angle))
            var sign_val = 1.0 if angle < 0 else -1.0
            var slope = tan(pitch)
            var has_incline = abs(pitch) > 0.01
            
            var end_pos = Vector3(radius * (1.0 - cos(angle_rad)) * sign_val, radius * angle_rad * slope, -radius * sin(angle_rad))
            var end_flat_basis = flat_basis.rotated(Vector3.UP, angle_rad * -sign_val)
            
            end_transform.origin = flat_transform * end_pos
            end_transform.basis = end_flat_basis.rotated(end_flat_basis.x, pitch)
            
        elif type == "transition":
            var length = float(piece.get("length", 100.0))
            var sw = float(piece.get("start_width", 104.0))
            var ew = float(piece.get("end_width", 52.0))
            
            var incline = float(piece.get("incline", 0.0))
            var render_len = length
            
            if abs(incline) >= 0.1:
                var theta = deg_to_rad(incline)
                var R = length / abs(theta)
                var sign_pitch = 1.0 if incline > 0 else -1.0
                var y = (R - R * cos(abs(theta))) * sign_pitch
                var z = -R * sin(abs(theta))
                render_len = max(0.1, sqrt(y*y + z*z))
            
            var road = _create_transition_csg(render_len, sw, ew, 0.0)
            piece_node.add_child(road)
            var border_l = _create_transition_border(render_len, -sw/2.0, -ew/2.0)
            piece_node.add_child(border_l)
            var border_r = _create_transition_border(render_len, sw/2.0, ew/2.0)
            piece_node.add_child(border_r)
            
            var ai_vision = _create_transition_csg(render_len, sw, ew, -2.0, 128)
            piece_node.add_child(ai_vision)
            
            var ai_wall_l = _create_transition_border(render_len, -sw/2.0 - 2.0, -ew/2.0 - 2.0)
            ai_wall_l.position.y = 20.0
            ai_wall_l.depth = 40.0
            ai_wall_l.collision_layer = 128
            ai_wall_l.collision_mask = 0
            ai_wall_l.visible = false
            piece_node.add_child(ai_wall_l)
            
            var ai_wall_r = _create_transition_border(render_len, sw/2.0 + 2.0, ew/2.0 + 2.0)
            ai_wall_r.position.y = 20.0
            ai_wall_r.depth = 40.0
            ai_wall_r.collision_layer = 128
            ai_wall_r.collision_mask = 0
            ai_wall_r.visible = false
            piece_node.add_child(ai_wall_r)
            
            if abs(incline) < 0.1:
                end_transform = end_transform.translated_local(Vector3(0, 0, -length))
            else:
                piece_node.rotate_object_local(Vector3(1, 0, 0), deg_to_rad(incline) / 2.0)
                var theta = deg_to_rad(incline)
                var R = length / abs(theta)
                var sign_pitch = 1.0 if incline > 0 else -1.0
                var y = (R - R * cos(abs(theta))) * sign_pitch
                var z = -R * sin(abs(theta))
                end_transform = current_transform.translated_local(Vector3(0, y, z))
                end_transform.basis = end_transform.basis.rotated(current_transform.basis.x, theta)
            
        elif type == "gate":
            var tw = float(piece.get("track_width", 104.0))
            var gw = max(float(piece.get("gate_width", 140.0)), tw + 20.0)
            
            var trans_len = max(10.0, (gw - tw) / 2.0)
            var flat_len = 12.0
            var length = trans_len * 2.0 + flat_len
            
            # 1. Expand
            var road1 = _create_transition_csg(trans_len, tw, gw, 0.0)
            piece_node.add_child(road1)
            var bl1 = _create_transition_border(trans_len, -tw/2.0, -gw/2.0)
            piece_node.add_child(bl1)
            var br1 = _create_transition_border(trans_len, tw/2.0, gw/2.0)
            piece_node.add_child(br1)
            var ai1 = _create_transition_csg(trans_len, tw, gw, -2.0, 128)
            piece_node.add_child(ai1)
            
            # 2. Flat middle
            var flat_node = Node3D.new()
            flat_node.transform.origin = Vector3(0, 0, -trans_len)
            piece_node.add_child(flat_node)
            
            var road_flat = _create_straight_csg(flat_len, gw, 0.0)
            flat_node.add_child(road_flat)
            var bl_flat = _create_straight_border(flat_len, -gw/2.0)
            flat_node.add_child(bl_flat)
            var br_flat = _create_straight_border(flat_len, gw/2.0)
            flat_node.add_child(br_flat)
            var ai_flat = _create_straight_csg(flat_len, gw, -2.0, 128)
            flat_node.add_child(ai_flat)
            
            # 3. Contract
            var end_node = Node3D.new()
            end_node.transform.origin = Vector3(0, 0, -trans_len - flat_len)
            piece_node.add_child(end_node)
            
            var road2 = _create_transition_csg(trans_len, gw, tw, 0.0)
            end_node.add_child(road2)
            var bl2 = _create_transition_border(trans_len, -gw/2.0, -tw/2.0)
            end_node.add_child(bl2)
            var br2 = _create_transition_border(trans_len, gw/2.0, tw/2.0)
            end_node.add_child(br2)
            var ai2 = _create_transition_csg(trans_len, gw, tw, -2.0, 128)
            end_node.add_child(ai2)
            
            # Pillars inside align with outer edges of track width
            var pillar_l = CSGBox3D.new()
            pillar_l.size = Vector3(4.0, 20.0, 4.0)
            pillar_l.position = Vector3(-tw/2.0 - 2.0, 10.0, -trans_len - flat_len/2.0)
            pillar_l.use_collision = true
            
            var pillar_r = CSGBox3D.new()
            pillar_r.size = Vector3(4.0, 20.0, 4.0)
            pillar_r.position = Vector3(tw/2.0 + 2.0, 10.0, -trans_len - flat_len/2.0)
            pillar_r.use_collision = true
            
            piece_node.add_child(pillar_l)
            piece_node.add_child(pillar_r)
            
            # Top beam
            var beam = CSGBox3D.new()
            beam.size = Vector3(tw + 8.0, 4.0, 4.0)
            beam.position = Vector3(0, 22.0, -trans_len - flat_len/2.0)
            beam.use_collision = true
            piece_node.add_child(beam)
            
            end_transform = end_transform.translated_local(Vector3(0, 0, -length))
            
        elif type == "bank_transition":
            var length = float(piece.get("length", 100.0))
            var width = float(piece.get("width", 104.0))
            
            # Find next curve direction
            var next_sign = 1.0
            var found = false
            for j in range(i + 1, render_data.size()):
                var t = render_data[j].get("type", "")
                if t == "curve":
                    var raw_ang = float(render_data[j].get("angle", 90.0))
                    next_sign = 1.0 if raw_ang < 0 else -1.0
                    found = true
                    break
                elif t in ["straight", "bank_transition", "gap", "drop"]:
                    break
                    
            # Check if we're *leaving* a curve
            var prev_sign = 1.0
            var prev_found = false
            for j in range(i - 1, -1, -1):
                var t = render_data[j].get("type", "")
                if t == "curve":
                    var raw_ang = float(render_data[j].get("angle", 90.0))
                    prev_sign = 1.0 if raw_ang < 0 else -1.0
                    prev_found = true
                    break
                elif t in ["straight", "bank_transition", "gap", "drop"]:
                    break
                    
            var max_tilt = deg_to_rad(15.0)
            
            # Determine if entering or exiting
            var start_tilt = 0.0
            var end_tilt = 0.0
            if found and not prev_found:
                end_tilt = max_tilt * next_sign
            elif prev_found and not found:
                start_tilt = max_tilt * prev_sign
            elif found and prev_found:
                start_tilt = max_tilt * prev_sign
                end_tilt = max_tilt * next_sign
                
            _build_bank_transition(piece_node, length, width, start_tilt, end_tilt)
            
            # End transform does NOT account for y_bump because the curve piece natively adds it!
            end_transform = end_transform.translated_local(Vector3(0, 0, -length))
        elif type == "right_angle":
            var radius = piece.get("radius", 20.0)
            var width = piece.get("width", 10.0)
            var is_left = piece.get("is_left", true)
            
            var csg_node = _create_right_angle_csg(radius, width, is_left)
            piece_node.add_child(csg_node)
            
            var end_pos = Vector3(-radius if is_left else radius, 0, -radius)
            end_transform.origin = current_transform * end_pos
            
            var angle_rad = deg_to_rad(90.0 if is_left else -90.0)
            end_transform.basis = current_transform.basis.rotated(Vector3.UP, angle_rad)
            
        elif type == "gap":
            var width = float(piece.get("width", 104.0))
            var ramp_angle = float(piece.get("ramp_angle", 45.0))
            var gap_length = float(piece.get("gap_length", 50.0))
            var ramp_size = float(piece.get("ramp_size", 20.0))
            
            # Legacy fallback if they DO have length and ramp_length
            if piece.has("length") and piece.has("ramp_length"):
                var old_length = float(piece.get("length"))
                ramp_size = float(piece.get("ramp_length"))
                var old_theta = deg_to_rad(abs(ramp_angle))
                var old_R = (ramp_size * 0.75) / old_theta if old_theta > 0.001 else 0.0
                var old_z_curve = old_R * sin(old_theta) if old_theta > 0.001 else 0.0
                var old_z_straight = (ramp_size * 0.25) * cos(old_theta) if old_theta > 0.001 else ramp_size
                gap_length = old_length - 2.0 * (old_z_curve + old_z_straight)
                if gap_length < 0: gap_length = 0.0
                
            var ramp_len = ramp_size
            
            var theta = deg_to_rad(abs(ramp_angle))
            var Lc = ramp_size * 0.75
            var Ls = ramp_size * 0.25
            var R = Lc / theta if theta > 0.001 else 0.0
            var z_curve = R * sin(theta) if theta > 0.001 else 0.0
            var z_straight = Ls * cos(theta) if theta > 0.001 else ramp_size
            var ramp_z = z_curve + z_straight
            
            var length = gap_length + 2.0 * ramp_z

            
            var ai_vision = _create_transition_csg(length, width, width, -20.0, 128)
            piece_node.add_child(ai_vision)
            piece_node.add_child(_create_ai_sidewall(length, -width/2.0 - 2.0))
            piece_node.add_child(_create_ai_sidewall(length, width/2.0 + 2.0))
            
            var launch_node = Node3D.new()
            piece_node.add_child(launch_node)
            _create_curved_ramp_editor(launch_node, width, ramp_angle, ramp_len)
            
            var land_node = Node3D.new()
            piece_node.add_child(land_node)
            land_node.position = Vector3(0, 0, -length)
            land_node.rotation_degrees.y = 180
            _create_curved_ramp_editor(land_node, width, ramp_angle, ramp_len)
            
            end_transform = end_transform.translated_local(Vector3(0, 0, -length))
            
        elif type == "close_loop":
            var width = float(piece.get("width", 104.0))
            
            var end_pos_global = Vector3(0, 0, 0)
            var end_dir_global = Vector3(0, 0, -1)
            
            var start_pos_local = Vector3.ZERO
            var start_dir_local = Vector3(0, 0, -1)
            var end_pos_local = current_transform.affine_inverse() * end_pos_global
            var end_dir_local = current_transform.basis.inverse() * end_dir_global
            
            var dist = start_pos_local.distance_to(end_pos_local)
            if dist < 0.1:
                # Update transform to the start and skip mesh generation
                current_transform.origin = end_pos_global
                current_transform.basis = Basis()
                continue
                
            var handle_len = max(dist * 0.4, width * 0.8)
            
            var path = Path3D.new()
            path.name = "Path3D"
            path.curve = Curve3D.new()
            path.curve.bake_interval = 0.01
            
            # In Godot 4 Curve3D, handles are relative to the point.
            # Handle out is the forward direction.
            path.curve.add_point(start_pos_local, Vector3.ZERO, start_dir_local * handle_len)
            path.curve.add_point(end_pos_local, -end_dir_local * handle_len, Vector3.ZERO)
            
            var root = Node3D.new()
            piece_node.add_child(root)
            root.add_child(path)
            
            _build_path_csg_elements(root, path, width, true)
            
            # Update transform to the start
            current_transform.origin = end_pos_global
            current_transform.basis = Basis()
            
            end_transform.origin = end_pos_global
            end_transform.basis = Basis()
            
        elif type == "drop":
            var distance = float(piece.get("drop_distance", 20.0))
            end_transform.origin.y -= distance
            
        current_transform = end_transform


    _update_selection_indicators()


func _create_right_angle_csg(radius: float, width: float, is_left: bool) -> Node3D:
    var node = Node3D.new()
    var hw = width / 2.0
    
    # Road
    var road = CSGPolygon3D.new()
    road.mode = CSGPolygon3D.MODE_DEPTH
    road.depth = 0.5
    var pts = PackedVector2Array()
    if is_left:
        pts.push_back(Vector2(hw, 0))
        pts.push_back(Vector2(hw, radius + hw))
        pts.push_back(Vector2(-radius, radius + hw))
        pts.push_back(Vector2(-radius, radius - hw))
        pts.push_back(Vector2(-hw, radius - hw))
        pts.push_back(Vector2(-hw, 0))
    else:
        pts.push_back(Vector2(-hw, 0))
        pts.push_back(Vector2(-hw, radius + hw))
        pts.push_back(Vector2(radius, radius + hw))
        pts.push_back(Vector2(radius, radius - hw))
        pts.push_back(Vector2(hw, radius - hw))
        pts.push_back(Vector2(hw, 0))
    road.polygon = pts
    road.use_collision = true
    var mat = load("res://materials/grey_cracked_rock/grey_cracked_rock.tres")
    if mat:
        mat = mat.duplicate()
        mat.uv1_triplanar = true
        road.material = mat
    road.rotation_degrees = Vector3(-90, 0, 0)
    node.add_child(road)
    
    # Centerline
    var cline = CSGPolygon3D.new()
    cline.mode = CSGPolygon3D.MODE_DEPTH
    cline.depth = 0.1
    var cw = 1.2
    var cpts = PackedVector2Array()
    if is_left:
        cpts.push_back(Vector2(cw, 0))
        cpts.push_back(Vector2(cw, radius + cw))
        cpts.push_back(Vector2(-radius, radius + cw))
        cpts.push_back(Vector2(-radius, radius - cw))
        cpts.push_back(Vector2(-cw, radius - cw))
        cpts.push_back(Vector2(-cw, 0))
    else:
        cpts.push_back(Vector2(-cw, 0))
        cpts.push_back(Vector2(-cw, radius + cw))
        cpts.push_back(Vector2(radius, radius + cw))
        cpts.push_back(Vector2(radius, radius - cw))
        cpts.push_back(Vector2(cw, radius - cw))
        cpts.push_back(Vector2(cw, 0))
    cline.polygon = cpts
    cline.use_collision = false
    
    var cmat = StandardMaterial3D.new()
    cmat.albedo_color = Color(1.0, 0.0, 1.0, 1.0)
    cmat.emission_enabled = true
    cmat.emission = Color(1.0, 0.0, 1.0, 1.0)
    cline.material = cmat
    
    cline.rotation_degrees = Vector3(-90, 0, 0)
    cline.position = Vector3(0, 0.35, 0)
    node.add_child(cline)
    
    # Borders
    var bw = 1.0
    var bh = 4.0
    var b_mat = StandardMaterial3D.new()
    b_mat.albedo_color = Color(0, 0.9, 0.9, 1)
    b_mat.emission_enabled = true
    b_mat.emission = Color(0, 0.9, 0.9, 1)
    
    var ob = CSGPolygon3D.new()
    ob.mode = CSGPolygon3D.MODE_DEPTH
    ob.depth = bh
    var opts = PackedVector2Array()
    if is_left:
        opts.push_back(Vector2(hw - bw, 0))
        opts.push_back(Vector2(hw + bw, 0))
        opts.push_back(Vector2(hw + bw, radius + hw + bw))
        opts.push_back(Vector2(-radius, radius + hw + bw))
        opts.push_back(Vector2(-radius, radius + hw - bw))
        opts.push_back(Vector2(hw - bw, radius + hw - bw))
    else:
        opts.push_back(Vector2(-hw + bw, 0))
        opts.push_back(Vector2(-hw - bw, 0))
        opts.push_back(Vector2(-hw - bw, radius + hw + bw))
        opts.push_back(Vector2(radius, radius + hw + bw))
        opts.push_back(Vector2(radius, radius + hw - bw))
        opts.push_back(Vector2(-hw + bw, radius + hw - bw))
    ob.polygon = opts
    ob.use_collision = true
    ob.material = b_mat
    ob.rotation_degrees = Vector3(-90, 0, 0)
    ob.position = Vector3(0, 4.0, 0)
    node.add_child(ob)
    
    var ib = CSGPolygon3D.new()
    ib.mode = CSGPolygon3D.MODE_DEPTH
    ib.depth = bh
    var ipts = PackedVector2Array()
    if is_left:
        ipts.push_back(Vector2(-hw - bw, 0))
        ipts.push_back(Vector2(-hw + bw, 0))
        ipts.push_back(Vector2(-hw + bw, radius - hw + bw))
        ipts.push_back(Vector2(-radius, radius - hw + bw))
        ipts.push_back(Vector2(-radius, radius - hw - bw))
        ipts.push_back(Vector2(-hw - bw, radius - hw - bw))
    else:
        ipts.push_back(Vector2(hw + bw, 0))
        ipts.push_back(Vector2(hw - bw, 0))
        ipts.push_back(Vector2(hw - bw, radius - hw + bw))
        ipts.push_back(Vector2(radius, radius - hw + bw))
        ipts.push_back(Vector2(radius, radius - hw - bw))
        ipts.push_back(Vector2(hw + bw, radius - hw - bw))
    ib.polygon = ipts
    ib.use_collision = true
    ib.material = b_mat
    ib.rotation_degrees = Vector3(-90, 0, 0)
    ib.position = Vector3(0, 4.0, 0)
    node.add_child(ib)
    
    return node

func _create_straight_csg(length: float, width: float, y_offset: float, collision_layer: int = 1) -> CSGPolygon3D:
    var csg = CSGPolygon3D.new()
    csg.mode = CSGPolygon3D.MODE_DEPTH
    csg.depth = max(0.1, length)
    
    var hw = width / 2.0
    csg.polygon = PackedVector2Array([
        Vector2(-hw, y_offset),
        Vector2(hw, y_offset),
        Vector2(hw, y_offset - 0.5),
        Vector2(-hw, y_offset - 0.5)
    ])
    
    csg.use_collision = true
    if collision_layer != 1:
        csg.collision_layer = collision_layer
        csg.collision_mask = 0
        csg.visible = false
    else:
        var mat = load("res://materials/grey_cracked_rock/grey_cracked_rock.tres")
        if mat:
            mat = mat.duplicate()
            mat.uv1_triplanar = true
            mat.uv1_world_triplanar = true
            mat.uv1_scale = Vector3(0.05, 0.05, 0.05) # Uniform scale for all orientations
            csg.material = mat
    return csg

func _create_straight_border(length: float, x_offset: float) -> CSGPolygon3D:
    var csg = CSGPolygon3D.new()
    csg.mode = CSGPolygon3D.MODE_DEPTH
    csg.depth = max(0.1, length)
    
    var w = 2.0
    csg.polygon = PackedVector2Array([
        Vector2(x_offset - w/2.0, 4.0),
        Vector2(x_offset + w/2.0, 4.0),
        Vector2(x_offset + w/2.0, 0.0),
        Vector2(x_offset - w/2.0, 0.0)
    ])
    csg.use_collision = true
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0, 0.9, 0.9, 1)
    mat.emission_enabled = true
    mat.emission = Color(0, 0.9, 0.9, 1)
    csg.material = mat
    return csg

func _create_ai_sidewall(length: float, x_offset: float) -> CSGPolygon3D:
    var csg = CSGPolygon3D.new()
    csg.mode = CSGPolygon3D.MODE_DEPTH
    csg.depth = max(0.1, length)
    
    var w = 2.0
    csg.polygon = PackedVector2Array([
        Vector2(x_offset - w/2.0, 20.0),
        Vector2(x_offset + w/2.0, 20.0),
        Vector2(x_offset + w/2.0, -20.0),
        Vector2(x_offset - w/2.0, -20.0)
    ])
    csg.use_collision = true
    csg.collision_layer = 128
    csg.collision_mask = 0
    csg.visible = false
    return csg


func _create_transition_csg(length: float, sw: float, ew: float, y_offset: float, collision_layer: int = 1) -> CSGPolygon3D:
    var csg = CSGPolygon3D.new()
    csg.mode = CSGPolygon3D.MODE_DEPTH
    csg.depth = 0.5 
    
    csg.polygon = PackedVector2Array([
        Vector2(-sw/2.0, 0),
        Vector2(-ew/2.0, length),
        Vector2(ew/2.0, length),
        Vector2(sw/2.0, 0)
    ])
    csg.rotation_degrees.x = -90
    csg.position.y = y_offset
    
    csg.use_collision = true
    if collision_layer != 1:
        csg.collision_layer = collision_layer
        csg.collision_mask = 0
        csg.visible = false
    else:
        var mat = load("res://materials/grey_cracked_rock/grey_cracked_rock.tres")
        if mat:
            mat = mat.duplicate()
            mat.uv1_triplanar = true
            mat.uv1_world_triplanar = true
            mat.uv1_scale = Vector3(0.05, 0.05, 0.05) # Uniform scale for all orientations
            csg.material = mat
    return csg

func _create_transition_border(length: float, start_x: float, end_x: float) -> CSGPolygon3D:
    var csg = CSGPolygon3D.new()
    csg.mode = CSGPolygon3D.MODE_DEPTH
    csg.depth = 4.0 
    
    var w = 2.0
    csg.polygon = PackedVector2Array([
        Vector2(start_x - w/2.0, 0),
        Vector2(end_x - w/2.0, length),
        Vector2(end_x + w/2.0, length),
        Vector2(start_x + w/2.0, 0)
    ])
    csg.rotation_degrees.x = -90
    csg.position.y = 4.0 
    
    csg.use_collision = true
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0, 0.9, 0.9, 1)
    mat.emission_enabled = true
    mat.emission = Color(0, 0.9, 0.9, 1)
    csg.material = mat
    return csg


func _create_curve_csg(angle: float, radius: float, width: float, parent: Node3D, start_t: float, end_t: float, pitch: float = 0.0, banked: bool = true) -> Dictionary:
    var path = Path3D.new()
    path.name = "Path3D"
    var curve = Curve3D.new()
    curve.bake_interval = 0.01
    
    var num_points = max(32, int(abs(angle) * 1.5))
    var angle_rad = deg_to_rad(abs(angle))
    var sign_val = 1.0 if angle < 0 else -1.0 
    var slope = tan(pitch)
    var has_incline = abs(pitch) > 0.01
    
    var expected_flat = Basis().rotated(Vector3.UP, angle_rad * -sign_val)
    var expected_basis = expected_flat.rotated(expected_flat.x, pitch)
    
    var build_curve_points = func(c: Curve3D, torsion: float, apply_tilt: bool):
        c.clear_points()
        for i in range(num_points + 1):
            var t = float(i) / num_points
            var current_angle = t * angle_rad
            var global_t = lerp(start_t, end_t, t)
            var max_tilt = (0.0 if (has_incline or not banked) else deg_to_rad(15.0)) * sign_val
            var nascar_tilt = max_tilt
            
            var y_bump = (width / 2.0) * abs(sin(nascar_tilt))
            
            var x = radius * (1.0 - cos(current_angle)) * sign_val
            var z = -radius * sin(current_angle)
            var y = (radius * current_angle * slope) + y_bump
            
            var d_global_t_dt = end_t - start_t
            var d_nascar_dt = 0.0
            var d_ybump_dt = (width / 2.0) * sign(nascar_tilt) * cos(nascar_tilt) * d_nascar_dt if max_tilt != 0.0 else 0.0
            
            var tan_y = (radius * slope) + (d_ybump_dt / angle_rad)
            var tan_x = radius * sin(current_angle) * sign_val
            var tan_z = -radius * cos(current_angle)
            var tangent = Vector3(tan_x, tan_y, tan_z)
            
            var handle = tangent * ((angle_rad / num_points) / 3.0)
            
            c.add_point(Vector3(x, y, z), -handle, handle)
            if apply_tilt:
                c.set_point_tilt(i, nascar_tilt + lerp(0.0, torsion, t))
            else:
                c.set_point_tilt(i, 0.0)

    var temp_c = Curve3D.new()
    temp_c.bake_interval = 0.01
    temp_c.up_vector_enabled = true
    build_curve_points.call(temp_c, 0.0, false)
    
    var tf1 = temp_c.sample_baked_with_rotation(temp_c.get_baked_length(), false, true)
    var proj_x = tf1.basis.x.dot(expected_basis.x)
    var proj_y = tf1.basis.x.dot(expected_basis.y)
    var torsion_error = atan2(proj_y, proj_x)
    
    build_curve_points.call(curve, torsion_error, true)
        
    path.curve = curve
    var root = Node3D.new()
    parent.add_child(root)
    root.add_child(path)
    
    _build_path_csg_elements(root, path, width, true)
    
    return {"node": root}

func _build_path_csg_elements(root: Node3D, path: Path3D, width: float, path_local: bool = false):
    var create_path_csg = func(poly: PackedVector2Array, c_layer: int, is_border: bool):
        var csg = CSGPolygon3D.new()
        path.add_child(csg)
        csg.mode = CSGPolygon3D.MODE_PATH
        csg.path_node = NodePath("..")
        csg.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
        csg.path_local = path_local
        csg.path_continuous_u = true
        csg.path_u_distance = 16.0
        csg.path_interval = 0.5
        csg.path_rotation_accurate = true
        csg.path_simplify_angle = 0.0
        csg.path_interval_type = 0

        csg.use_collision = true
        
        if is_border:
            var bmat = StandardMaterial3D.new()
            bmat.albedo_color = Color(0, 0.9, 0.9, 1)
            bmat.emission_enabled = true
            bmat.emission = Color(0, 0.9, 0.9, 1)
            csg.material = bmat
        elif c_layer != 1:
            csg.collision_layer = c_layer
            csg.collision_mask = 0
            csg.visible = false
        else:
            var mat = load("res://materials/grey_cracked_rock/grey_cracked_rock.tres")
            if mat:
                mat = mat.duplicate()
                mat.uv1_triplanar = true
                mat.uv1_world_triplanar = true
                mat.uv1_scale = Vector3(0.05, 0.05, 0.05)
                csg.material = mat
        csg.polygon = poly
    var hw = width / 2.0
    var road_poly = PackedVector2Array([Vector2(-hw, -0.5), Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw, -0.5)])
    create_path_csg.call(road_poly, 1, false)
    
    var w = 2.0
    # Clockwise winding for borders
    var left_b = PackedVector2Array([Vector2(-hw - w/2.0, 0.0), Vector2(-hw - w/2.0, 4.0), Vector2(-hw + w/2.0, 4.0), Vector2(-hw + w/2.0, 0.0)])
    create_path_csg.call(left_b, 1, true)
    
    var right_b = PackedVector2Array([Vector2(hw - w/2.0, 0.0), Vector2(hw - w/2.0, 4.0), Vector2(hw + w/2.0, 4.0), Vector2(hw + w/2.0, 0.0)])
    create_path_csg.call(right_b, 1, true)
    
    # Centerline
    var c_line = PackedVector2Array([Vector2(-1.2, 0.35), Vector2(1.2, 0.35), Vector2(1.2, 0.25), Vector2(-1.2, 0.25)])
    var cline_csg = CSGPolygon3D.new()
    path.add_child(cline_csg)
    cline_csg.mode = CSGPolygon3D.MODE_PATH
    cline_csg.path_node = NodePath("..")
    cline_csg.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
    cline_csg.path_local = path_local
    cline_csg.path_continuous_u = true
    cline_csg.use_collision = false
    var cmat = StandardMaterial3D.new()
    cmat.albedo_color = Color(1.0, 0.0, 1.0, 1.0)
    cmat.emission_enabled = true
    cmat.emission = Color(1.0, 0.0, 1.0, 1.0)
    cline_csg.material = cmat
    cline_csg.polygon = c_line
    
    var ai_l = PackedVector2Array([Vector2(-hw - 2.0 - w/2.0, -20.0), Vector2(-hw - 2.0 + w/2.0, -20.0), Vector2(-hw - 2.0 + w/2.0, 20.0), Vector2(-hw - 2.0 - w/2.0, 20.0)])
    create_path_csg.call(ai_l, 128, false)
    
    var ai_r = PackedVector2Array([Vector2(hw + 2.0 - w/2.0, -20.0), Vector2(hw + 2.0 + w/2.0, -20.0), Vector2(hw + 2.0 + w/2.0, 20.0), Vector2(hw + 2.0 - w/2.0, 20.0)])
    create_path_csg.call(ai_r, 128, false)
    
    var ai_f = PackedVector2Array([Vector2(-hw, -2.5), Vector2(-hw, -2.0), Vector2(hw, -2.0), Vector2(hw, -2.5)])
    create_path_csg.call(ai_f, 128, false)


func _build_bank_transition(root: Node3D, length: float, width: float, start_tilt: float, end_tilt: float):
    var path = Path3D.new()
    var curve = Curve3D.new()
    curve.bake_interval = 0.01
    
    var num_points = max(20, int(length / 2.0))
    for i in range(num_points + 1):
        var t = float(i) / num_points
        var smooth_t = t * t * (3.0 - 2.0 * t)
        var current_tilt = lerp(start_tilt, end_tilt, smooth_t)
        
        var y_bump = (width / 2.0) * abs(sin(current_tilt))
        
        var z = -length * t
        var y = y_bump
        
        var d_smooth_dt = (6.0 * t - 6.0 * t * t) / length
        var d_tilt_dt = (end_tilt - start_tilt) * d_smooth_dt
        var d_ybump_dt = (width / 2.0) * sign(current_tilt) * cos(current_tilt) * d_tilt_dt if current_tilt != 0.0 else 0.0
        
        var tangent = Vector3(0, d_ybump_dt, -1)
        var handle = tangent * (length / num_points / 3.0)
        
        curve.add_point(Vector3(0, y, z), -handle, handle)
        curve.set_point_tilt(i, current_tilt)
        
    path.curve = curve
    root.add_child(path)
    
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.2, 0.2, 0.2)
    
    var bmat = StandardMaterial3D.new()
    bmat.albedo_color = Color(0.0, 1.0, 1.0)
    
    var hw = width / 2.0
    var csg = CSGPolygon3D.new()
    path.add_child(csg)
    csg.mode = CSGPolygon3D.MODE_PATH
    csg.path_node = NodePath("..")
    csg.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
    csg.path_local = true
    csg.path_continuous_u = true
    csg.path_u_distance = 16.0
    csg.path_interval = 0.25
    csg.path_rotation_accurate = true
    csg.path_simplify_angle = 0.0
    csg.path_interval_type = 0
    csg.use_collision = true
    csg.material = mat
    csg.polygon = PackedVector2Array([Vector2(-hw, -0.5), Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw, -0.5)])
    
    var w = 2.0
    
    var l_border = csg.duplicate()
    path.add_child(l_border)
    l_border.material = bmat
    l_border.polygon = PackedVector2Array([Vector2(-hw - w/2.0, 4.0), Vector2(-hw + w/2.0, 4.0), Vector2(-hw + w/2.0, 0.0), Vector2(-hw - w/2.0, 0.0)])
    
    var r_border = csg.duplicate()
    path.add_child(r_border)
    r_border.material = bmat
    r_border.polygon = PackedVector2Array([Vector2(hw - w/2.0, 4.0), Vector2(hw + w/2.0, 4.0), Vector2(hw + w/2.0, 0.0), Vector2(hw - w/2.0, 0.0)])

func _create_curved_ramp_editor(root: Node3D, width: float, ramp_angle: float, ramp_length: float):
    var path = Path3D.new()
    var curve = Curve3D.new()
    curve.bake_interval = 0.5
    
    var Lc = ramp_length * 0.75
    var Ls = ramp_length * 0.25
    var theta = deg_to_rad(abs(ramp_angle))
    var R = Lc / theta if theta > 0.001 else 0.0
    var sign_a = sign(ramp_angle) if ramp_angle != 0.0 else 1.0
    
    var num_curve_points = max(10, int(Lc / 2.0))
    var current_pos = Vector3.ZERO
    
    for i in range(num_curve_points + 1):
        var phi = (float(i) / num_curve_points) * theta
        var y = R * (1 - cos(phi)) * sign_a if R > 0 else 0.0
        var z = -R * sin(phi) if R > 0 else -Lc * (float(i)/num_curve_points)
        var pos = Vector3(0, y, z)
        
        var tangent = Vector3(0, R * sin(phi) * sign_a, -R * cos(phi)).normalized() if R > 0 else Vector3(0, 0, -1)
        var handle = tangent * (Lc / num_curve_points / 3.0)
        
        curve.add_point(pos, -handle, handle)
        current_pos = pos
        
    var end_pos = current_pos + Vector3(0, Ls * sin(theta) * sign_a, -Ls * cos(theta))
    curve.add_point(end_pos)
    
    path.curve = curve
    root.add_child(path)
    
    var create_csg = func(poly: PackedVector2Array, mat: Material):
        var csg = CSGPolygon3D.new()
        path.add_child(csg)
        csg.mode = CSGPolygon3D.MODE_PATH
        csg.path_node = NodePath("..")
        csg.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
        csg.path_interval = 2.0
        csg.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
        csg.path_local = true
        csg.path_continuous_u = true
        csg.path_u_distance = 16.0
        csg.polygon = poly
        if mat: csg.material = mat
        csg.use_collision = false
        return csg
        
    var mat_asphalt = load("res://materials/grey_cracked_rock/grey_cracked_rock.tres")
    if mat_asphalt:
        mat_asphalt = mat_asphalt.duplicate()
        mat_asphalt.uv1_triplanar = true
        mat_asphalt.uv1_world_triplanar = true
        mat_asphalt.uv1_scale = Vector3(0.05, 0.05, 0.05)
    
    var cmat = StandardMaterial3D.new()
    cmat.albedo_color = Color(1.0, 0.0, 1.0, 1.0)
    cmat.emission_enabled = true
    cmat.emission = Color(1.0, 0.0, 1.0, 1.0)
    
    var bmat = StandardMaterial3D.new()
    bmat.albedo_color = Color(0.0, 1.0, 1.0, 1.0)
    bmat.emission_enabled = true
    bmat.emission = Color(0.0, 1.0, 1.0, 1.0)
    
    var hw = width / 2.0
    var road_poly = PackedVector2Array([Vector2(-hw, -0.5), Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw, -0.5)])
    create_csg.call(road_poly, mat_asphalt)
    
    var c_line = PackedVector2Array([Vector2(-1.2, 0.35), Vector2(1.2, 0.35), Vector2(1.2, 0.25), Vector2(-1.2, 0.25)])
    create_csg.call(c_line, cmat)
    
    var w = 2.0
    var border_l = PackedVector2Array([
        Vector2(-hw - w/2.0, 0.0), Vector2(-hw - w/2.0, 4.0), Vector2(-hw + w/2.0, 4.0), Vector2(-hw + w/2.0, 0.0)
    ])
    create_csg.call(border_l, bmat)
    
    var border_r = PackedVector2Array([
        Vector2(hw - w/2.0, 0.0), Vector2(hw - w/2.0, 4.0), Vector2(hw + w/2.0, 4.0), Vector2(hw + w/2.0, 0.0)
    ])
    create_csg.call(border_r, bmat)




func _add_selection_indicator(piece_node: Node3D, piece: Dictionary, is_red: bool = false):
    var type = piece.get("type", "")
    var w = piece.get("width", 104.0)
    var aabb = AABB()
    
    if type == "straight":
        var l = piece.get("length", 100.0)
        aabb = AABB(Vector3(-w/2.0 - 5.0, -10.0, -l - 5.0), Vector3(w + 10.0, 20.0, l + 10.0))
    elif type == "curve":
        var r = piece.get("radius", 100.0)
        var a = piece.get("angle", 90.0)
        var is_left = a > 0
        var theta = deg_to_rad(abs(a))
        var z_max = r * sin(theta)
        var x_max = r * (1.0 - cos(theta))
        if abs(a) > 90.0:
            z_max = r
            if abs(a) > 180.0:
                x_max = r * 2.0
            
        if is_left:
            aabb = AABB(Vector3(-x_max - w/2.0 - 5.0, -10.0, -z_max - 5.0), Vector3(x_max + w + 10.0, 20.0, z_max + 10.0))
        else:
            aabb = AABB(Vector3(-w/2.0 - 5.0, -10.0, -z_max - 5.0), Vector3(x_max + w + 10.0, 20.0, z_max + 10.0))
    elif type == "gap":
        var gap_len = piece.get("gap_length", 50.0)
        var ramp_size = piece.get("ramp_size", 20.0)
        var total_len = gap_len + 2.0 * ramp_size
        aabb = AABB(Vector3(-w/2.0 - 5.0, -40.0, -total_len - 5.0), Vector3(w + 10.0, 60.0, total_len + 10.0))
    elif type == "drop":
        var drop = piece.get("drop_distance", 20.0)
        aabb = AABB(Vector3(-w/2.0 - 5.0, min(-drop - 5.0, -5.0), -5.0), Vector3(w + 10.0, abs(drop) + 10.0, 10.0))
    else:
        var l = piece.get("length", 100.0)
        aabb = AABB(Vector3(-w/2.0 - 5.0, -10.0, -l - 5.0), Vector3(w + 10.0, 20.0, l + 10.0))
        
    var mesh = ImmediateMesh.new()
    var mat = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(1.0, 0.0, 0.0, 1.0) if is_red else Color(1.0, 1.0, 1.0, 1.0)
    
    mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
    var p0 = aabb.position
    var p1 = p0 + Vector3(aabb.size.x, 0, 0)
    var p2 = p0 + Vector3(aabb.size.x, aabb.size.y, 0)
    var p3 = p0 + Vector3(0, aabb.size.y, 0)
    var p4 = p0 + Vector3(0, 0, aabb.size.z)
    var p5 = p0 + Vector3(aabb.size.x, 0, aabb.size.z)
    var p6 = p0 + Vector3(aabb.size.x, aabb.size.y, aabb.size.z)
    var p7 = p0 + Vector3(0, aabb.size.y, aabb.size.z)
    
    mesh.surface_add_vertex(p0); mesh.surface_add_vertex(p1)
    mesh.surface_add_vertex(p1); mesh.surface_add_vertex(p2)
    mesh.surface_add_vertex(p2); mesh.surface_add_vertex(p3)
    mesh.surface_add_vertex(p3); mesh.surface_add_vertex(p0)
    
    mesh.surface_add_vertex(p4); mesh.surface_add_vertex(p5)
    mesh.surface_add_vertex(p5); mesh.surface_add_vertex(p6)
    mesh.surface_add_vertex(p6); mesh.surface_add_vertex(p7)
    mesh.surface_add_vertex(p7); mesh.surface_add_vertex(p4)
    
    mesh.surface_add_vertex(p0); mesh.surface_add_vertex(p4)
    mesh.surface_add_vertex(p1); mesh.surface_add_vertex(p5)
    mesh.surface_add_vertex(p2); mesh.surface_add_vertex(p6)
    mesh.surface_add_vertex(p3); mesh.surface_add_vertex(p7)
    mesh.surface_end()
    
    var mi = MeshInstance3D.new()
    mi.mesh = mesh
    piece_node.add_child(mi)


func _update_selection_indicators():
    for child in built_nodes:
        if is_instance_valid(child):
            for grandchild in child.get_children():
                if grandchild is MeshInstance3D and grandchild.mesh is ImmediateMesh:
                    grandchild.queue_free()
                    
    if built_nodes.size() > 0:
        if not is_hole_mode:
            if track_data.size() > 0:
                _add_selection_indicator(built_nodes.back(), track_data.back(), false)
        else:
            if build_direction == 1 and track_data.size() > 0:
                _add_selection_indicator(built_nodes[track_data.size() - 1], track_data.back(), false)
            elif build_direction == -1 and track_after_hole.size() > 0:
                _add_selection_indicator(built_nodes[track_data.size()], track_after_hole[0], false)
                
        var select_undo_mode = lua_manager.get_global_float("editor_select_undo_mode") > 0.5
        if select_undo_mode and hovered_piece_index >= 0 and hovered_piece_index < built_nodes.size():
            var hover_child = built_nodes[hovered_piece_index]
            var piece_data = {}
            if hovered_piece_index < track_data.size():
                piece_data = track_data[hovered_piece_index]
            else:
                var offset_idx = hovered_piece_index - track_data.size()
                if offset_idx < track_after_hole.size():
                    piece_data = track_after_hole[offset_idx]
            if piece_data.size() > 0:
                _add_selection_indicator(hover_child, piece_data, true)

func _unhandled_input(event):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        var select_undo_mode = lua_manager.get_global_float("editor_select_undo_mode") > 0.5
        if select_undo_mode and not is_hole_mode and hovered_piece_index != -1:
            _delete_piece(hovered_piece_index)

func _handle_raycast():
    if is_hole_mode: return
    var cam = get_viewport().get_camera_3d()
    if not cam: return
    var mouse_pos = get_viewport().get_mouse_position()
    var ray_length = 1000.0
    var from = cam.project_ray_origin(mouse_pos)
    var to = from + cam.project_ray_normal(mouse_pos) * ray_length
    var space = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(from, to)
    var result = space.intersect_ray(query)
    
    var new_hover = -1
    if result:
        var col = result.collider
        var n = col
        while n and n != get_tree().root:
            if n.name.begins_with("Piece_"):
                new_hover = n.name.trim_prefix("Piece_").to_int()
                break
            n = n.get_parent()
            
    if new_hover != hovered_piece_index:
        hovered_piece_index = new_hover
        rebuild_track()

func _delete_piece(idx: int):
    if idx < 0 or idx >= track_data.size(): return
    history_stack.append(track_data.duplicate(true))
    
    if idx + 1 < built_nodes.size():
        hole_anchor_transform = built_nodes[idx + 1].transform
    else:
        hole_anchor_transform = Transform3D.IDENTITY
    
    var new_data = []
    track_after_hole = []
    
    for i in range(track_data.size()):
        if i < idx:
            new_data.append(track_data[i])
        elif i > idx:
            track_after_hole.append(track_data[i])
            
    track_data = new_data
    is_hole_mode = track_after_hole.size() > 0
    build_direction = 1
    hovered_piece_index = -1
    lua_manager.set_global_float("editor_select_undo_mode", 0.0)
    rebuild_track()


func _get_piece_offset(piece: Dictionary) -> Transform3D:
    var t = Transform3D.IDENTITY
    var type = piece.get("type", "straight")
    if type == "straight" or type == "transition" or type == "gate" or type == "bank_transition":
        var l = float(piece.get("length", 100.0))
        var incline = float(piece.get("incline", 0.0))
        if abs(incline) >= 0.1:
            var theta = deg_to_rad(incline)
            var R = l / abs(theta)
            var sign_pitch = 1.0 if incline > 0 else -1.0
            var y = (R - R * cos(abs(theta))) * sign_pitch
            var z = -R * sin(abs(theta))
            t = t.translated_local(Vector3(0, y, z))
            t = t.rotated_local(Vector3.RIGHT, theta)
        else:
            t = t.translated_local(Vector3(0, 0, -l))
    elif type == "curve":
        var radius = float(piece.get("radius", 100.0))
        var angle = float(piece.get("angle", 90.0))
        var is_left = angle > 0
        var theta = deg_to_rad(abs(angle))
        var sign_x = -1.0 if is_left else 1.0
        var x = (radius - radius * cos(theta)) * sign_x
        var z = -radius * sin(theta)
        t = t.translated_local(Vector3(x, 0, z))
        t = t.rotated_local(Vector3.UP, theta * (1.0 if is_left else -1.0))
    elif type == "gap":
        var gap_len = float(piece.get("gap_length", 50.0))
        var ramp_size = float(piece.get("ramp_size", 20.0))
        var ramp_angle = float(piece.get("ramp_angle", 45.0))
        var theta = deg_to_rad(ramp_angle)
        var R = (ramp_size * 0.75) / theta
        var z_curve = R * sin(theta)
        var z_straight = (ramp_size * 0.25) * cos(theta)
        var total_z = gap_len + 2.0 * (z_curve + z_straight)
        t = t.translated_local(Vector3(0, 0, -total_z))
    elif type == "drop":
        var drop = float(piece.get("drop_distance", 20.0))
        t = t.translated_local(Vector3(0, -drop, 0))
    elif type == "right_angle":
        var radius = float(piece.get("radius", 20.0))
        var is_left = piece.get("is_left", true)
        var sign_x = -1.0 if is_left else 1.0
        t = t.translated_local(Vector3(radius * sign_x, 0, -radius))
        t = t.rotated_local(Vector3.UP, (PI/2.0) * (1.0 if is_left else -1.0))
    return t

func _add_new_piece(piece: Dictionary):
    history_stack.append({"d": track_data.duplicate(true), "a": track_after_hole.duplicate(true), "anc": hole_anchor_transform, "hole": is_hole_mode, "dir": build_direction})
    if not is_hole_mode or build_direction == 1:
        track_data.append(piece)
    else:
        var offset = _get_piece_offset(piece)
        hole_anchor_transform = hole_anchor_transform * offset.affine_inverse()
        track_after_hole.insert(0, piece)


func _create_spline_transition(piece: Dictionary, current_transform: Transform3D) -> Node3D:
    var width = float(piece.get("width", 104.0))
    var target_pos = Vector3(piece.get("target_pos_x", 0.0), piece.get("target_pos_y", 0.0), piece.get("target_pos_z", 0.0))
    var target_rot = Vector3(piece.get("target_rot_x", 0.0), piece.get("target_rot_y", 0.0), piece.get("target_rot_z", 0.0))
    var target_transform = Transform3D(Basis.from_euler(target_rot), target_pos)
    
    var root = Node3D.new()
    var path = Path3D.new()
    var curve = Curve3D.new()
    
    var local_target = current_transform.affine_inverse() * target_transform
    
    var start_pos = Vector3.ZERO
    var start_dir = Vector3(0, 0, -1)
    var end_dir = -local_target.basis.z
    var dist = start_pos.distance_to(local_target.origin)
    var c_len = dist * 0.5
    
    curve.add_point(start_pos, Vector3.ZERO, start_dir * c_len)
    curve.add_point(local_target.origin, -end_dir * c_len, Vector3.ZERO)
    path.curve = curve
    root.add_child(path)
    
    _build_path_csg_elements(root, path, width, true)
    
    var res = Node3D.new()
    res.add_child(root)
    
    # Store end transform in a metadata node or return it
    var end_node = Node3D.new()
    end_node.name = "EndTransform"
    end_node.transform = target_transform
    res.add_child(end_node)
    
    return res

