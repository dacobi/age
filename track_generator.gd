class_name TrackGenerator
extends RefCounted

static func get_road_mat() -> Material:
    var mat = load("res://materials/grey_cracked_rock/grey_cracked_rock.tres")
    if mat:
        mat = mat.duplicate()
        mat.uv1_triplanar = true
        mat.uv1_world_triplanar = true
        mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
    return mat

static func get_centerline_mat() -> Material:
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(1.0, 0.0, 1.0, 1.0)
    mat.emission_enabled = true
    mat.emission = Color(1.0, 0.0, 1.0, 1.0)
    mat.emission_energy_multiplier = 2.0
    return mat

static func get_cyan_mat() -> Material:
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.0, 0.9, 0.9, 1.0)
    mat.emission_enabled = true
    mat.emission = Color(0.0, 0.9, 0.9, 1.0)
    return mat

static func _build_straight(root: Node3D, length: float, width: float, incline: float = 0.0):
    var hw = width / 2.0
    
    if abs(incline) < 0.1:
        var road = CSGPolygon3D.new()
        road.mode = CSGPolygon3D.MODE_DEPTH
        road.depth = max(0.1, length)
        road.polygon = PackedVector2Array([
            Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw, -0.5), Vector2(-hw, -0.5)
        ])
        road.use_collision = true
        road.material = get_road_mat()
        root.add_child(road)
        
        var c_line = CSGPolygon3D.new()
        c_line.mode = CSGPolygon3D.MODE_DEPTH
        c_line.depth = max(0.1, length)
        c_line.polygon = PackedVector2Array([
            Vector2(-1.2, 0.25), Vector2(1.2, 0.25), Vector2(1.2, 0.15), Vector2(-1.2, 0.15)
        ])
        c_line.use_collision = true
        c_line.material = get_centerline_mat()
        root.add_child(c_line)
        
        var w = 2.0
        var border_l = CSGPolygon3D.new()
        border_l.mode = CSGPolygon3D.MODE_DEPTH
        border_l.depth = max(0.1, length)
        border_l.polygon = PackedVector2Array([
            Vector2(-hw - w/2.0, 4.0), Vector2(-hw + w/2.0, 4.0), Vector2(-hw + w/2.0, 0.0), Vector2(-hw - w/2.0, 0.0)
        ])
        border_l.use_collision = true
        border_l.material = get_cyan_mat()
        root.add_child(border_l)

        var border_r = CSGPolygon3D.new()
        border_r.mode = CSGPolygon3D.MODE_DEPTH
        border_r.depth = max(0.1, length)
        border_r.polygon = PackedVector2Array([
            Vector2(hw - w/2.0, 4.0), Vector2(hw + w/2.0, 4.0), Vector2(hw + w/2.0, 0.0), Vector2(hw - w/2.0, 0.0)
        ])
        border_r.use_collision = true
        border_r.material = get_cyan_mat()
        root.add_child(border_r)
    else:
        var path = Path3D.new()
        var curve = Curve3D.new()
        curve.bake_interval = 0.01
        
        var theta = deg_to_rad(incline)
        var R = length / abs(theta)
        var sign_pitch = 1.0 if incline > 0 else -1.0
        
        var num_points = 20
        for i in range(num_points + 1):
            var t = float(i) / num_points
            var angle = t * abs(theta)
            var y = (R - R * cos(angle)) * sign_pitch
            var z = -R * sin(angle)
            
            var tan_y = R * sin(angle) * sign_pitch
            var tan_z = -R * cos(angle)
            var tangent = Vector3(0, tan_y, tan_z)
            var handle_len = (abs(theta) / num_points) * R / 3.0
            var handle = tangent.normalized() * handle_len
            
            curve.add_point(Vector3(0, y, z), -handle, handle)
            curve.set_point_tilt(i, 0.0)
            
        path.curve = curve
        root.add_child(path)
        
        var create_path_csg = func(poly: PackedVector2Array, c_layer: int, mat: Material):
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
            csg.path_interval_type = 1
            csg.use_collision = true
            csg.material = mat
            if c_layer != 1:
                csg.collision_layer = c_layer
                csg.collision_mask = 0
                csg.visible = false
            csg.polygon = poly
            
        var road_poly = PackedVector2Array([Vector2(-hw, -0.5), Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw, -0.5)])
        create_path_csg.call(road_poly, 1, get_road_mat())
        
        var c_line_poly = PackedVector2Array([Vector2(-1.2, 0.25), Vector2(1.2, 0.25), Vector2(1.2, 0.15), Vector2(-1.2, 0.15)])
        create_path_csg.call(c_line_poly, 1, get_centerline_mat())
        
        var w = 2.0
        var border_l_poly = PackedVector2Array([
            Vector2(-hw - w/2.0, 4.0), Vector2(-hw + w/2.0, 4.0), Vector2(-hw + w/2.0, 0.0), Vector2(-hw - w/2.0, 0.0)
        ])
        create_path_csg.call(border_l_poly, 1, get_cyan_mat())
        
        var border_r_poly = PackedVector2Array([
            Vector2(hw - w/2.0, 4.0), Vector2(hw + w/2.0, 4.0), Vector2(hw + w/2.0, 0.0), Vector2(hw - w/2.0, 0.0)
        ])
        create_path_csg.call(border_r_poly, 1, get_cyan_mat())
        
        var ai_l = PackedVector2Array([Vector2(-hw - 2.0 - w/2.0, -20.0), Vector2(-hw - 2.0 + w/2.0, -20.0), Vector2(-hw - 2.0 + w/2.0, 20.0), Vector2(-hw - 2.0 - w/2.0, 20.0)])
        create_path_csg.call(ai_l, 128, null)
        
        var ai_r = PackedVector2Array([Vector2(hw + 2.0 - w/2.0, -20.0), Vector2(hw + 2.0 + w/2.0, -20.0), Vector2(hw + 2.0 + w/2.0, 20.0), Vector2(hw + 2.0 - w/2.0, 20.0)])
        create_path_csg.call(ai_r, 128, null)
        
        var ai_f = PackedVector2Array([Vector2(-hw, -2.0), Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw, -2.0)])
        create_path_csg.call(ai_f, 128, null)

