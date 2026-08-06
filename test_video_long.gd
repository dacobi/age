extends SceneTree

var vp = VideoStreamPlayer.new()

func _init():
    var stream = ResourceLoader.load("res://track.ogv")
    if stream:
        vp.set_stream(stream)
        vp.set_autoplay(true)
        var root = get_root()
        root.add_child(vp)
    else:
        print("Failed to load video!")

func _process(delta):
    if vp.get_stream_position() > 0.5:
        print("Paused at ", vp.get_stream_position())
        quit()
