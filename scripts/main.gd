extends Control

var current_turn: int = 1
var current_stage: String = "A" # "A", "B", "C", "D", "COMPLETE"

# Inventory data
var inventory_cards: Array = []

# Selected card for click-to-slot UI interaction
var selected_card_data: Dictionary = {}
var selected_card_ui = null

# Scenes
var card_ui_scene: PackedScene = preload("res://scenes/card_ui.tscn")
var event_ui_scene: PackedScene = preload("res://scenes/event_ui.tscn")

# UI Nodes
@onready var turn_label: Label = $VBox/TopBar/TurnLabel
@onready var stage_label: Label = $VBox/TopBar/StageLabel
@onready var end_turn_button: Button = $VBox/TopBar/EndTurnButton

@onready var wizard_title_label: Label = $VBox/MainSplit/LeftPanel/WizardStatusBox/VBox/WizardTitleLabel
@onready var wizard_desc_label: Label = $VBox/MainSplit/LeftPanel/WizardStatusBox/VBox/WizardDescLabel
@onready var inventory_container: HFlowContainer = $VBox/MainSplit/LeftPanel/InventoryScroll/InventoryContainer

@onready var events_container: VBoxContainer = $VBox/MainSplit/RightPanel/EventsScroll/EventsContainer
@onready var log_label: RichTextLabel = $VBox/LogPanel/LogMargin/LogLabel

# Card Definitions
var wizard_card_def = {
	"id": "wizard",
	"title": "Hedge Wizard",
	"tag": "wizard",
	"description": "The protector of the village. Knowledgeable in simple craft and rituals."
}

var magical_material_def = {
	"id": "magical_material",
	"title": "Magical Essence",
	"tag": "ingredient",
	"description": "A pinch of shimmering dust used for crafting magical talismans."
}

var tea_leaves_def = {
	"id": "tea_leaves",
	"title": "Tea Leaves",
	"tag": "ingredient",
	"description": "Fragrant herbs harvested from the garden, perfect for hot tea."
}

# Delayed task state
var gathering_task_active: bool = false
var gathering_turns_remaining: int = 0

func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	_setup_initial_state()

func log_message(text: String) -> void:
	if log_label:
		log_label.append_text("[Turn " + str(current_turn) + "] " + text + "\n")

func _setup_initial_state() -> void:
	current_turn = 1
	current_stage = "A"
	inventory_cards.clear()

	# Add initial inventory cards for Stage A
	add_card_to_inventory(wizard_card_def.duplicate())
	add_card_to_inventory(magical_material_def.duplicate())

	log_message("Welcome, Wizard! Scenario Started. [Stage A: The Talisman]")
	log_message("Goal: Select or drag your Wizard card and Magical Essence into the event slots to craft a Talisman.")

	_update_ui()
	_spawn_stage_a_event()

func add_card_to_inventory(card_data: Dictionary) -> void:
	inventory_cards.append(card_data)
	_refresh_inventory_ui()

func remove_card_from_inventory(card_data: Dictionary) -> bool:
	for i in range(inventory_cards.size()):
		if inventory_cards[i].get("id") == card_data.get("id"):
			inventory_cards.remove_at(i)
			if selected_card_data == card_data:
				_deselect_card()
			_refresh_inventory_ui()
			return true
	return false

func _deselect_card() -> void:
	selected_card_data = {}
	if selected_card_ui != null and is_instance_valid(selected_card_ui):
		selected_card_ui.set_selected(false)
		selected_card_ui = null

func _refresh_inventory_ui() -> void:
	for child in inventory_container.get_children():
		child.queue_free()

	for card_data in inventory_cards:
		var card_inst = card_ui_scene.instantiate()
		inventory_container.add_child(card_inst)
		card_inst.setup(card_data, false)
		card_inst.card_selected.connect(_on_inventory_card_selected)

func _on_inventory_card_selected(card_ui) -> void:
	if selected_card_ui == card_ui:
		_deselect_card()
	else:
		if selected_card_ui != null and is_instance_valid(selected_card_ui):
			selected_card_ui.set_selected(false)
		selected_card_ui = card_ui
		selected_card_data = card_ui.card_data
		selected_card_ui.set_selected(true)

func _update_ui() -> void:
	turn_label.text = "Turn: " + str(current_turn)
	stage_label.text = "Stage: " + current_stage
	wizard_title_label.text = "Wizard: Elian"
	wizard_desc_label.text = "Status: Active Guardian\nInventory Count: " + str(inventory_cards.size())

