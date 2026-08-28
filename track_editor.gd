extends Node3D

var track_data: Array = []
var history_stack: Array = []
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
    if action > 0.0:
        if action >= 1.0 and action <= 7.0:
            history_stack.append(track_data.duplicate(true))
            
        var p1 = lua_manager.get_global_float("editor_param_1")
        var p2 = lua_manager.get_global_float("editor_param_2")
        var p3 = lua_manager.get_global_float("editor_param_3")
        var p4 = lua_manager.get_global_float("editor_param_4")
        var p5 = lua_manager.get_global_float("editor_param_5")
        var p6 = lua_manager.get_global_float("editor_param_6")
        
        if action == 1.0:
            track_data.append({"type": "straight", "length": p1, "width": p2, "incline": p4})
        elif action == 2.0:
            track_data.append({"type": "curve", "angle": p1, "radius": p3, "width": p2})
        elif action == 3.0:
            track_data.append({"type": "drop", "drop_distance": p4})
        elif action == 4.0:
            track_data.append({"type": "transition", "length": p1, "start_width": p2, "end_width": p5, "incline": p4})
        elif action == 5.0:
            track_data.append({"type": "gate", "length": p1, "track_width": p2, "gate_width": p5})
        elif action == 6.0:
            track_data.append({"type": "gap", "length": p1, "width": p2, "ramp_angle": p6, "ramp_length": max(5.0, p1 * 0.2)})
        elif action == 7.0:
            track_data.append({"type": "close_loop", "width": p2})
        elif action == 8.0:
            lua_manager.set_global_float("editor_action", 0.0)
            _show_file_dialog(false)
            return
        elif action == 9.0:
            lua_manager.set_global_float("editor_action", 0.0)
            _show_file_dialog(true)
            return
        elif action == 10.0:
            if history_stack.size() > 0:
                track_data = history_stack.pop_back()
            
        lua_manager.set_global_float("editor_action", 0.0)
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
        file.store_string(JSON.stringify(track_data, "	"))
        file.close()

