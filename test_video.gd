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
    print("Pos: ", vp.get_stream_position(), " Playing: ", vp.is_playing())
    if vp.get_stream_position() > 0.0:
        print("SUCCESS! position moved.")
        quit()