static func _build_transition(root: Node3D, length: float, sw: float, ew: float):
    var road = CSGPolygon3D.new()
    road.mode = CSGPolygon3D.MODE_DEPTH
    road.depth = 0.5 
    road.polygon = PackedVector2Array([
        Vector2(-sw/2.0, 0), Vector2(-ew/2.0, length), Vector2(ew/2.0, length), Vector2(sw/2.0, 0)
    ])
    road.rotation_degrees.x = -90
    road.use_collision = true
    road.material = get_road_mat()
    root.add_child(road)
    
    var c_line = CSGPolygon3D.new()
    c_line.mode = CSGPolygon3D.MODE_DEPTH
    c_line.depth = 0.1
    c_line.polygon = PackedVector2Array([
        Vector2(-1.2, 0), Vector2(-1.2, length), Vector2(1.2, length), Vector2(1.2, 0)
    ])
    c_line.rotation_degrees.x = -90
    c_line.position.y = 0.25
    c_line.material = get_centerline_mat()
    root.add_child(c_line)
    
    var w = 2.0
    var border_l = CSGPolygon3D.new()
    border_l.mode = CSGPolygon3D.MODE_DEPTH
    border_l.depth = 4.0
    border_l.polygon = PackedVector2Array([
        Vector2(-sw/2.0 - w/2.0, 0), Vector2(-ew/2.0 - w/2.0, length), 
        Vector2(-ew/2.0 + w/2.0, length), Vector2(-sw/2.0 + w/2.0, 0)
    ])
    border_l.rotation_degrees.x = -90
    border_l.position.y = 4.0
    border_l.use_collision = true
    border_l.material = get_cyan_mat()
    root.add_child(border_l)
    
    var border_r = CSGPolygon3D.new()
    border_r.mode = CSGPolygon3D.MODE_DEPTH
    border_r.depth = 4.0
    border_r.polygon = PackedVector2Array([
        Vector2(sw/2.0 - w/2.0, 0), Vector2(ew/2.0 - w/2.0, length), 
        Vector2(ew/2.0 + w/2.0, length), Vector2(sw/2.0 + w/2.0, 0)
    ])
    border_r.rotation_degrees.x = -90
    border_r.position.y = 4.0
    border_r.use_collision = true
    border_r.material = get_cyan_mat()
    root.add_child(border_r)