func _on_load_file(path: String):
    history_stack.append(track_data.duplicate(true))
    var file = FileAccess.open(path, FileAccess.READ)
    if file:
        var text = file.get_as_text()
        var data = JSON.parse_string(text)
        if typeof(data) == TYPE_ARRAY:
            track_data = data
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
    
    for i in range(track_data.size()):
        var piece = track_data[i]
        var type = piece.get("type", "straight")
        
        var piece_node = Node3D.new()
        piece_node.name = "Piece_" + str(i)
        track_root.add_child(piece_node)
        built_nodes.append(piece_node)
        
        piece_node.global_transform = current_transform
        var end_transform = current_transform
        
        if type == "straight":
            var length = float(piece.get("length", 100.0))
            var width = float(piece.get("width", 104.0))
            
            var road = _create_straight_csg(length, width, 0.0)
            piece_node.add_child(road)
            var border_l = _create_straight_border(length, -width/2.0)
            piece_node.add_child(border_l)
            var border_r = _create_straight_border(length, width/2.0)
            piece_node.add_child(border_r)
            
            var ai_vision = _create_straight_csg(length, width, -2.0, 128) 
            piece_node.add_child(ai_vision)
            piece_node.add_child(_create_ai_sidewall(length, -width/2.0 - 2.0))
            piece_node.add_child(_create_ai_sidewall(length, width/2.0 + 2.0))
            
            var incline = float(piece.get("incline", 0.0))
            if abs(incline) < 0.1:
                end_transform = end_transform.translated_local(Vector3(0, 0, -length))
            else:
                piece_node.rotation_degrees.x = incline / 2.0
                var theta = deg_to_rad(incline)
                var R = length / abs(theta)
                var sign_pitch = 1.0 if incline > 0 else -1.0
                var y = (R - R * cos(abs(theta))) * sign_pitch
                var z = -R * sin(abs(theta))
                end_transform = current_transform.translated_local(Vector3(0, y, z))
                end_transform.basis = end_transform.basis.rotated(current_transform.basis.x, theta * sign_pitch)
            
        elif type == "curve":
            var raw_angle = float(piece.get("angle", 90.0))
            if abs(raw_angle) < 1.0: raw_angle = 1.0 if raw_angle >= 0 else -1.0
            var angle = raw_angle
            var radius = max(1.0, float(piece.get("radius", 100.0)))
            var width = float(piece.get("width", 104.0))
            
            var curve_data = _create_curve_csg(angle, radius, width, piece_node)
            
            var angle_rad = deg_to_rad(angle)
            var sign = 1.0 if angle < 0 else -1.0
            
            var end_pos = Vector3(radius * (1.0 - cos(angle_rad)) * sign, 0, -radius * sin(angle_rad))
            end_transform = end_transform.translated_local(end_pos)
            end_transform.basis = end_transform.basis.rotated(Vector3.UP, angle_rad * -sign)
            
        elif type == "transition":
            var length = float(piece.get("length", 100.0))
            var sw = float(piece.get("start_width", 104.0))
            var ew = float(piece.get("end_width", 52.0))
            
            var road = _create_transition_csg(length, sw, ew, 0.0)
            piece_node.add_child(road)
            var border_l = _create_transition_border(length, -sw/2.0, -ew/2.0)
            piece_node.add_child(border_l)
            var border_r = _create_transition_border(length, sw/2.0, ew/2.0)
            piece_node.add_child(border_r)
            
            var ai_vision = _create_transition_csg(length, sw, ew, -2.0, 128)
            piece_node.add_child(ai_vision)
            
            var ai_wall_l = _create_transition_border(length, -sw/2.0 - 2.0, -ew/2.0 - 2.0)
            ai_wall_l.position.y = 20.0
            ai_wall_l.depth = 40.0
            ai_wall_l.collision_layer = 128
            ai_wall_l.collision_mask = 0
            ai_wall_l.visible = false
            ai_wall_l.material = null
            piece_node.add_child(ai_wall_l)
            
            var ai_wall_r = _create_transition_border(length, sw/2.0 + 2.0, ew/2.0 + 2.0)
            ai_wall_r.position.y = 20.0
            ai_wall_r.depth = 40.0
            ai_wall_r.collision_layer = 128
            ai_wall_r.collision_mask = 0
            ai_wall_r.visible = false
            ai_wall_r.material = null
            piece_node.add_child(ai_wall_r)
            
            end_transform = end_transform.translated_local(Vector3(0, 0, -length))
            
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
            
        elif type == "gap":
            var length = float(piece.get("length", 100.0))
            var width = float(piece.get("width", 104.0))
            var ramp_angle = float(piece.get("ramp_angle", 15.0))
            var ramp_len = float(piece.get("ramp_length", 20.0))
            
            var ai_vision = _create_transition_csg(length, width, width, -20.0, 128)
            piece_node.add_child(ai_vision)
            piece_node.add_child(_create_ai_sidewall(length, -width/2.0 - 2.0))
            piece_node.add_child(_create_ai_sidewall(length, width/2.0 + 2.0))
            
            var launch_node = Node3D.new()
            piece_node.add_child(launch_node)
            launch_node.rotation_degrees.x = ramp_angle
            
            var road_up = _create_transition_csg(ramp_len, width, width, 0.0)
            launch_node.add_child(road_up)
            var bl_up = _create_transition_border(ramp_len, -width/2.0, -width/2.0)
            launch_node.add_child(bl_up)
            var br_up = _create_transition_border(ramp_len, width/2.0, width/2.0)
            launch_node.add_child(br_up)
            
            var land_node = Node3D.new()
            piece_node.add_child(land_node)
            land_node.position = Vector3(0, 0, -length)
            land_node.rotation_degrees.y = 180
            land_node.rotation_degrees.x = ramp_angle
            
            var road_down = _create_transition_csg(ramp_len, width, width, 0.0)
            land_node.add_child(road_down)
            var bl_down = _create_transition_border(ramp_len, -width/2.0, -width/2.0)
            land_node.add_child(bl_down)
            var br_down = _create_transition_border(ramp_len, width/2.0, width/2.0)
            land_node.add_child(br_down)
            
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
                
            var handle_len = dist * 0.4
            
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