# Event Spawners
func _spawn_stage_a_event() -> void:
	_clear_events()

	var event_def = {
		"id": "craft_talisman",
		"title": "Stage A: Craft a Talisman",
		"description": "Slot your Wizard card and Magical Essence to craft a magical Talisman for the village.",
		"deadline": -1,
		"slots": [
			{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
			{"id": "material_slot", "label": "Material", "req_tag": "ingredient"}
		],
		"actions": [
			{"id": "resolve_craft_talisman", "label": "Craft Talisman", "required_slots": ["wizard_slot", "material_slot"]}
		]
	}
	_add_event(event_def)

func _spawn_stage_b_event() -> void:
	current_stage = "B"
	log_message("\n--- [Stage B: The Tea] ---")
	log_message("Tea Leaves have been discovered! Prepare tea using your Wizard and Tea Leaves.")

	# Add Tea Leaves to inventory
	add_card_to_inventory(tea_leaves_def.duplicate())

	_clear_events()
	var event_def = {
		"id": "prepare_tea",
		"title": "Stage B: Prepare Tea",
		"description": "Combine the Wizard card and Tea Leaves to brew a fresh pot of Tea.",
		"deadline": -1,
		"slots": [
			{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
			{"id": "tea_slot", "label": "Tea Leaves", "req_tag": "ingredient"}
		],
		"actions": [
			{"id": "resolve_prepare_tea", "label": "Brew Tea", "required_slots": ["wizard_slot", "tea_slot"]}
		]
	}
	_add_event(event_def)

func _spawn_stage_c_event() -> void:
	current_stage = "C"
	log_message("\n--- [Stage C: The Missing Herb] ---")
	log_message("A villager is sick and needs a Herbal Poultice! However, you lack Herbs.")
	log_message("Start a Gathering Task (requires 2 turns) to obtain Herbs.")

	_clear_events()

	var gather_event_def = {
		"id": "gather_herbs",
		"title": "Stage C: Gather Herbs (Task)",
		"description": "Send someone or use time to gather wild medicinal herbs in the forest. Takes 2 turns once started.",
		"deadline": -1,
		"slots": [
			{"id": "wizard_slot", "label": "Wizard (Optional)", "req_tag": "wizard"}
		],
		"actions": [
			{"id": "start_gathering", "label": "Start Gathering Herbs (2 Turns)", "required_slots": []}
		]
	}
	_add_event(gather_event_def)

func _spawn_stage_c_poultice_event() -> void:
	log_message("Herbs gathered! Now craft the Poultice using Wizard and Herb.")
	_clear_events()

	var poultice_event_def = {
		"id": "craft_poultice",
		"title": "Stage C: Prepare Herbal Poultice",
		"description": "Combine the Wizard and Herbs to make a Poultice and heal the village ailment.",
		"deadline": -1,
		"slots": [
			{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
			{"id": "herb_slot", "label": "Medicinal Herb", "req_tag": "herb"}
		],
		"actions": [
			{"id": "resolve_poultice", "label": "Craft & Apply Poultice", "required_slots": ["wizard_slot", "herb_slot"]}
		]
	}
	_add_event(poultice_event_def)

func _spawn_stage_d_events() -> void:
	current_stage = "D"
	log_message("\n--- [Stage D: Competing Obligations] ---")
	log_message("CRITICAL DECISION: Two urgent events have appeared, both requiring Tea!")
	log_message("Both events have a deadline of 0 turns! You only have enough Tea for ONE. Committing to one means losing the other.")

	_clear_events()

	var guest_event_def = {
		"id": "unexpected_guest",
		"title": "Stage D: Unexpected Guest",
		"description": "A travelling noble scholar arrives at your door needing refreshment. Offer Tea to gain Village Favor.",
		"deadline": 0,
		"slots": [
			{"id": "tea_slot", "label": "Fresh Tea", "req_tag": "tea"}
		],
		"actions": [
			{"id": "welcome_guest", "label": "Serve Tea to Guest", "required_slots": ["tea_slot"]}
		]
	}

	var spirit_event_def = {
		"id": "spirit_opportunity",
		"title": "Stage D: Spirit Ritual",
		"description": "Forest spirits request a tea offering under the full moon. Offer Tea to gain Arcane Lore.",
		"deadline": 0,
		"slots": [
			{"id": "tea_slot", "label": "Fresh Tea", "req_tag": "tea"}
		],
		"actions": [
			{"id": "commune_spirits", "label": "Offer Tea to Spirits", "required_slots": ["tea_slot"]}
		]
	}

	_add_event(guest_event_def)
	_add_event(spirit_event_def)

func _clear_events() -> void:
	for child in events_container.get_children():
		child.queue_free()

func _add_event(event_def: Dictionary) -> void:
	var event_inst = event_ui_scene.instantiate()
	events_container.add_child(event_inst)
	event_inst.setup(event_def)
	event_inst.action_triggered.connect(_on_event_action_triggered)
	event_inst.slot_clicked.connect(_on_event_slot_clicked)

func _on_event_slot_clicked(_event_ui, slot_ui) -> void:
	if not selected_card_data.is_empty():
		if slot_ui.slotted_card_data.is_empty():
			if slot_ui.slot_card(selected_card_data):
				log_message("Slotted card '" + selected_card_data.get("title", "") + "' into " + slot_ui.slot_label_text)
				_deselect_card()
		else:
			log_message("Slot is already occupied.")
	elif not slot_ui.slotted_card_data.is_empty():
		var removed = slot_ui.clear_slot()
		log_message("Removed card '" + removed.get("title", "") + "' from " + slot_ui.slot_label_text)

func _on_event_action_triggered(event_ui, action_id: String) -> void:
	var slotted = event_ui.get_slotted_cards()

	if action_id == "resolve_craft_talisman":
		var wizard_card = slotted.get("wizard_slot", {})
		var material_card = slotted.get("material_slot", {})

		remove_card_from_inventory(material_card)
		event_ui.clear_all_slots()

		var talisman_card = {
			"id": "talisman",
			"title": "Protective Talisman",
			"tag": "talisman",
			"description": "A glowing ward crafted by the Hedge Wizard to protect the village."
		}
		add_card_to_inventory(talisman_card)
		log_message("Action Resolved: Crafted a Protective Talisman! (Magical Essence consumed, Talisman added to inventory).")

		_spawn_stage_b_event()

	elif action_id == "resolve_prepare_tea":
		var tea_leaves_card = slotted.get("tea_slot", {})
		remove_card_from_inventory(tea_leaves_card)

		event_ui.clear_all_slots()

		var tea_card = {
			"id": "tea",
			"title": "Pot of Hot Tea",
			"tag": "tea",
			"description": "Freshly brewed warm tea. Refreshing and deeply comforting."
		}
		add_card_to_inventory(tea_card)
		log_message("Action Resolved: Prepared Pot of Hot Tea! (Tea Leaves consumed, Hot Tea added to inventory).")

		_spawn_stage_c_event()

	elif action_id == "start_gathering":
		event_ui.clear_all_slots()
		gathering_task_active = true
		gathering_turns_remaining = 2
		log_message("Action Started: Gathering Herbs task initiated! Requires 2 turns to complete. Press End Turn to advance time.")
		_clear_events()

	elif action_id == "resolve_poultice":
		var herb_card = slotted.get("herb_slot", {})
		remove_card_from_inventory(herb_card)

		event_ui.clear_all_slots()

		var poultice_card = {
			"id": "poultice",
			"title": "Herbal Poultice",
			"tag": "remedy",
			"description": "A healing salve that cures village ailments."
		}
		add_card_to_inventory(poultice_card)
		log_message("Action Resolved: Herbal Poultice prepared and applied! Village ailment cured.")

		_spawn_stage_d_events()

	elif action_id == "welcome_guest":
		var tea_card = slotted.get("tea_slot", {})
		remove_card_from_inventory(tea_card)

		event_ui.clear_all_slots()

		log_message("CHOSEN OBLIGATION: Welcomed the Unexpected Guest with Tea!")
		log_message("Consequence: Received 'Village Favor' reward! The Spirit opportunity expired.")

		var favor_card = {
			"id": "village_favor",
			"title": "Village Favor",
			"tag": "boon",
			"description": "The gratitude of a wealthy guest and local villagers."
		}
		add_card_to_inventory(favor_card)

		current_stage = "COMPLETE"
		_clear_events()
		log_message("\n=== PROTOTYPE SCENARIO COMPLETE ===")

	elif action_id == "commune_spirits":
		var tea_card = slotted.get("tea_slot", {})
		remove_card_from_inventory(tea_card)

		event_ui.clear_all_slots()

		log_message("CHOSEN OBLIGATION: Communed with Forest Spirits using Tea!")
		log_message("Consequence: Received 'Arcane Lore' reward! The Unexpected Guest left disappointed.")

		var lore_card = {
			"id": "arcane_lore",
			"title": "Arcane Lore",
			"tag": "knowledge",
			"description": "Secrets of the ancient forest granted by the spirits."
		}
		add_card_to_inventory(lore_card)

		current_stage = "COMPLETE"
		_clear_events()
		log_message("\n=== PROTOTYPE SCENARIO COMPLETE ===")

	_update_ui()

func _on_end_turn_pressed() -> void:
	current_turn += 1
	log_message("\nAdvanced to Turn " + str(current_turn) + ".")

	# Handle gathering delayed task
	if gathering_task_active:
		gathering_turns_remaining -= 1
		if gathering_turns_remaining <= 0:
			gathering_task_active = false
			log_message("Task Completed: Gathering Herbs complete!")
			var herb_card = {
				"id": "medicinal_herb",
				"title": "Medicinal Herb",
				"tag": "herb",
				"description": "A rare healing plant harvested from the deep woods."
			}
			add_card_to_inventory(herb_card)
			_spawn_stage_c_poultice_event()
		else:
			log_message("Task Progress: Gathering Herbs in progress... (" + str(gathering_turns_remaining) + " turn(s) remaining).")

	# Update active event deadlines & handle expired events
	var events_to_remove = []
	for event_inst in events_container.get_children():
		if event_inst.deadline_turns >= 0:
			event_inst.deadline_turns -= 1
			if event_inst.deadline_turns < 0:
				events_to_remove.append(event_inst)
				log_message("Event Expired: '" + event_inst.event_data.get("title", "Event") + "' deadline passed!")
			else:
				event_inst.update_ui()

	for exp_event in events_to_remove:
		exp_event.queue_free()

	_update_ui()
