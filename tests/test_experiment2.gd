extends SceneTree

func _init():
	call_deferred("_run_test")

func _run_test():
	print("=== Running Experiment 2 (Neglect & Evolving World) Test ===")
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	main.switch_experiment(2)
	await process_frame

	assert(main.active_experiment == 2, "Expected Exp 2 active")

	# Turn 1: Work on wand, neglect blight & blacksmith & merchant
	print("Turn 1: Working on wand...")
	var wand_event = main.events_container.get_child(0)
	var wizard_card = {}
	for card in main.inventory_cards:
		if card.id == "wizard": wizard_card = card

	assert(wand_event.slot_instances[0].slot_card(wizard_card), "Slot wizard")
	main._on_event_action_triggered(wand_event, "exp2_work_wand")
	await process_frame
	assert(main.exp2_wand_progress == 1, "Wand progress 1/3")

	# Advance turn -> World Evolves (Blight -> Severe, Blacksmith -> Grievance, Merchant -> Leftovers)
	main._on_end_turn_pressed()
	await process_frame

	assert(main.exp2_blight_stage == 2, "Blight escalated to Severe")
	assert(main.exp2_blacksmith_stage == 2, "Blacksmith escalated to Grievance")
	assert(main.exp2_merchant_stage == 2, "Merchant shifted to Leftovers")

	# Turn 2: Work on wand again
	print("Turn 2: Working on wand again...")
	var wand_event_t2 = main.events_container.get_child(0)
	assert(wand_event_t2.slot_instances[0].slot_card(wizard_card), "Slot wizard turn 2")
	main._on_event_action_triggered(wand_event_t2, "exp2_work_wand")
	await process_frame
	assert(main.exp2_wand_progress == 2, "Wand progress 2/3")

	# Turn 3: Work on wand -> completion
	main._on_end_turn_pressed()
	await process_frame
	var wand_event_t3 = main.events_container.get_child(0)
	assert(wand_event_t3.slot_instances[0].slot_card(wizard_card), "Slot wizard turn 3")
	main._on_event_action_triggered(wand_event_t3, "exp2_work_wand")
	await process_frame
	assert(main.exp2_wand_progress == 3, "Wand completed")

	# Conclude
	var conclude_event = main.events_container.get_child(0)
	assert(conclude_event.slot_instances[0].slot_card(wizard_card), "Slot wizard conclude")
	main._on_event_action_triggered(conclude_event, "exp2_conclude")
	await process_frame

	assert(main.current_stage == "COMPLETE", "Experiment 2 complete")
	print("=== EXPERIMENT 2 TEST PASSED SUCCESSFULLY! ===")
	quit()
