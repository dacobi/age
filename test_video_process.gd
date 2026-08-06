extends SceneTree

var vp = VideoStreamPlayer.new()
var frame_count = 0
var preloaded = false
var unpaused = false
var disabled_time = 0

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
        if vp.get_stream_position() > 0.1:
            vp.process_mode = Node.PROCESS_MODE_DISABLED
            preloaded = true
            disabled_time = Time.get_ticks_msec()
            print("Process Disabled at ", vp.get_stream_position())
    elif not unpaused:
        if Time.get_ticks_msec() - disabled_time > 2000:
            var start_unpause = Time.get_ticks_msec()
            vp.process_mode = Node.PROCESS_MODE_INHERIT
            unpaused = true
            var end_unpause = Time.get_ticks_msec()
            print("Process Enabled, took ", end_unpause - start_unpause, " ms")
    else:
        print("Pos: ", vp.get_stream_position())
        if vp.get_stream_position() > 0.2:
            print("SUCCESS")
            quit()
