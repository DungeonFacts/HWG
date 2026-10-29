extends SceneTree

func _init():
	call_deferred("_run_test")

func _run_test():
	print("Testing Stage C (Missing Herb & Delayed Task)...")
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)

	await process_frame

	# Resolve Stage A
	var event_a = main.events_container.get_child(0)
	event_a.slot_instances[0].slot_card(main.inventory_cards[0])
	event_a.slot_instances[1].slot_card(main.inventory_cards[1])
	main._on_event_action_triggered(event_a, "resolve_craft_talisman")
	await process_frame

	# Resolve Stage B
	var event_b = main.events_container.get_child(0)
	# Find Wizard card and Tea Leaves card in inventory
	var wizard_card = {}
	var tea_leaves_card = {}
	for card in main.inventory_cards:
		if card.id == "wizard":
			wizard_card = card
		elif card.id == "tea_leaves":
			tea_leaves_card = card

	event_b.slot_instances[0].slot_card(wizard_card)
	event_b.slot_instances[1].slot_card(tea_leaves_card)
	main._on_event_action_triggered(event_b, "resolve_prepare_tea")
	await process_frame

	# Stage C reached
	assert(main.current_stage == "C", "Should be in Stage C")
	print("Entered Stage C. Starting gathering task...")

	var event_c_gather = main.events_container.get_child(0)
	main._on_event_action_triggered(event_c_gather, "start_gathering")
	await process_frame

	assert(main.gathering_task_active == true, "Gathering task should be active")
	assert(main.gathering_turns_remaining == 2, "2 turns should remain")

	# End Turn 1
	main._on_end_turn_pressed()
	await process_frame
	assert(main.gathering_turns_remaining == 1, "1 turn should remain after turn 1")
	assert(main.gathering_task_active == true, "Task should still be active")

	# End Turn 2 - Task completes
	main._on_end_turn_pressed()
	await process_frame
	assert(main.gathering_task_active == false, "Task should be complete")

	# Verify Medicinal Herb received
	var has_herb = false
	var herb_card = {}
	for card in main.inventory_cards:
		if card.id == "medicinal_herb":
			has_herb = true
			herb_card = card
	assert(has_herb, "Medicinal Herb card should be in inventory")

	# Craft Poultice
	var event_c_poultice = main.events_container.get_child(0)
	event_c_poultice.slot_instances[0].slot_card(wizard_card)
	event_c_poultice.slot_instances[1].slot_card(herb_card)
	main._on_event_action_triggered(event_c_poultice, "resolve_poultice")
	await process_frame

	assert(main.current_stage == "D", "Should transition to Stage D after crafting poultice")
	print("Stage C Test Passed Successfully!")
	quit()
