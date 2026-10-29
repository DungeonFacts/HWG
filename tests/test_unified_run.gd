extends SceneTree

func _init():
	call_deferred("_run_test")

func _run_test():
	print("=== Running Refined Unified Game Run Test ===")
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	main.switch_experiment(10)
	await process_frame

	assert(main.active_experiment == 10, "Expected Unified Game Run active")
	assert(main.inventory_cards.size() == 4, "Expected 4 initial cards in Unified Run")

	# Test 1: Slotted Card Inventory Filtering
	print("Test 1: Slotted card inventory filtering...")
	var forage_event = main.events_container.get_child(0) # uni_act_forage
	var wizard_card = {}
	for card in main.inventory_cards:
		if card.id == "wizard": wizard_card = card

	# Before slotting, inventory UI container has 4 children
	assert(main.inventory_container.get_child_count() == 4, "Inventory container has 4 cards initially")

	# Slot wizard card into forage
	assert(forage_event.slot_instances[0].slot_card(wizard_card), "Slot wizard into forage event")
	await process_frame

	# Slotted card must be hidden from inventory container!
	assert(main.inventory_container.get_child_count() == 3, "Inventory container hides slotted card (3 visible)")

	# Unslot wizard card
	forage_event.clear_all_slots()
	await process_frame
	assert(main.inventory_container.get_child_count() == 4, "Inventory container restores unslotted card (4 visible)")

	# Test 2: Animate Homunculus
	print("Test 2: Animate Homunculus activity...")
	var homunculus_event = null
	for child in main.events_container.get_children():
		if child.event_data.id == "uni_act_homunculus":
			homunculus_event = child
			break

	assert(homunculus_event != null, "Homunculus activity event present")

	var herb_card = {}
	for card in main.inventory_cards:
		if card.id == "medicinal_herb": herb_card = card

	assert(homunculus_event.slot_instances[0].slot_card(wizard_card), "Slot wizard into homunculus activity")
	assert(homunculus_event.slot_instances[1].slot_card(herb_card), "Slot herb into homunculus activity")

	main._on_end_turn_pressed()
	await process_frame

	var found_homunculus = false
	var homunculus_card = {}
	for card in main.inventory_cards:
		if card.id == "homunculus":
			found_homunculus = true
			homunculus_card = card
	assert(found_homunculus, "Homunculus card created successfully")
	assert(homunculus_card.tag == "wizard", "Homunculus has tag 'wizard'")
	assert(homunculus_card.expires_in_turns == 3, "Homunculus expires in 3 turns")

	# Test 3: Homunculus acting as Wizard in event slot
	print("Test 3: Using Homunculus as Wizard in event...")
	var brew_event = null
	for child in main.events_container.get_children():
		if child.event_data.id == "uni_act_brew":
			brew_event = child
			break

	# Add an herb for brewing
	main.add_card_to_inventory({"id": "medicinal_herb", "title": "Medicinal Herb", "tag": "herb", "description": "Healing plant."})
	var new_herb = main.inventory_cards[main.inventory_cards.size() - 1]

	# Slot Homunculus into Wizard slot of brew_event!
	assert(brew_event.slot_instances[0].slot_card(homunculus_card), "Homunculus accepted in Wizard slot")
	assert(brew_event.slot_instances[1].slot_card(new_herb), "Herb accepted in Herb slot")

	main._on_end_turn_pressed()
	await process_frame

	var found_remedy = false
	for card in main.inventory_cards:
		if card.id == "potent_remedy": found_remedy = true
	assert(found_remedy, "Brewing with Homunculus produced Potent Remedy!")

	# Test 4: Mass Mitigation Threshold (3 Negative Cards)
	print("Test 4: Mass Mitigation event spawning on 3+ negative cards...")
	main.add_card_to_inventory({"id": "villager_grievance", "title": "Villager Grievance", "tag": "grievance", "description": "Negative 1"})
	main.add_card_to_inventory({"id": "blighted_soil", "title": "Blighted Soil", "tag": "path_constraint", "description": "Negative 2"})
	main.add_card_to_inventory({"id": "forest_curse", "title": "Forest Lord Curse", "tag": "curse", "description": "Negative 3"})

	main._refresh_unified_events()
	await process_frame

	var mass_mitigate_event = null
	for child in main.events_container.get_children():
		if child.event_data.id == "uni_evt_mass_mitigate":
			mass_mitigate_event = child
			break

	assert(mass_mitigate_event != null, "Mass Mitigation event spawned when 3 negative cards accumulate")

	print("=== ALL REFINED UNIFIED GAME RUN TESTS PASSED SUCCESSFULLY! ===")
	quit()
