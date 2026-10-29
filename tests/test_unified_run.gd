extends SceneTree

func _init():
	call_deferred("_run_test")

func _run_test():
	print("=== Running Unified Game Run Test ===")
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	main.switch_experiment(10)
	await process_frame

	assert(main.active_experiment == 10, "Expected Unified Game Run active")
	assert(main.inventory_cards.size() == 4, "Expected 4 initial cards in Unified Run")

	# Test 1: Forage Woods by slotting Wizard into Forage Activity
	print("Test 1: Foraging woods...")
	var forage_event = main.events_container.get_child(0) # uni_act_forage
	var wizard_card = {}
	for card in main.inventory_cards:
		if card.id == "wizard": wizard_card = card

	assert(forage_event.slot_instances[0].slot_card(wizard_card), "Slot wizard into forage event")
	assert(forage_event.get_staged_action_id() == "uni_forage", "Action staged for End Turn")

	# Click End Turn -> Should resolve forage action and grant wood or herb
	main._on_end_turn_pressed()
	await process_frame

	assert(main.inventory_cards.size() == 5, "Cards in tableau increased to 5 after forage")

	# Test 2: Multi-turn Carve Totem Ambition
	print("Test 2: Working on Spirit Totem ambition...")
	var yew_card = {}
	for card in main.inventory_cards:
		if card.id == "yew_heartwood": yew_card = card

	# If forage yielded herb instead of yew wood, add yew wood for test determinism
	if yew_card.is_empty():
		main.add_card_to_inventory({"id": "yew_heartwood", "title": "Yew Heartwood", "tag": "yew_heartwood", "description": "Test Yew Wood"})
		for card in main.inventory_cards:
			if card.id == "yew_heartwood": yew_card = card

	# Find totem event
	var totem_event = null
	for child in main.events_container.get_children():
		if child.event_data.id == "uni_amb_totem":
			totem_event = child
			break

	assert(totem_event != null, "Totem event present")
	assert(totem_event.slot_instances[0].slot_card(wizard_card), "Slot wizard into totem event")
	assert(totem_event.slot_instances[1].slot_card(yew_card), "Slot yew into totem event")

	main._on_end_turn_pressed()
	await process_frame

	assert(main.totem_progress == 1, "Totem progress advanced to 1/2")

	# Test 3: Card Expiry / Decay Test
	print("Test 3: Testing expiring cards...")
	main.add_card_to_inventory({
		"id": "fleeting_essence",
		"title": "Fleeting Essence",
		"tag": "reagent",
		"description": "Fades away.",
		"expires_in_turns": 1
	})
	assert(main.inventory_cards.size() >= 5, "Expiring card added")

	main._on_end_turn_pressed()
	await process_frame

	# Check that fleeting essence expired
	var found_fleeting = false
	for card in main.inventory_cards:
		if card.id == "fleeting_essence":
			found_fleeting = true
	assert(not found_fleeting, "Fleeting essence expired and was removed")

	# Test 4: Complete Victory condition (Great Work of Magick)
	print("Test 4: Achieving Victory via Great Work of Magick...")
	main.great_work_progress = 2 # Set to 2/3 so 1 more work triggers win
	var great_work_event = null
	for child in main.events_container.get_children():
		if child.event_data.id == "uni_amb_great_work":
			great_work_event = child
			break

	assert(great_work_event != null, "Great work event present")
	assert(great_work_event.slot_instances[0].slot_card(wizard_card), "Slot wizard into great work")
	var grimoire_card = {}
	for card in main.inventory_cards:
		if card.id == "forbidden_grimoire": grimoire_card = card
	assert(great_work_event.slot_instances[1].slot_card(grimoire_card), "Slot grimoire into great work")

	main._on_end_turn_pressed()
	await process_frame

	assert(main.great_work_progress == 3, "Great work progress reached 3/3")
	assert(main.game_over == true, "Game Over triggered on victory")
	assert(main.current_stage == "VICTORY", "Victory achieved")

	print("=== UNIFIED GAME RUN TEST PASSED SUCCESSFULLY! ===")
	quit()
