extends SceneTree

func _init():
	call_deferred("_run_test")

func _run_test():
	print("Testing Stage D (Competing Obligations & Zero Deadline)...")

	# Test Branch 1: Welcome Guest
	var main_scene = load("res://scenes/main.tscn")
	var main1 = main_scene.instantiate()
	root.add_child(main1)
	await process_frame

	_reach_stage_d(main1)
	await process_frame

	assert(main1.current_stage == "D", "Should be in Stage D")
	assert(main1.events_container.get_child_count() == 2, "Should have 2 competing events")

	var event_guest = main1.events_container.get_child(0)
	var event_spirit = main1.events_container.get_child(1)

	assert(event_guest.deadline_turns == 0, "Guest deadline should be 0")
	assert(event_spirit.deadline_turns == 0, "Spirit deadline should be 0")

	# Find Tea card
	var tea_card = {}
	for card in main1.inventory_cards:
		if card.id == "tea":
			tea_card = card
	assert(not tea_card.is_empty(), "Tea card should be in inventory")

	# Resolve Guest branch
	event_guest.slot_instances[0].slot_card(tea_card)
	main1._on_event_action_triggered(event_guest, "welcome_guest")
	await process_frame

	assert(main1.current_stage == "COMPLETE", "Scenario should be complete")
	var has_favor = false
	for card in main1.inventory_cards:
		if card.id == "village_favor":
			has_favor = true
	assert(has_favor, "Village Favor card should be in inventory")

	root.remove_child(main1)
	main1.queue_free()

	# Test Branch 2: Commune Spirits
	var main2 = main_scene.instantiate()
	root.add_child(main2)
	await process_frame

	_reach_stage_d(main2)
	await process_frame

	var event_spirit2 = main2.events_container.get_child(1)
	var tea_card2 = {}
	for card in main2.inventory_cards:
		if card.id == "tea":
			tea_card2 = card

	event_spirit2.slot_instances[0].slot_card(tea_card2)
	main2._on_event_action_triggered(event_spirit2, "commune_spirits")
	await process_frame

	assert(main2.current_stage == "COMPLETE", "Scenario should be complete")
	var has_lore = false
	for card in main2.inventory_cards:
		if card.id == "arcane_lore":
			has_lore = true
	assert(has_lore, "Arcane Lore card should be in inventory")

	root.remove_child(main2)
	main2.queue_free()

	# Test Branch 3: Ending turn without resolving expires both 0-deadline events
	var main3 = main_scene.instantiate()
	root.add_child(main3)
	await process_frame

	_reach_stage_d(main3)
	await process_frame

	assert(main3.events_container.get_child_count() == 2, "Should have 2 active events")
	main3._on_end_turn_pressed()
	await process_frame

	assert(main3.events_container.get_child_count() == 0, "Both 0-deadline events should expire on End Turn")
	print("Stage D Test Passed Successfully!")
	quit()

func _reach_stage_d(main):
	# A
	var event_a = main.events_container.get_child(0)
	event_a.slot_instances[0].slot_card(main.inventory_cards[0])
	event_a.slot_instances[1].slot_card(main.inventory_cards[1])
	main._on_event_action_triggered(event_a, "resolve_craft_talisman")

	# B
	var event_b = main.events_container.get_child(0)
	var wizard_card = {}
	var tea_leaves_card = {}
	for card in main.inventory_cards:
		if card.id == "wizard": wizard_card = card
		elif card.id == "tea_leaves": tea_leaves_card = card
	event_b.slot_instances[0].slot_card(wizard_card)
	event_b.slot_instances[1].slot_card(tea_leaves_card)
	main._on_event_action_triggered(event_b, "resolve_prepare_tea")

	# C Gather
	var event_c_gather = main.events_container.get_child(0)
	main._on_event_action_triggered(event_c_gather, "start_gathering")
	main._on_end_turn_pressed()
	main._on_end_turn_pressed()

	# C Poultice
	var event_c_poultice = main.events_container.get_child(0)
	var herb_card = {}
	for card in main.inventory_cards:
		if card.id == "medicinal_herb": herb_card = card
	event_c_poultice.slot_instances[0].slot_card(wizard_card)
	event_c_poultice.slot_instances[1].slot_card(herb_card)
	main._on_event_action_triggered(event_c_poultice, "resolve_poultice")
