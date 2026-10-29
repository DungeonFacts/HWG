extends SceneTree

func _init():
	call_deferred("_run_test")

func _run_test():
	print("=== Running Full Scenario Integration Test ===")
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	# 1. Stage A: Craft Talisman
	print("[1/5] Stage A: Crafting Talisman...")
	assert(main.current_stage == "A", "Expected Stage A")
	var event_a = main.events_container.get_child(0)
	var wizard_card = main.inventory_cards[0]
	var material_card = main.inventory_cards[1]

	assert(event_a.slot_instances[0].slot_card(wizard_card), "Slot wizard")
	assert(event_a.slot_instances[1].slot_card(material_card), "Slot material")
	main._on_event_action_triggered(event_a, "resolve_craft_talisman")
	await process_frame

	# 2. Stage B: Prepare Tea
	print("[2/5] Stage B: Preparing Tea...")
	assert(main.current_stage == "B", "Expected Stage B")
	var event_b = main.events_container.get_child(0)
	var tea_leaves_card = {}
	for card in main.inventory_cards:
		if card.id == "tea_leaves": tea_leaves_card = card

	assert(event_b.slot_instances[0].slot_card(wizard_card), "Slot wizard")
	assert(event_b.slot_instances[1].slot_card(tea_leaves_card), "Slot tea leaves")
	main._on_event_action_triggered(event_b, "resolve_prepare_tea")
	await process_frame

	# 3. Stage C: Gathering Task & Delayed Payoff
	print("[3/5] Stage C: Starting Gathering Task (2 turns)...")
	assert(main.current_stage == "C", "Expected Stage C")
	var event_c_gather = main.events_container.get_child(0)
	main._on_event_action_triggered(event_c_gather, "start_gathering")
	await process_frame

	assert(main.gathering_task_active == true, "Task active")
	main._on_end_turn_pressed() # Turn 2
	await process_frame
	main._on_end_turn_pressed() # Turn 3
	await process_frame

	assert(main.gathering_task_active == false, "Task completed")
	var herb_card = {}
	for card in main.inventory_cards:
		if card.id == "medicinal_herb": herb_card = card
	assert(not herb_card.is_empty(), "Herb received")

	# Craft Poultice
	print("[4/5] Stage C: Crafting Poultice...")
	var event_c_poultice = main.events_container.get_child(0)
	assert(event_c_poultice.slot_instances[0].slot_card(wizard_card), "Slot wizard")
	assert(event_c_poultice.slot_instances[1].slot_card(herb_card), "Slot herb")
	main._on_event_action_triggered(event_c_poultice, "resolve_poultice")
	await process_frame

	# 4. Stage D: Competing Obligations
	print("[5/5] Stage D: Competing Obligations Decision...")
	assert(main.current_stage == "D", "Expected Stage D")
	assert(main.events_container.get_child_count() == 2, "2 competing events present")

	var event_guest = main.events_container.get_child(0)
	var event_spirit = main.events_container.get_child(1)

	# Verify independent mutable slot state on event instances
	assert(event_guest != event_spirit, "Event instances must be distinct")
	assert(event_guest.slot_instances[0] != event_spirit.slot_instances[0], "Slot instances must be distinct")

	var tea_card = {}
	for card in main.inventory_cards:
		if card.id == "tea": tea_card = card
	assert(not tea_card.is_empty(), "Tea card present")

	# Slot tea into guest event
	assert(event_guest.slot_instances[0].slot_card(tea_card), "Slot tea into guest")
	assert(event_spirit.slot_instances[0].slotted_card_data.is_empty(), "Spirit event slot must remain empty!")

	# Resolve Guest
	main._on_event_action_triggered(event_guest, "welcome_guest")
	await process_frame

	assert(main.current_stage == "COMPLETE", "Scenario complete")
	print("=== ALL SCENARIO TESTS PASSED SUCCESSFULLY! ===")
	quit()
