extends VideoStreamPlayer

var preloaded = false

func _process(delta):
	if not preloaded and is_playing() and not paused:
		if get_stream_position() > 0.05:
			paused = true
			preloaded = true
			set_process(false)
