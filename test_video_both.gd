extends SceneTree

var vp1 = VideoStreamPlayer.new()
var vp2 = VideoStreamPlayer.new()

func _init():
    var stream1 = ResourceLoader.load("res://track.ogv")
    var stream2 = ResourceLoader.load("res://area.ogv")
    
    vp1.set_stream(stream1)
    vp1.set_autoplay(true)
    get_root().add_child(vp1)
    
    vp2.set_stream(stream2)
    vp2.set_autoplay(true)
    get_root().add_child(vp2)

func _process(delta):
    print("VP1: ", vp1.get_stream_position(), " VP2: ", vp2.get_stream_position())
    if vp1.get_stream_position() > 1.0 and vp2.get_stream_position() > 1.0:
        print("BOTH REACHED 1.0")
        quit()
