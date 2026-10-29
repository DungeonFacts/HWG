extends SceneTree

func _init():
	print("Checking UI components compilation...")
	var card_script = load("res://scripts/card_ui.gd")
	var slot_script = load("res://scripts/slot_ui.gd")
	var event_script = load("res://scripts/event_ui.gd")
	print("Card script loaded: ", card_script != null)
	print("Slot script loaded: ", slot_script != null)
	print("Event script loaded: ", event_script != null)

	var card_scene = load("res://scenes/card_ui.tscn")
	var slot_scene = load("res://scenes/slot_ui.tscn")
	var event_scene = load("res://scenes/event_ui.tscn")
	print("Card scene loaded: ", card_scene != null)
	print("Slot scene loaded: ", slot_scene != null)
	print("Event scene loaded: ", event_scene != null)
	quit()
