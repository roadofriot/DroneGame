extends SceneTree

func _init():
	print("Root viewport size: ", root.get_viewport().size)
	print("DisplayServer window size: ", DisplayServer.window_get_size())
	quit()
