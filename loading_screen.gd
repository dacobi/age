extends CanvasLayer

var progress_bar: ProgressBar
var active: bool = false
var checking_load: bool = false
var current_target_scene: String = ""
var load_progress: Array = []
@onready var lua_manager = get_node("/root/LuaManager")

func _ready():
	layer = 100
	visible = false
	
	var ui_root = Control.new()
	add_child(ui_root)
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var bg = ColorRect.new()
	bg.color = Color.BLACK
	ui_root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var center = CenterContainer.new()
	ui_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	var label = Label.new()
	label.text = "LOADING"
	label.add_theme_font_size_override("font_size", 180)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 40)
	progress_bar.show_percentage = false
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(progress_bar)

func start_loading(script_name: String):
	checking_load = false
	progress_bar.value = 0.0
	visible = true
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	current_target_scene = ""
	
	lua_manager._do_clear_and_run(script_name)
	checking_load = true

func switch_to_level(target_path: String) -> void:
	current_target_scene = target_path
	load_progress.resize(1)
	
	var error = ResourceLoader.load_threaded_request(target_path)
	if error != OK:
		print("Error: Scene file path could not be loaded into memory.")
		lua_manager.finish_gdscript_load()
		visible = false
		return
		
	visible = true
	active = true

func _process(_delta: float) -> void:
	# Fallback for scripts that don't trigger switch_to_level (like cars.lua)
	if lua_manager.has_method("is_loading_engine") and checking_load:
		if not lua_manager.is_loading_engine() and current_target_scene == "":
			visible = false
			
	if not active:
		return
		
	var status = ResourceLoader.load_threaded_get_status(current_target_scene, load_progress)
	
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var progress_percentage = load_progress[0] * 100.0
			progress_bar.value = progress_percentage
			
		ResourceLoader.THREAD_LOAD_LOADED:
			progress_bar.value = 100.0
			active = false
			
			var packed_scene = ResourceLoader.load_threaded_get(current_target_scene)
			get_tree().change_scene_to_packed(packed_scene)
			
			# Wait for Godot to finish the synchronous instantiation freeze
			await get_tree().process_frame
			
			lua_manager.finish_gdscript_load()
			visible = false
			
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			print("Critical Error: Thread background scene load sequence failed.")
			active = false
			lua_manager.finish_gdscript_load()
			visible = false
