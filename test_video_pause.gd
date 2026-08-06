extends SceneTree

var vp = VideoStreamPlayer.new()
var frame_count = 0
var preloaded = false
var unpaused = false

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
    if not preloaded:
        if vp.get_stream_position() > 0.05:
            vp.set_paused(true)
            preloaded = true
            print("Paused at ", vp.get_stream_position())
    elif not unpaused:
        frame_count += 1
        if frame_count > 10:
            var start_unpause = Time.get_ticks_msec()
            vp.set_paused(false)
            unpaused = true
            var end_unpause = Time.get_ticks_msec()
            print("Unpaused, took ", end_unpause - start_unpause, " ms")
    else:
        print("Pos: ", vp.get_stream_position())
        if vp.get_stream_position() > 0.1:
            print("SUCCESS")
            quit()