static func _build_gap(root: Node3D, length: float, width: float, ramp_angle: float, ramp_length: float):
    var hw = width / 2.0
    var angle_rad = deg_to_rad(ramp_angle)
    var ramp_y = sin(angle_rad) * ramp_length
    var ramp_z = cos(angle_rad) * ramp_length
    
    # Start Ramp
    var launch = Node3D.new()
    launch.rotation_degrees.x = ramp_angle
    root.add_child(launch)
    _build_transition(launch, ramp_length, width, width)
    
    # End Ramp
    var land = Node3D.new()
    land.position = Vector3(0, ramp_y, -length + ramp_z)
    land.rotation_degrees.x = -ramp_angle
    root.add_child(land)
    _build_transition(land, ramp_length, width, width)

static func _build_curve(root: Node3D, angle: float, radius: float, width: float, start_t: float, end_t: float, pitch: float = 0.0):
    var path = Path3D.new()
    path.name = "Path3D"
    var curve = Curve3D.new()
    curve.bake_interval = 0.01
    
    var num_points = 20
    var angle_rad = deg_to_rad(abs(angle))
    var sign_val = 1.0 if angle < 0 else -1.0 
    var slope = tan(pitch)
    var has_incline = abs(pitch) > 0.01
    
    for i in range(num_points + 1):
        var t = float(i) / num_points
        var current_angle = t * angle_rad
        var x = radius * (1.0 - cos(current_angle)) * sign_val
        var z = -radius * sin(current_angle)
        var y = radius * current_angle * slope
        
        var tan_x = radius * sin(current_angle) * sign_val
        var tan_z = -radius * cos(current_angle)
        var tan_y = radius * slope
        var tangent = Vector3(tan_x, tan_y, tan_z)
        
        var handle = tangent * ((angle_rad / num_points) / 3.0)
        curve.add_point(Vector3(x, y, z), -handle, handle)
        
        var global_t = lerp(start_t, end_t, t)
        var max_tilt = (0.0 if has_incline else deg_to_rad(15.0)) * sign_val
        
        # Counteract helix torsion
        var twist = -current_angle * sin(pitch) * sign_val
        curve.set_point_tilt(i, (sin(global_t * PI) * max_tilt) + twist)
        
    path.curve = curve
    root.add_child(path)
    
    var create_path_csg = func(poly: PackedVector2Array, c_layer: int, mat: Material):
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
        csg.path_interval_type = 1
        csg.use_collision = true
        csg.material = mat
        if c_layer != 1:
            csg.collision_layer = c_layer
            csg.collision_mask = 0
            csg.visible = false
        csg.polygon = poly
        
    var hw = width / 2.0
    var road_poly = PackedVector2Array([Vector2(-hw, -0.5), Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw, -0.5)])
    create_path_csg.call(road_poly, 1, get_road_mat())
    
    var c_line = PackedVector2Array([Vector2(-1.2, 0.35), Vector2(1.2, 0.35), Vector2(1.2, 0.25), Vector2(-1.2, 0.25)])
    create_path_csg.call(c_line, 1, get_centerline_mat())
    
    var w = 2.0

    var border_l = PackedVector2Array([
        Vector2(-hw - w/2.0, 4.0), Vector2(-hw + w/2.0, 4.0), Vector2(-hw + w/2.0, 0.0), Vector2(-hw - w/2.0, 0.0)
    ])
    create_path_csg.call(border_l, 1, get_cyan_mat())
    
    var border_r = PackedVector2Array([
        Vector2(hw - w/2.0, 4.0), Vector2(hw + w/2.0, 4.0), Vector2(hw + w/2.0, 0.0), Vector2(hw - w/2.0, 0.0)
    ])
    create_path_csg.call(border_r, 1, get_cyan_mat())
    
    var ai_l = PackedVector2Array([Vector2(-hw - 2.0 - w/2.0, -20.0), Vector2(-hw - 2.0 + w/2.0, -20.0), Vector2(-hw - 2.0 + w/2.0, 20.0), Vector2(-hw - 2.0 - w/2.0, 20.0)])
    create_path_csg.call(ai_l, 128, null)
    
    var ai_r = PackedVector2Array([Vector2(hw + 2.0 - w/2.0, -20.0), Vector2(hw + 2.0 + w/2.0, -20.0), Vector2(hw + 2.0 + w/2.0, 20.0), Vector2(hw + 2.0 - w/2.0, 20.0)])
    create_path_csg.call(ai_r, 128, null)
    
    var ai_f = PackedVector2Array([Vector2(-hw, -2.0), Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw, -2.0)])
    create_path_csg.call(ai_f, 128, null)


