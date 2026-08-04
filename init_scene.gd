extends Node3D

func _ready():
	get_node("/root/LuaManager").run_script("testphysics.lua")
