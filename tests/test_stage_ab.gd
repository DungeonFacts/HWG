extends SceneTree

func _init():
	call_deferred("_run_test")

func _run_test():
	print("Testing Stage A & B...")
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)

	await process_frame

	print("Stage is: ", main.current_stage)
	print("Inventory size: ", main.inventory_cards.size())

	assert(main.current_stage == "A", "Should start at Stage A")
	assert(main.inventory_cards.size() == 2, "Should have 2 inventory cards initially")

	var event_node = main.events_container.get_child(0)
	assert(event_node != null, "Event node should exist")

	var wizard_card = main.inventory_cards[0]
	var material_card = main.inventory_cards[1]

	var slot_wiz = event_node.slot_instances[0]
	var slot_mat = event_node.slot_instances[1]

	assert(slot_wiz.slot_card(wizard_card), "Wizard card should slot into wizard_slot")
	assert(slot_mat.slot_card(material_card), "Material card should slot into material_slot")

	main._on_event_action_triggered(event_node, "resolve_craft_talisman")

	await process_frame

	assert(main.current_stage == "B", "Should transition to Stage B")

	var has_talisman = false
	var has_tea_leaves = false
	for card in main.inventory_cards:
		if card.get("id") == "talisman":
			has_talisman = true
		if card.get("id") == "tea_leaves":
			has_tea_leaves = true

	assert(has_talisman, "Should have received Talisman card")
	assert(has_tea_leaves, "Should have received Tea Leaves card")

	print("Stage A -> Stage B Test Passed Successfully!")
	quit()