static func _build_close_loop(root: Node3D, current_transform: Transform3D, width: float) -> Transform3D:
    var end_pos_global = Vector3(0, 0, 0)
    var end_dir_global = Vector3(0, 0, -1)
    
    var start_pos_local = Vector3.ZERO
    var start_dir_local = Vector3(0, 0, -1)
    var end_pos_local = current_transform.affine_inverse() * end_pos_global
    var end_dir_local = current_transform.basis.inverse() * end_dir_global
    
    var dist = start_pos_local.distance_to(end_pos_local)
    if dist < 0.1:
        var ret = Transform3D()
        ret.origin = end_pos_global
        ret.basis = Basis()
        return ret
        
    var handle_len = dist * 0.4
    var path = Path3D.new()
    path.curve = Curve3D.new()
    path.curve.bake_interval = 0.01
    path.curve.add_point(start_pos_local, Vector3.ZERO, start_dir_local * handle_len)
    path.curve.add_point(end_pos_local, -end_dir_local * handle_len, Vector3.ZERO)
    root.add_child(path)
    
    var create_path_csg = func(poly: PackedVector2Array, c_layer: int, mat: Material):
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
        csg.path_interval_type = 1
        csg.use_collision = true
        csg.material = mat
        if c_layer != 1:
            csg.collision_layer = c_layer
            csg.collision_mask = 0
            csg.visible = false
        csg.polygon = poly
        
    var hw = width / 2.0
    var road_poly = PackedVector2Array([Vector2(-hw, -0.5), Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw, -0.5)])
    create_path_csg.call(road_poly, 1, get_road_mat())
    
    var c_line = PackedVector2Array([Vector2(-1.2, 0.35), Vector2(1.2, 0.35), Vector2(1.2, 0.25), Vector2(-1.2, 0.25)])
    create_path_csg.call(c_line, 1, get_centerline_mat())
    
    var w = 2.0

    var border_l = PackedVector2Array([
        Vector2(-hw - w/2.0, 4.0), Vector2(-hw + w/2.0, 4.0), Vector2(-hw + w/2.0, 0.0), Vector2(-hw - w/2.0, 0.0)
    ])
    create_path_csg.call(border_l, 1, get_cyan_mat())
    
    var border_r = PackedVector2Array([
        Vector2(hw - w/2.0, 4.0), Vector2(hw + w/2.0, 4.0), Vector2(hw + w/2.0, 0.0), Vector2(hw - w/2.0, 0.0)
    ])
    create_path_csg.call(border_r, 1, get_cyan_mat())
    
    var ai_l = PackedVector2Array([Vector2(-hw - 2.0 - w/2.0, -20.0), Vector2(-hw - 2.0 + w/2.0, -20.0), Vector2(-hw - 2.0 + w/2.0, 20.0), Vector2(-hw - 2.0 - w/2.0, 20.0)])
    create_path_csg.call(ai_l, 128, null)
    
    var ai_r = PackedVector2Array([Vector2(hw + 2.0 - w/2.0, -20.0), Vector2(hw + 2.0 + w/2.0, -20.0), Vector2(hw + 2.0 + w/2.0, 20.0), Vector2(hw + 2.0 - w/2.0, 20.0)])
    create_path_csg.call(ai_r, 128, null)
    
    var ai_f = PackedVector2Array([Vector2(-hw, -2.0), Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw, -2.0)])
    create_path_csg.call(ai_f, 128, null)
    
    var ret = Transform3D()
    ret.origin = end_pos_global
    ret.basis = Basis()
    return ret

