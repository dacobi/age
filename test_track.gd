extends Node3D

var supercar: Node3D
var track_root: Node3D
var is_paused = true # Pauses game logic from test_track.lua
var in_edit_mode = false # Matches lua expected property

var orbit_yaw = 0.0
var orbit_pitch = 0.5
var orbit_dist = 18.0
var cam_rx = 0.0
var cam_ry = 0.0
var current_cam_yaw = 0.0
var current_cam_pitch = 0.0
var mouse_dx = 0.0
var mouse_dy = 0.0
var mouse_wheel = 0.0
var key_e_pressed = false
var reset_car = false
var reset_game = false
var start_transform: Transform3D
var is_crash_cam_active = false


func _ready():
    supercar = get_node_or_null("SuperCar")
    
    # Create the root for track elements
    track_root = Node3D.new()
    track_root.name = "TrackRoot"
    add_child(track_root)
    
    # Freeze the supercar initially
    if supercar:
        supercar.process_mode = Node.PROCESS_MODE_DISABLED
        
    # Open File Dialog
    var fd = FileDialog.new()
    fd.access = FileDialog.ACCESS_FILESYSTEM
    fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    fd.use_native_dialog = true
    fd.add_filter("*.json", "Track JSON")
    fd.current_dir = ProjectSettings.globalize_path("user://")
    
    fd.file_selected.connect(_on_file_selected)
    fd.canceled.connect(_on_canceled)
    
    add_child(fd)
    fd.popup_centered(Vector2(600, 400))

func _on_canceled():
    print("Dialog canceled. Loading default track_test1.json")
    var default_path = ProjectSettings.globalize_path("user://track_test1.json")
    if not FileAccess.file_exists(default_path):
        default_path = ProjectSettings.globalize_path("res://track_test1.json")
    _on_file_selected(default_path)

func _on_file_selected(path: String):
    print("Loading track: ", path)
    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        print("Failed to load track file!")
        return
        
    var text = file.get_as_text()
    var data = JSON.parse_string(text)
    file.close()
    
    if typeof(data) != TYPE_ARRAY:
        print("Invalid track data format.")
        return
        
    # Generate the track
    preload("res://track_generator.gd").generate(data, track_root)
    
    # Find the gate or start position
    start_transform = Transform3D()
    var gate_found = false
    
    var children = track_root.get_children()
    for i in range(data.size()):
        if data[i].get("type") == "gate":
            start_transform = children[i].global_transform
            gate_found = true
            break
            
    if not gate_found and children.size() > 0:
        start_transform = children[0].global_transform
        
    # Position Supercar (slightly raised so it drops nicely)
    if supercar:
        var offset = start_transform.basis.z * 10.0 # Move 10m back from the start of the gate piece
        supercar.global_transform = start_transform
        supercar.global_position = supercar.global_position + offset + Vector3(0, 2.0, 0)
        
        # Reset car physics velocities
        if supercar is RigidBody3D:
            supercar.linear_velocity = Vector3.ZERO
            supercar.angular_velocity = Vector3.ZERO
        
        # Unfreeze
        supercar.process_mode = Node.PROCESS_MODE_INHERIT
        
    _spawn_nitros(data, children)
    
    is_paused = false

func _spawn_nitros(data: Array, children: Array):
    var nitro_script = load("res://nitro_powerup.gd")
    if not nitro_script: return
    
    var pieces_with_nitros = 25
    var step = max(1, children.size() / pieces_with_nitros)
    
    var nitro_count = 0
    for i in range(0, children.size(), step):
        if nitro_count >= 25: break
        
        var piece_type = data[i].get("type")
        if piece_type == "gate" or piece_type == "gap" or piece_type == "drop":
            continue
            
        var t = children[i].global_transform
        
        # Random lane offset
        var width = float(data[i].get("width", 40.0))
        var lane_offset = randf_range(-width*0.4, width*0.4)
        
        # Spawn slightly forward into the piece
        var forward_offset = 20.0
        if data[i].has("length"):
            forward_offset = float(data[i]["length"]) * 0.5
            
        var world_pos = t.origin + t.basis.x * lane_offset - t.basis.z * forward_offset + t.basis.y * 5.0
        
        var powerup = StaticBody3D.new()
        powerup.name = "RandomNitroPowerup_" + str(nitro_count)
        powerup.set_script(nitro_script)
        
        track_root.add_child(powerup)
        powerup.global_position = world_pos
        
        nitro_count += 1


func _process(delta):

    if reset_car or (supercar and supercar.global_position.y < -150.0):
        reset_car = false
        if supercar:
            supercar.global_transform = start_transform
            var offset = start_transform.basis.z * 10.0 # Move 10m back from the start of the gate piece
            supercar.global_position = supercar.global_position + offset + Vector3(0, 2.0, 0)
            
            if supercar is RigidBody3D:
                supercar.linear_velocity = Vector3.ZERO
                supercar.angular_velocity = Vector3.ZERO
    if key_e_pressed:
        is_paused = not is_paused
        
    var camera_node = get_node_or_null("Camera3D")
    if camera_node and supercar:
        if is_paused:
            var offset = Vector3(
                sin(orbit_yaw) * cos(orbit_pitch),
                sin(orbit_pitch),
                cos(orbit_yaw) * cos(orbit_pitch)
            ) * orbit_dist
            camera_node.global_position = supercar.global_position + offset
            camera_node.look_at(supercar.global_position, Vector3.UP)

func _physics_process(delta):
    var camera_node = get_node_or_null("Camera3D")
    if camera_node and supercar and not in_edit_mode and not is_paused:
        current_cam_yaw = lerp(current_cam_yaw, -cam_rx * 2.0, 5.0 * delta)
        current_cam_pitch = lerp(current_cam_pitch, cam_ry * 1.0, 5.0 * delta)
        
        var is_grounded = true
        if supercar.has_method("is_grounded"):
            is_grounded = supercar.is_grounded()
            
        var is_flipped = supercar.global_transform.basis.y.dot(Vector3.UP) < 0.4
        var is_falling = supercar.linear_velocity.y < -15.0
        
        if reset_car:
            is_crash_cam_active = false
        elif not is_grounded and (is_flipped or is_falling):
            is_crash_cam_active = true
        elif is_grounded:
            is_crash_cam_active = false
        
        var forward = supercar.global_transform.basis.z.normalized()
        var up = Vector3.UP
        
        var rotated_forward = forward.rotated(up, current_cam_yaw)
        var offset: Vector3
        var pos_lerp_speed = 10.0
        
        if is_crash_cam_active:
            # Zoom out and up
            offset = rotated_forward * 40.0 + Vector3(0, 20.0, 0)
            pos_lerp_speed = 2.0 # Slower, more cinematic follow
        else:
            offset = rotated_forward * 12.0 + Vector3(0, 4.0 + current_cam_pitch * 4.0, 0)
            
        var target_pos = supercar.global_position + offset
        
        camera_node.global_position = camera_node.global_position.lerp(target_pos, pos_lerp_speed * delta)
        var look_target = supercar.global_position + Vector3(0, 1.5, 0)
        if not is_crash_cam_active:
            look_target += supercar.linear_velocity * 0.1
            
        var target_transform = camera_node.global_transform.looking_at(look_target, Vector3.UP)
        camera_node.global_transform = camera_node.global_transform.interpolate_with(target_transform, 10.0 * delta)
