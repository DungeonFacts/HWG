extends SceneTree

func _init():
	call_deferred("_run_screenshot")

func _run_screenshot():
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var viewport = root.get_viewport()
	var img = viewport.get_texture().get_image()
	if img:
		img.save_png("screenshot.png")
		print("Screenshot saved to screenshot.png")
	quit()