static func generate(track_data: Array, root_node: Node3D):
    for child in root_node.get_children():
        child.queue_free()
        
    var curve_start_t = []
    var curve_end_t = []
    curve_start_t.resize(track_data.size())
    curve_end_t.resize(track_data.size())
    
    var i_idx = 0
    while i_idx < track_data.size():
        var piece = track_data[i_idx]
        if piece["type"] == "curve":
            var sign_dir = sign(float(piece["angle"]))
            var block_end = i_idx
            var total_angle = abs(float(piece["angle"]))
            
            for j in range(i_idx + 1, track_data.size()):
                if track_data[j]["type"] == "curve" and sign(float(track_data[j]["angle"])) == sign_dir:
                    block_end = j
                    total_angle += abs(float(track_data[j]["angle"]))
                else:
                    break
            
            var current_accum = 0.0
            for j in range(i_idx, block_end + 1):
                var p_ang = abs(float(track_data[j]["angle"]))
                curve_start_t[j] = current_accum / total_angle
                current_accum += p_ang
                curve_end_t[j] = current_accum / total_angle
                
            i_idx = block_end + 1
        else:
            curve_start_t[i_idx] = 0.0
            curve_end_t[i_idx] = 1.0
            i_idx += 1
            
    var current_transform = Transform3D()
    
    for i in range(track_data.size()):
        var piece = track_data[i]
        var root = Node3D.new()
        root_node.add_child(root)
        root.global_transform = current_transform
        
        var end_transform = current_transform
        
        if piece["type"] == "straight":
            var length = piece["length"]
            var width = piece["width"]
            var incline = piece.get("incline", 0.0)
            _build_straight(root, length, width, incline)
            if abs(incline) < 0.1:
                end_transform = current_transform.translated_local(Vector3(0, 0, -length))
            else:
                var theta = deg_to_rad(incline)
                var R = length / abs(theta)
                var sign_pitch = 1.0 if incline > 0 else -1.0
                var y = (R - R * cos(abs(theta))) * sign_pitch
                var z = -R * sin(abs(theta))
                end_transform = current_transform.translated_local(Vector3(0, y, z))
                end_transform.basis = end_transform.basis.rotated(current_transform.basis.x, theta)
            
        elif piece["type"] == "curve":
            var angle = piece["angle"]
            var radius = piece["radius"]
            var width = piece["width"]
            
            var forward = -current_transform.basis.z
            var pitch = atan2(forward.y, Vector2(forward.x, forward.z).length())
            var flat_forward = Vector3(forward.x, 0, forward.z).normalized()
            if flat_forward.length_squared() < 0.01: flat_forward = -current_transform.basis.y
            var flat_right = flat_forward.cross(Vector3.UP).normalized()
            var flat_basis = Basis(flat_right, Vector3.UP, -flat_forward)
            
            var flat_transform = Transform3D(flat_basis, current_transform.origin)
            root.global_transform = flat_transform
            _build_curve(root, angle, radius, width, curve_start_t[i], curve_end_t[i], pitch)
            
            var angle_rad = deg_to_rad(abs(angle))
            var sign_val = 1.0 if angle < 0 else -1.0
            var slope = tan(pitch)
            
            var end_pos = Vector3(radius * (1.0 - cos(angle_rad)) * sign_val, radius * angle_rad * slope, -radius * sin(angle_rad))
            var end_flat_basis = flat_basis.rotated(Vector3.UP, angle_rad * -sign_val)
            
            end_transform.origin = flat_transform * end_pos
            end_transform.basis = end_flat_basis.rotated(end_flat_basis.x, pitch)
            
        elif piece["type"] == "transition":
            var length = piece["length"]
            var sw = piece["start_width"]
            var ew = piece["end_width"]
            _build_transition(root, length, sw, ew)
            end_transform = current_transform.translated_local(Vector3(0, 0, -length))
            
        elif piece["type"] == "gate":
            var tw = float(piece.get("track_width", 104.0))
            var gw = max(float(piece.get("gate_width", 140.0)), tw + 20.0)
            
            var trans_len = max(10.0, (gw - tw) / 2.0)
            var flat_len = 12.0
            var length = trans_len * 2.0 + flat_len
            
            # 1. Expand
            _build_transition(root, trans_len, tw, gw)
            
            # 2. Flat middle
            var flat_node = Node3D.new()
            flat_node.transform.origin = Vector3(0, 0, -trans_len)
            root.add_child(flat_node)
            _build_straight(flat_node, flat_len, gw)
            
            # 3. Contract
            var end_node = Node3D.new()
            end_node.transform.origin = Vector3(0, 0, -trans_len - flat_len)
            root.add_child(end_node)
            _build_transition(end_node, trans_len, gw, tw)
            
            # Pillars
            var rock_mat = load("res://materials/grey_cracked_rock/grey_cracked_rock.tres")
            var pillar_l = CSGBox3D.new()
            pillar_l.size = Vector3(4.0, 20.0, 4.0)
            pillar_l.position = Vector3(-tw/2.0 - 2.0, 10.0, -trans_len - flat_len/2.0)
            pillar_l.use_collision = true
            pillar_l.material = rock_mat
            
            var pillar_r = CSGBox3D.new()
            pillar_r.size = Vector3(4.0, 20.0, 4.0)
            pillar_r.position = Vector3(tw/2.0 + 2.0, 10.0, -trans_len - flat_len/2.0)
            pillar_r.use_collision = true
            pillar_r.material = rock_mat
            
            root.add_child(pillar_l)
            root.add_child(pillar_r)
            
            # Top beam
            var beam = CSGBox3D.new()
            beam.size = Vector3(tw + 8.0, 4.0, 4.0)
            beam.position = Vector3(0, 22.0, -trans_len - flat_len/2.0)
            beam.use_collision = true
            beam.material = rock_mat
            root.add_child(beam)
            
            # Glowing accents
            var glow_band_l = CSGBox3D.new()
            glow_band_l.size = Vector3(4.5, 2.0, 4.5)
            glow_band_l.position = Vector3(0, 5.0, 0)
            glow_band_l.material = get_cyan_mat()
            pillar_l.add_child(glow_band_l)
            
            var glow_band_r = CSGBox3D.new()
            glow_band_r.size = Vector3(4.5, 2.0, 4.5)
            glow_band_r.position = Vector3(0, 5.0, 0)
            glow_band_r.material = get_cyan_mat()
            pillar_r.add_child(glow_band_r)
            
            var beam_top_glow = CSGBox3D.new()
            beam_top_glow.size = Vector3(tw + 8.5, 1.5, 4.5)
            beam_top_glow.position = Vector3(0, 0, 0)
            beam_top_glow.material = get_centerline_mat()
            beam.add_child(beam_top_glow)
            
            end_transform = current_transform.translated_local(Vector3(0, 0, -length))
            
        elif piece["type"] == "gap":
            var length = piece["length"]
            var width = piece["width"]
            var r_angle = piece["ramp_angle"]
            var r_len = piece["ramp_length"]
            _build_gap(root, length, width, r_angle, r_len)
            end_transform = current_transform.translated_local(Vector3(0, 0, -length))
            
        elif piece["type"] == "drop":
            var drop_d = piece["drop_distance"]
            end_transform = current_transform.translated_local(Vector3(0, -drop_d, 0))
            
        elif piece["type"] == "close_loop":
            var width = float(piece.get("width", 104.0))
            end_transform = _build_close_loop(root, current_transform, width)
            
        current_transform = end_transform
