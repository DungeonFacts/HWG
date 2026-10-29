extends SceneTree

func _init():
	call_deferred("_run_test")

func _run_test():
	print("=== Running Experiment 3 (Multiple Paths to Power) Test ===")
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	main.switch_experiment(3)
	await process_frame

	assert(main.active_experiment == 3, "Expected Exp 3 active")

	# Test Path 4: Dark Blight Ritual (Instant)
	print("Selecting Dark Ritual Path...")
	var dark_event = main.events_container.get_child(3)
	var wizard_card = {}
	var grimoire_card = {}
	for card in main.inventory_cards:
		if card.id == "wizard": wizard_card = card
		if card.id == "ancient_grimoire": grimoire_card = card

	assert(dark_event.slot_instances[0].slot_card(wizard_card), "Slot wizard into dark ritual")
	assert(dark_event.slot_instances[1].slot_card(grimoire_card), "Slot grimoire into dark ritual")

	main._on_event_action_triggered(dark_event, "exp3_choose_dark")
	await process_frame

	assert(main.exp3_wood_acquired == true, "Yew Wood acquired")
	assert(main.exp3_chosen_path == "dark", "Dark path chosen")

	# Check for Blighted Soil constraint card in inventory
	var constraint_card = {}
	for card in main.inventory_cards:
		if card.id == "blighted_soil": constraint_card = card
	assert(not constraint_card.is_empty(), "Blighted Soil constraint card generated")

	# Face Concluding Trial Event
	var trial_event = main.events_container.get_child(0)
	var yew_card = {}
	for card in main.inventory_cards:
		if card.id == "yew_heartwood": yew_card = card

	assert(trial_event.slot_instances[0].slot_card(wizard_card), "Slot wizard into trial")
	assert(trial_event.slot_instances[1].slot_card(yew_card), "Slot yew into trial")

	main._on_event_action_triggered(trial_event, "exp3_resolve_trial")
	await process_frame

	assert(main.current_stage == "COMPLETE", "Experiment 3 complete")
	print("=== EXPERIMENT 3 TEST PASSED SUCCESSFULLY! ===")
	quit()
