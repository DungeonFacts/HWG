extends SceneTree

func _init():
	print("Checking main scene loading...")
	var main_scene = load("res://scenes/main.tscn")
	print("Main scene loaded: ", main_scene != null)
	if main_scene:
		var main_inst = main_scene.instantiate()
		print("Main instance created: ", main_inst != null)
	quit()
