extends SceneTree

var frames = 0
var sq: ColorRect
var bar_container: HBoxContainer

func _init():
	var layer = CanvasLayer.new()
	root.add_child(layer)
	
	var ui_root = Control.new()
	layer.add_child(ui_root)
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	bar_container = HBoxContainer.new()
	bar_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar_container.add_theme_constant_override("separation", 30)
	ui_root.add_child(bar_container)
	bar_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	bar_container.position.y += 80
	
	sq = ColorRect.new()
	sq.custom_minimum_size = Vector2(30, 30)
	sq.color = Color.WHITE
	bar_container.add_child(sq)

func _process(delta):
	frames += 1
	if frames == 5:
		print("bar_container pos: ", bar_container.position, " size: ", bar_container.size)
		print("sq pos: ", sq.position, " size: ", sq.size)
		quit()