func _create_straight_csg(length: float, width: float, y_offset: float, collision_layer: int = 1) -> CSGPolygon3D:
    var csg = CSGPolygon3D.new()
    csg.mode = CSGPolygon3D.MODE_DEPTH
    csg.depth = length
    
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
    csg.depth = length
    
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
    csg.depth = length
    
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


func _create_curve_csg(angle: float, radius: float, width: float, parent: Node3D) -> Dictionary:
    var path = Path3D.new()
    path.name = "Path3D"
    var curve = Curve3D.new()
    curve.bake_interval = 0.01
    
    var num_points = 20
    var angle_rad = deg_to_rad(abs(angle))
    var sign = 1.0 if angle < 0 else -1.0 
    
    for i in range(num_points + 1):
        var t = float(i) / num_points
        var current_angle = t * angle_rad
        var x = radius * (1.0 - cos(current_angle)) * sign
        var z = -radius * sin(current_angle)
        
        # Tangent vector for a circle:
        # dx/d(theta) = radius * sin(current_angle) * sign
        # dz/d(theta) = -radius * cos(current_angle)
        var tan_x = radius * sin(current_angle) * sign
        var tan_z = -radius * cos(current_angle)
        var tangent = Vector3(tan_x, 0, tan_z)
        
        # Arc length between points is roughly (angle_rad / num_points) * radius
        # The bezier handle length should be scaled appropriately.
        # A good approximation for small angles is handle_len = (arc_length) / 3.0
        var handle_len = (angle_rad / num_points) * radius / 3.0
        var handle = tangent.normalized() * handle_len
        
        curve.add_point(Vector3(x, 0, z), -handle, handle)
        
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
        csg.path_interval = 1.0
        csg.path_rotation_accurate = true
        csg.path_simplify_angle = 0.0
        csg.path_interval_type = 1

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
    var left_b = PackedVector2Array([Vector2(-hw - w/2.0, 0.0), Vector2(-hw + w/2.0, 0.0), Vector2(-hw + w/2.0, 4.0), Vector2(-hw - w/2.0, 4.0)])
    create_path_csg.call(left_b, 1, true)
    
    var right_b = PackedVector2Array([Vector2(hw - w/2.0, 0.0), Vector2(hw + w/2.0, 0.0), Vector2(hw + w/2.0, 4.0), Vector2(hw - w/2.0, 4.0)])
    create_path_csg.call(right_b, 1, true)
    
    var ai_l = PackedVector2Array([Vector2(-hw - 2.0 - w/2.0, -20.0), Vector2(-hw - 2.0 + w/2.0, -20.0), Vector2(-hw - 2.0 + w/2.0, 20.0), Vector2(-hw - 2.0 - w/2.0, 20.0)])
    create_path_csg.call(ai_l, 128, false)
    
    var ai_r = PackedVector2Array([Vector2(hw + 2.0 - w/2.0, -20.0), Vector2(hw + 2.0 + w/2.0, -20.0), Vector2(hw + 2.0 + w/2.0, 20.0), Vector2(hw + 2.0 - w/2.0, 20.0)])
    create_path_csg.call(ai_r, 128, false)
    
    var ai_f = PackedVector2Array([Vector2(-hw, -2.5), Vector2(-hw, -2.0), Vector2(hw, -2.0), Vector2(hw, -2.5)])
    create_path_csg.call(ai_f, 128, false)
