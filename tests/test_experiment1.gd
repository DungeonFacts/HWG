extends SceneTree

func _init():
	call_deferred("_run_test")

func _run_test():
	print("=== Running Experiment 1 (Scarcity) Test ===")
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	main.switch_experiment(1)
	await process_frame

	assert(main.active_experiment == 1, "Expected Exp 1 active")
	assert(main.inventory_cards.size() == 5, "Expected 5 initial cards in Exp 1")

	# Find wand crafting event and slot cards
	var wand_event = main.events_container.get_child(0)
	var wizard_card = {}
	var yew_card = {}
	for card in main.inventory_cards:
		if card.id == "wizard": wizard_card = card
		if card.id == "yew_heartwood": yew_card = card

	assert(wand_event.slot_instances[0].slot_card(wizard_card), "Slot wizard into wand event")
	assert(wand_event.slot_instances[1].slot_card(yew_card), "Slot yew into wand event")

	# Craft Wand
	main._on_event_action_triggered(wand_event, "exp1_craft_wand")
	await process_frame

	assert(main.exp1_yew_committed == true, "Yew wood committed")

	# Verify yew heartwood was consumed
	var remaining_yew = {}
	for card in main.inventory_cards:
		if card.id == "yew_heartwood": remaining_yew = card
	assert(remaining_yew.is_empty(), "Yew Heartwood consumed")

	# Resolve final Crisis Event with Wand
	var crisis_event = main.events_container.get_child(3)
	var wand_card = {}
	for card in main.inventory_cards:
		if card.id == "yew_wand": wand_card = card
	assert(not wand_card.is_empty(), "Wand present")

	assert(crisis_event.slot_instances[0].slot_card(wand_card), "Slot wand into crisis event")
	main._on_event_action_triggered(crisis_event, "exp1_resolve_crisis")
	await process_frame

	assert(main.current_stage == "COMPLETE", "Experiment 1 complete")
	print("=== EXPERIMENT 1 TEST PASSED SUCCESSFULLY! ===")
	quit()
