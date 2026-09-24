extends SceneTree
func _init():
    var fmod = Engine.get_singleton("FmodServer")
    if fmod:
        for m in fmod.get_method_list():
            if "stop" in m["name"] or "shutdown" in m["name"] or "pause" in m["name"] or "mute" in m["name"]:
                print(m["name"])
    quit()
