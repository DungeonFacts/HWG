extends Control

var current_turn: int = 1
var current_stage: String = "Active"
var active_experiment: int = 1 # 1, 2, 3, or 0 (Legacy)

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
@onready var exp_selector: OptionButton = $VBox/TopBar/ExpSelector
@onready var exp_title_label: Label = $VBox/ExpInfoPanel/MarginContainer/VBox/ExpTitleLabel
@onready var exp_desc_label: Label = $VBox/ExpInfoPanel/MarginContainer/VBox/ExpDescLabel

@onready var wizard_title_label: Label = $VBox/MainSplit/LeftPanel/WizardStatusBox/VBox/WizardTitleLabel
@onready var wizard_desc_label: Label = $VBox/MainSplit/LeftPanel/WizardStatusBox/VBox/WizardDescLabel
@onready var inventory_container: HFlowContainer = $VBox/MainSplit/LeftPanel/InventoryScroll/InventoryContainer

@onready var events_container: VBoxContainer = $VBox/MainSplit/RightPanel/EventsScroll/EventsContainer
@onready var log_label: RichTextLabel = $VBox/LogPanel/LogMargin/LogLabel

# Base Card Definitions
var wizard_card_def = {
	"id": "wizard",
	"title": "Hedge Wizard",
	"tag": "wizard",
	"description": "The protector of the village. Knowledgeable in simple craft and rituals."
}

# State Trackers
# Experiment 1 State
var exp1_yew_committed: bool = false

# Experiment 2 State
var exp2_wand_progress: int = 0 # 0, 1, 2, 3 (Completed)
var exp2_blight_stage: int = 1 # 1 (Mild), 2 (Severe), 3 (Famine)
var exp2_blight_resolved: bool = false
var exp2_blacksmith_stage: int = 1 # 1 (Help Request), 2 (Grievance)
var exp2_blacksmith_resolved: bool = false
var exp2_merchant_stage: int = 1 # 1 (Sun-Gem), 2 (Leftovers)
var exp2_merchant_resolved: bool = false

# Experiment 3 State
var exp3_wood_acquired: bool = false
var exp3_chosen_path: String = "" # "patient", "spirit", "forester", "dark"
var exp3_patient_progress: int = 0

# Legacy State
var gathering_task_active: bool = false
var gathering_turns_remaining: int = 0

func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	_setup_exp_selector()
	switch_experiment(1)

func log_message(text: String) -> void:
	if log_label:
		log_label.append_text("[Turn " + str(current_turn) + "] " + text + "\n")

func _setup_exp_selector() -> void:
	exp_selector.clear()
	exp_selector.add_item("Exp 1: Scarcity & Competing Uses", 1)
	exp_selector.add_item("Exp 2: Neglect & Evolving World", 2)
	exp_selector.add_item("Exp 3: Multiple Paths to Power", 3)
	exp_selector.add_item("Legacy Prototype Loop", 0)

	exp_selector.item_selected.connect(func(idx):
		var id = exp_selector.get_item_id(idx)
		switch_experiment(id)
	)

func switch_experiment(exp_id: int) -> void:
	active_experiment = exp_id
	current_turn = 1
	current_stage = "Active"
	inventory_cards.clear()
	_deselect_card()
	_clear_events()
	if log_label:
		log_label.clear()

	match exp_id:
		1:
			_setup_experiment_1()
		2:
			_setup_experiment_2()
		3:
			_setup_experiment_3()
		0:
			_setup_legacy_scenario()

	_update_ui()

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

# ==============================================================================
# EXPERIMENT 1: SCARCITY AND COMPETING USES
# ==============================================================================
func _setup_experiment_1() -> void:
	exp1_yew_committed = false
	exp_title_label.text = "Experiment 1: Scarcity and Competing Uses"
	exp_desc_label.text = "HYPOTHESIS: Severe resource scarcity with multiple competing uses creates strategic tension without countdown timers.\nPROBLEM: You have ONE Yew Heartwood. Three critical ambitions demand it."

	log_message("=== EXPERIMENT 1 INITIALIZED ===")
	log_message("You possess 1 Yew Heartwood, 1 Silver Shilling, 1 Herbal Infusion, and 1 Ancient Scroll.")
	log_message("Decide how to allocate your scarce Yew Heartwood!")

	add_card_to_inventory(wizard_card_def.duplicate())
	add_card_to_inventory({
		"id": "yew_heartwood",
		"title": "Yew Heartwood",
		"tag": "yew_heartwood",
		"description": "A dense piece of rare magical wood. Irreplaceable and coveted."
	})
	add_card_to_inventory({
		"id": "silver_shilling",
		"title": "Silver Shilling",
		"tag": "currency",
		"description": "Hard coin earned from village trade."
	})
	add_card_to_inventory({
		"id": "herbal_infusion",
		"title": "Herbal Infusion",
		"tag": "herb",
		"description": "Potent medicinal brew made from sage."
	})
	add_card_to_inventory({
		"id": "ancient_scroll",
		"title": "Ancient Scroll",
		"tag": "scroll",
		"description": "A scroll containing arcane runes."
	})

	_spawn_exp1_events()

func _spawn_exp1_events() -> void:
	_clear_events()

	_add_event({
		"id": "exp1_wand_event",
		"title": "Ambition 1: Craft Yew-Heart Wand",
		"description": "Craft a legendary wand that permanently unlocks advanced elemental magic.",
		"deadline": -1,
		"slots": [
			{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
			{"id": "wood_slot", "label": "Yew Heartwood", "req_tag": "yew_heartwood"}
		],
		"actions": [
			{"id": "exp1_craft_wand", "label": "Craft Yew Wand", "required_slots": ["wizard_slot", "wood_slot"]}
		]
	})

	_add_event({
		"id": "exp1_provisions_event",
		"title": "Ambition 2: Secure Winter Provisions",
		"description": "Merchant offers food for winter. Trade Yew Heartwood for Abundant Provisions, or buy Emergency Rations with Silver + Herb.",
		"deadline": -1,
		"slots": [
			{"id": "yew_slot", "label": "Yew Heartwood (Option A)", "req_tag": "yew_heartwood"},
			{"id": "silver_slot", "label": "Silver (Option B)", "req_tag": "currency"},
			{"id": "herb_slot", "label": "Herb (Option B)", "req_tag": "herb"}
		],
		"actions": [
			{"id": "exp1_trade_yew_provisions", "label": "Trade Yew Wood (Abundant Food)", "required_slots": ["yew_slot"]},
			{"id": "exp1_buy_basic_provisions", "label": "Buy Basic Rations (Silver + Herb)", "required_slots": ["silver_slot", "herb_slot"]}
		]
	})

	_add_event({
		"id": "exp1_spirit_event",
		"title": "Ambition 3: Heart-Oak Spirit Shrine",
		"description": "Spirit demands an offering. Present Yew Heartwood for Heart-Oak's Favor, or Ancient Scroll for a Lesser Blessing.",
		"deadline": -1,
		"slots": [
			{"id": "yew_slot", "label": "Yew Heartwood (Option A)", "req_tag": "yew_heartwood"},
			{"id": "scroll_slot", "label": "Scroll (Option B)", "req_tag": "scroll"}
		],
		"actions": [
			{"id": "exp1_spirit_yew", "label": "Offer Yew Heartwood (Heart-Oak Favor)", "required_slots": ["yew_slot"]},
			{"id": "exp1_spirit_scroll", "label": "Offer Ancient Scroll (Lesser Blessing)", "required_slots": ["scroll_slot"]}
		]
	})

	_add_event({
		"id": "exp1_crisis_event",
		"title": "Consequence: Valley Shadow Storm",
		"description": "A dark shadow storm threatens the valley! Resolve with your crafted Yew Wand, Abundant Provisions, OR Heart-Oak Favor.",
		"deadline": -1,
		"slots": [
			{"id": "boon_slot", "label": "Wand / Food / Favor", "req_tag": "any"}
		],
		"actions": [
			{"id": "exp1_resolve_crisis", "label": "Ward Valley & Conclude Experiment", "required_slots": ["boon_slot"]}
		]
	})

# ==============================================================================
# EXPERIMENT 2: NEGLECT AND AN EVOLVING WORLD
# ==============================================================================
func _setup_experiment_2() -> void:
	exp2_wand_progress = 0
	exp2_blight_stage = 1
	exp2_blight_resolved = false
	exp2_blacksmith_stage = 1
	exp2_blacksmith_resolved = false
	exp2_merchant_stage = 1
	exp2_merchant_resolved = false

	exp_title_label.text = "Experiment 2: Neglect and an Evolving World"
	exp_desc_label.text = "HYPOTHESIS: Graduated consequences of neglect generate organic pressure.\nPROBLEM: Crafting your Yew Wand takes 3 turns of focus. World problems escalate while you work!"

	log_message("=== EXPERIMENT 2 INITIALIZED ===")
	log_message("Goal: Complete 3 turns of work to craft the Yew Wand while managing escalating world events.")

	add_card_to_inventory(wizard_card_def.duplicate())
	add_card_to_inventory({
		"id": "medicinal_herb",
		"title": "Medicinal Herb",
		"tag": "herb",
		"description": "Healing plant used to cleanse blight."
	})
	add_card_to_inventory({
		"id": "silver_shilling",
		"title": "Silver Shilling",
		"tag": "currency",
		"description": "Hard coin earned from village trade."
	})
	add_card_to_inventory({
		"id": "wand_project",
		"title": "Yew Wand Work (0/3)",
		"tag": "project",
		"description": "Long-term crafting project in progress."
	})

	_refresh_exp2_events()

func _refresh_exp2_events() -> void:
	_clear_events()

	if exp2_wand_progress < 3:
		_add_event({
			"id": "exp2_wand_event",
			"title": "Long-Term Ambition: Craft Yew Wand (" + str(exp2_wand_progress) + "/3)",
			"description": "Slot your Wizard to spend a turn shaping and enchanting the Yew Heartwood wand.",
			"deadline": -1,
			"slots": [
				{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"}
			],
			"actions": [
				{"id": "exp2_work_wand", "label": "Work on Wand (1 Turn)", "required_slots": ["wizard_slot"]}
			]
		})
	else:
		_add_event({
			"id": "exp2_conclude_event",
			"title": "Project Complete: Yew Wand Crafted!",
			"description": "You completed the Yew-Heart Wand! Review the state of the village and conclude.",
			"deadline": -1,
			"slots": [
				{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"}
			],
			"actions": [
				{"id": "exp2_conclude", "label": "Conclude Experiment 2", "required_slots": ["wizard_slot"]}
			]
		})

	if not exp2_blight_resolved:
		if exp2_blight_stage == 1:
			_add_event({
				"id": "exp2_blight_event",
				"title": "[World] Mild Crop Blight",
				"description": "A faint fungus touches the village crops. Costs 1 Medicinal Herb to cure before it spreads.",
				"deadline": -1,
				"slots": [
					{"id": "herb_slot", "label": "Medicinal Herb", "req_tag": "herb"}
				],
				"actions": [
					{"id": "exp2_cure_blight_mild", "label": "Cure Mild Blight (1 Herb)", "required_slots": ["herb_slot"]}
				]
			})
		elif exp2_blight_stage == 2:
			_add_event({
				"id": "exp2_blight_event",
				"title": "[World] SEVERE Crop Blight Spread!",
				"description": "NEGLECT CONSEQUENCE: Blight has spread! Requires 1 Herb + Wizard's personal ritual to cleanse.",
				"deadline": -1,
				"slots": [
					{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
					{"id": "herb_slot", "label": "Medicinal Herb", "req_tag": "herb"}
				],
				"actions": [
					{"id": "exp2_cure_blight_severe", "label": "Perform Cleanse Ritual (Wizard + Herb)", "required_slots": ["wizard_slot", "herb_slot"]}
				]
			})
		elif exp2_blight_stage >= 3:
			_add_event({
				"id": "exp2_blight_event",
				"title": "[World] Famine & Crop Rot!",
				"description": "SEVERE NEGLECT CONSEQUENCE: Crops ruined! Villagers are starving and resentful.",
				"deadline": -1,
				"slots": [],
				"actions": []
			})

	if not exp2_blacksmith_resolved:
		if exp2_blacksmith_stage == 1:
			_add_event({
				"id": "exp2_smith_event",
				"title": "[Petitioner] Blacksmith's Anomaly",
				"description": "Blacksmith seeks your wizardry to fix a strange glowing heat in his forge.",
				"deadline": -1,
				"slots": [
					{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"}
				],
				"actions": [
					{"id": "exp2_fix_smith", "label": "Assist Blacksmith (Slot Wizard)", "required_slots": ["wizard_slot"]}
				]
			})
		else:
			_add_event({
				"id": "exp2_smith_event",
				"title": "[Petitioner] Blacksmith's Resentment!",
				"description": "NEGLECT CONSEQUENCE: You ignored the Blacksmith. He damaged his forge and holds a grievance against you.",
				"deadline": -1,
				"slots": [
					{"id": "silver_slot", "label": "Silver Shilling", "req_tag": "currency"}
				],
				"actions": [
					{"id": "exp2_repair_smith", "label": "Pay Damages (1 Silver)", "required_slots": ["silver_slot"]}
				]
			})

	if not exp2_merchant_resolved:
		if exp2_merchant_stage == 1:
			_add_event({
				"id": "exp2_merchant_event",
				"title": "[Opportunity] Wandering Merchant: Rare Sun-Gem",
				"description": "Merchant offers a magnificent Sun-Gem for 1 Silver Shilling. Available this turn!",
				"deadline": -1,
				"slots": [
					{"id": "silver_slot", "label": "Silver Shilling", "req_tag": "currency"}
				],
				"actions": [
					{"id": "exp2_buy_sungem", "label": "Buy Sun-Gem (1 Silver)", "required_slots": ["silver_slot"]}
				]
			})
		else:
			_add_event({
				"id": "exp2_merchant_event",
				"title": "[Opportunity] Merchant's Leftovers",
				"description": "SHIFTING OPPORTUNITY: The Sun-Gem was bought by a rival! Merchant now sells Scrap Metal for 1 Silver.",
				"deadline": -1,
				"slots": [
					{"id": "silver_slot", "label": "Silver Shilling", "req_tag": "currency"}
				],
				"actions": [
					{"id": "exp2_buy_scrap", "label": "Buy Scrap Metal (1 Silver)", "required_slots": ["silver_slot"]}
				]
			})

# ==============================================================================
# EXPERIMENT 3: MULTIPLE PATHS TO POWER
# ==============================================================================
func _setup_experiment_3() -> void:
	exp3_wood_acquired = false
	exp3_chosen_path = ""
	exp3_patient_progress = 0

	exp_title_label.text = "Experiment 3: Multiple Paths to Power"
	exp_desc_label.text = "HYPOTHESIS: The method chosen to acquire power defines the wizard's identity.\nGOAL: Acquire Yew Heartwood through 1 of 4 distinct paths to face the Archmage Trial."

	log_message("=== EXPERIMENT 3 INITIALIZED ===")
	log_message("Choose how to acquire Yew Heartwood: Patient Forestry, Spirit Bargain, Forester Hire, or Dark Ritual.")

	add_card_to_inventory(wizard_card_def.duplicate())
	add_card_to_inventory({
		"id": "herbal_offering",
		"title": "Herbal Offering",
		"tag": "offering",
		"description": "Sacred offering herbs for nature spirits."
	})
	add_card_to_inventory({
		"id": "silver_shilling",
		"title": "Silver Shilling",
		"tag": "currency",
		"description": "Hard coin earned from village trade."
	})
	add_card_to_inventory({
		"id": "ancient_grimoire",
		"title": "Forbidden Grimoire",
		"tag": "grimoire",
		"description": "Tome of forbidden blood and corruption magic."
	})

	_refresh_exp3_events()

func _refresh_exp3_events() -> void:
	_clear_events()

	if not exp3_wood_acquired:
		# Path 1: Patient Forestry (3 turns)
		_add_event({
			"id": "exp3_path_patient",
			"title": "Path 1: Patient Stewardship (" + str(exp3_patient_progress) + "/3)",
			"description": "Patiently nurture and harvest sacred yew. Takes 3 turns. Pure, risk-free, pure harmony.",
			"deadline": -1,
			"slots": [
				{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"}
			],
			"actions": [
				{"id": "exp3_work_patient", "label": "Gather Patiently (1 Turn)", "required_slots": ["wizard_slot"]}
			]
		})

		# Path 2: Spirit Bargain (1 turn)
		_add_event({
			"id": "exp3_path_spirit",
			"title": "Path 2: Bargain with Sylph Spirit",
			"description": "Offer sacred herbs to Sylph Spirit. Immediate Yew Wood, but imposes a Spirit Taboo constraint.",
			"deadline": -1,
			"slots": [
				{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
				{"id": "offering_slot", "label": "Herbal Offering", "req_tag": "offering"}
			],
			"actions": [
				{"id": "exp3_choose_spirit", "label": "Seal Spirit Pact", "required_slots": ["wizard_slot", "offering_slot"]}
			]
		})

		# Path 3: Hire Local Forester (1 turn)
		_add_event({
			"id": "exp3_path_forester",
			"title": "Path 3: Hire Local Forester",
			"description": "Pay Silver to have a woodsman fell the tree. Fast acquisition, but leaves a Forester's Debt.",
			"deadline": -1,
			"slots": [
				{"id": "silver_slot", "label": "Silver Shilling", "req_tag": "currency"}
			],
			"actions": [
				{"id": "exp3_choose_forester", "label": "Hire Forester", "required_slots": ["silver_slot"]}
			]
		})

		# Path 4: Dark Blight Ritual (0 turns - Instant)
		_add_event({
			"id": "exp3_path_dark",
			"title": "Path 4: Forbidden Blight Ritual",
			"description": "Use Forbidden Grimoire to strip life force from the land. INSTANT wood, but corrupts the soil.",
			"deadline": -1,
			"slots": [
				{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
				{"id": "grimoire_slot", "label": "Forbidden Grimoire", "req_tag": "grimoire"}
			],
			"actions": [
				{"id": "exp3_choose_dark", "label": "Perform Dark Ritual (Instant)", "required_slots": ["wizard_slot", "grimoire_slot"]}
			]
		})
	else:
		# Concluding Archmage Trial
		_add_event({
			"id": "exp3_trial_event",
			"title": "Concluding Trial: The Archmage Test",
			"description": "Slot your Wizard and Yew Heartwood to face the Archmage Trial. Outcome will evaluate your path's consequences!",
			"deadline": -1,
			"slots": [
				{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
				{"id": "wood_slot", "label": "Yew Heartwood", "req_tag": "yew_heartwood"}
			],
			"actions": [
				{"id": "exp3_resolve_trial", "label": "Face Archmage Trial & Conclude", "required_slots": ["wizard_slot", "wood_slot"]}
			]
		})

# ==============================================================================
# LEGACY PROTOTYPE SCENARIO
# ==============================================================================
func _setup_legacy_scenario() -> void:
	exp_title_label.text = "Legacy Prototype Scenario"
	exp_desc_label.text = "Original sequential prototype loop (Stages A through D)."
	log_message("=== LEGACY PROTOTYPE SCENARIO INITIALIZED ===")

	current_stage = "A"
	add_card_to_inventory(wizard_card_def.duplicate())
	add_card_to_inventory({
		"id": "magical_material",
		"title": "Magical Essence",
		"tag": "ingredient",
		"description": "A pinch of shimmering dust used for crafting magical talismans."
	})
	_spawn_legacy_stage_a()

func _spawn_legacy_stage_a() -> void:
	_clear_events()
	_add_event({
		"id": "craft_talisman",
		"title": "Stage A: Craft a Talisman",
		"description": "Slot Wizard and Magical Essence to craft a Protective Talisman.",
		"deadline": -1,
		"slots": [
			{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
			{"id": "material_slot", "label": "Material", "req_tag": "ingredient"}
		],
		"actions": [
			{"id": "resolve_craft_talisman", "label": "Craft Talisman", "required_slots": ["wizard_slot", "material_slot"]}
		]
	})

func _spawn_legacy_stage_b() -> void:
	current_stage = "B"
	add_card_to_inventory({
		"id": "tea_leaves",
		"title": "Tea Leaves",
		"tag": "ingredient",
		"description": "Fragrant tea leaves."
	})
	_clear_events()
	_add_event({
		"id": "prepare_tea",
		"title": "Stage B: Prepare Tea",
		"description": "Combine Wizard and Tea Leaves to brew Hot Tea.",
		"deadline": -1,
		"slots": [
			{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
			{"id": "tea_slot", "label": "Tea Leaves", "req_tag": "ingredient"}
		],
		"actions": [
			{"id": "resolve_prepare_tea", "label": "Brew Tea", "required_slots": ["wizard_slot", "tea_slot"]}
		]
	})

func _spawn_legacy_stage_c() -> void:
	current_stage = "C"
	_clear_events()
	_add_event({
		"id": "gather_herbs",
		"title": "Stage C: Gather Herbs (Task)",
		"description": "Gather medicinal herbs in the forest (Takes 2 turns).",
		"deadline": -1,
		"slots": [],
		"actions": [
			{"id": "start_gathering", "label": "Start Gathering Herbs (2 Turns)", "required_slots": []}
		]
	})

func _spawn_legacy_stage_c_poultice() -> void:
	_clear_events()
	_add_event({
		"id": "craft_poultice",
		"title": "Stage C: Prepare Herbal Poultice",
		"description": "Combine Wizard and Herb to make a healing Poultice.",
		"deadline": -1,
		"slots": [
			{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
			{"id": "herb_slot", "label": "Medicinal Herb", "req_tag": "herb"}
		],
		"actions": [
			{"id": "resolve_poultice", "label": "Craft & Apply Poultice", "required_slots": ["wizard_slot", "herb_slot"]}
		]
	})

func _spawn_legacy_stage_d() -> void:
	current_stage = "D"
	_clear_events()
	_add_event({
		"id": "unexpected_guest",
		"title": "Stage D: Unexpected Guest",
		"description": "Offer Tea to guest for Village Favor.",
		"deadline": 0,
		"slots": [{"id": "tea_slot", "label": "Fresh Tea", "req_tag": "tea"}],
		"actions": [{"id": "welcome_guest", "label": "Serve Tea to Guest", "required_slots": ["tea_slot"]}]
	})
	_add_event({
		"id": "spirit_opportunity",
		"title": "Stage D: Spirit Ritual",
		"description": "Offer Tea to spirits for Arcane Lore.",
		"deadline": 0,
		"slots": [{"id": "tea_slot", "label": "Fresh Tea", "req_tag": "tea"}],
		"actions": [{"id": "commune_spirits", "label": "Offer Tea to Spirits", "required_slots": ["tea_slot"]}]
	})

# General Event Router
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

	# --- EXPERIMENT 1 ACTIONS ---
	if action_id == "exp1_craft_wand":
		var yew_card = slotted.get("wood_slot", {})
		remove_card_from_inventory(yew_card)
		event_ui.clear_all_slots()
		add_card_to_inventory({"id": "yew_wand", "title": "Yew-Heart Wand", "tag": "wand", "description": "A majestic wand of yew heartwood."})
		exp1_yew_committed = true
		log_message("RESOURCE SACRIFICE: Crafted Yew-Heart Wand! The Yew Heartwood is now spent.")

	elif action_id == "exp1_trade_yew_provisions":
		var yew_card = slotted.get("yew_slot", {})
		remove_card_from_inventory(yew_card)
		event_ui.clear_all_slots()
		add_card_to_inventory({"id": "abundant_provisions", "title": "Abundant Provisions", "tag": "provisions", "description": "Massive winter stockpiles."})
		exp1_yew_committed = true
		log_message("RESOURCE SACRIFICE: Traded Yew Heartwood for Abundant Provisions!")

	elif action_id == "exp1_buy_basic_provisions":
		remove_card_from_inventory(slotted.get("silver_slot", {}))
		remove_card_from_inventory(slotted.get("herb_slot", {}))
		event_ui.clear_all_slots()
		add_card_to_inventory({"id": "basic_provisions", "title": "Basic Rations", "tag": "provisions", "description": "Minimal winter rations."})
		log_message("COMPROMISE: Bought Basic Rations with Silver + Herb!")

	elif action_id == "exp1_spirit_yew":
		remove_card_from_inventory(slotted.get("yew_slot", {}))
		event_ui.clear_all_slots()
		add_card_to_inventory({"id": "heart_oak_favor", "title": "Heart-Oak's Favor", "tag": "spirit_favor", "description": "Divine blessing from Ancient Spirit."})
		exp1_yew_committed = true
		log_message("RESOURCE SACRIFICE: Offered Yew Heartwood to the Heart-Oak Spirit!")

	elif action_id == "exp1_spirit_scroll":
		remove_card_from_inventory(slotted.get("scroll_slot", {}))
		event_ui.clear_all_slots()
		add_card_to_inventory({"id": "lesser_blessing", "title": "Lesser Forest Blessing", "tag": "spirit_favor", "description": "Modest spirit blessing."})
		log_message("COMPROMISE: Offered Ancient Scroll to Spirit!")

	elif action_id == "exp1_resolve_crisis":
		remove_card_from_inventory(slotted.get("boon_slot", {}))
		event_ui.clear_all_slots()
		_clear_events()
		current_stage = "COMPLETE"
		log_message("\n=== EXPERIMENT 1 COMPLETED ===")

	# --- EXPERIMENT 2 ACTIONS ---
	elif action_id == "exp2_work_wand":
		event_ui.clear_all_slots()
		exp2_wand_progress += 1
		log_message("LONG-TERM PROJECT: Worked on Yew Wand! Progress: (" + str(exp2_wand_progress) + "/3).")
		for i in range(inventory_cards.size()):
			if inventory_cards[i].get("id") == "wand_project":
				if exp2_wand_progress < 3:
					inventory_cards[i]["title"] = "Yew Wand Work (" + str(exp2_wand_progress) + "/3)"
				else:
					inventory_cards[i] = {"id": "completed_yew_wand", "title": "Completed Yew Wand", "tag": "wand", "description": "A masterpiece wand."}
				break
		_refresh_inventory_ui()
		_refresh_exp2_events()

	elif action_id == "exp2_cure_blight_mild":
		remove_card_from_inventory(slotted.get("herb_slot", {}))
		event_ui.clear_all_slots()
		exp2_blight_resolved = true
		log_message("WORLD RESPONSE: Cured Mild Crop Blight!")
		_refresh_exp2_events()

	elif action_id == "exp2_cure_blight_severe":
		remove_card_from_inventory(slotted.get("herb_slot", {}))
		event_ui.clear_all_slots()
		exp2_blight_resolved = true
		log_message("WORLD RESPONSE: Cleanse Ritual performed on Severe Blight!")
		_refresh_exp2_events()

	elif action_id == "exp2_fix_smith":
		event_ui.clear_all_slots()
		exp2_blacksmith_resolved = true
		log_message("WORLD RESPONSE: Assisted Blacksmith with forge anomaly!")
		_refresh_exp2_events()

	elif action_id == "exp2_repair_smith":
		remove_card_from_inventory(slotted.get("silver_slot", {}))
		event_ui.clear_all_slots()
		exp2_blacksmith_resolved = true
		log_message("WORLD RESPONSE: Repaired forge damages with 1 Silver!")
		_refresh_exp2_events()

	elif action_id == "exp2_buy_sungem":
		remove_card_from_inventory(slotted.get("silver_slot", {}))
		event_ui.clear_all_slots()
		exp2_merchant_resolved = true
		add_card_to_inventory({"id": "sun_gem", "title": "Rare Sun-Gem", "tag": "artifact", "description": "A radiant gem."})
		log_message("OPPORTUNITY SEIZED: Bought Rare Sun-Gem!")
		_refresh_exp2_events()

	elif action_id == "exp2_buy_scrap":
		remove_card_from_inventory(slotted.get("silver_slot", {}))
		event_ui.clear_all_slots()
		exp2_merchant_resolved = true
		add_card_to_inventory({"id": "scrap_metal", "title": "Scrap Metal", "tag": "material", "description": "Leftover metal."})
		log_message("SHIFTING OFFER: Bought Scrap Metal!")
		_refresh_exp2_events()

	elif action_id == "exp2_conclude":
		event_ui.clear_all_slots()
		_clear_events()
		current_stage = "COMPLETE"
		log_message("\n=== EXPERIMENT 2 COMPLETED ===")

	# --- EXPERIMENT 3 ACTIONS ---
	elif action_id == "exp3_work_patient":
		event_ui.clear_all_slots()
		exp3_patient_progress += 1
		log_message("PATIENT PATH: Gathered in sacred forest (" + str(exp3_patient_progress) + "/3 turns).")
		if exp3_patient_progress >= 3:
			exp3_wood_acquired = true
			exp3_chosen_path = "patient"
			add_card_to_inventory({"id": "yew_heartwood", "title": "Yew Heartwood", "tag": "yew_heartwood", "description": "Harvested with care and forest harmony."})
			add_card_to_inventory({"id": "consecrated_yew", "title": "Consecrated Yew", "tag": "path_purity", "description": "Purity of pure harmony."})
			log_message("PATH COMPLETED: Acquired Yew Heartwood through Patient Stewardship! Received 'Consecrated Yew'.")
		_refresh_exp3_events()

	elif action_id == "exp3_choose_spirit":
		remove_card_from_inventory(slotted.get("offering_slot", {}))
		event_ui.clear_all_slots()
		exp3_wood_acquired = true
		exp3_chosen_path = "spirit"
		add_card_to_inventory({"id": "yew_heartwood", "title": "Yew Heartwood", "tag": "yew_heartwood", "description": "Granted by Sylph Spirit."})
		add_card_to_inventory({"id": "spirit_vow", "title": "Spirit Vow (Taboo)", "tag": "path_constraint", "description": "Taboo: Bound by oath to avoid destructive fire magic."})
		log_message("PATH COMPLETED: Sealed Spirit Bargain! Acquired Yew Heartwood and 'Spirit Vow (Taboo)'.")
		_refresh_exp3_events()

	elif action_id == "exp3_choose_forester":
		remove_card_from_inventory(slotted.get("silver_slot", {}))
		event_ui.clear_all_slots()
		exp3_wood_acquired = true
		exp3_chosen_path = "forester"
		add_card_to_inventory({"id": "yew_heartwood", "title": "Yew Heartwood", "tag": "yew_heartwood", "description": "Cut down by local forester."})
		add_card_to_inventory({"id": "forester_debt", "title": "Forester's Debt", "tag": "path_constraint", "description": "Debt: Forester expects political protection."})
		log_message("PATH COMPLETED: Hired Forester! Acquired Yew Heartwood and 'Forester's Debt'.")
		_refresh_exp3_events()

	elif action_id == "exp3_choose_dark":
		remove_card_from_inventory(slotted.get("grimoire_slot", {}))
		event_ui.clear_all_slots()
		exp3_wood_acquired = true
		exp3_chosen_path = "dark"
		add_card_to_inventory({"id": "yew_heartwood", "title": "Yew Heartwood", "tag": "yew_heartwood", "description": "Ripped from dying soil by dark magic."})
		add_card_to_inventory({"id": "blighted_soil", "title": "Blighted Soil", "tag": "path_constraint", "description": "Corrupted land; villagers fear your power."})
		log_message("PATH COMPLETED: Performed Dark Ritual! Instantly acquired Yew Heartwood and 'Blighted Soil'.")
		_refresh_exp3_events()

	elif action_id == "exp3_resolve_trial":
		remove_card_from_inventory(slotted.get("wood_slot", {}))
		event_ui.clear_all_slots()
		_clear_events()
		current_stage = "COMPLETE"
		log_message("\n=== EXPERIMENT 3 COMPLETED ===")
		match exp3_chosen_path:
			"patient":
				log_message("TITLE EARNED: 'Elian the Patient Scholar'")
				log_message("OUTCOME: Passed trial with pristine harmony! The woods and villagers flourish in balance.")
			"spirit":
				log_message("TITLE EARNED: 'Elian the Bound Mystic'")
				log_message("OUTCOME: Passed trial under Spirit Vow! Immense power gained, but bound by eternal nature taboos.")
			"forester":
				log_message("TITLE EARNED: 'Elian the Mortal Patron'")
				log_message("OUTCOME: Passed trial with mortal aid! Entangled in village debts and mortal politics.")
			"dark":
				log_message("TITLE EARNED: 'Elian the Dread Sorcerer'")
				log_message("OUTCOME: Passed trial through raw dark power! Feared by all, surrounded by blighted earth.")

	# --- LEGACY ACTIONS ---
	elif action_id == "resolve_craft_talisman":
		remove_card_from_inventory(slotted.get("material_slot", {}))
		event_ui.clear_all_slots()
		add_card_to_inventory({"id": "talisman", "title": "Protective Talisman", "tag": "talisman", "description": "A glowing ward."})
		_spawn_legacy_stage_b()

	elif action_id == "resolve_prepare_tea":
		remove_card_from_inventory(slotted.get("tea_slot", {}))
		event_ui.clear_all_slots()
		add_card_to_inventory({"id": "tea", "title": "Pot of Hot Tea", "tag": "tea", "description": "Warm tea."})
		_spawn_legacy_stage_c()

	elif action_id == "start_gathering":
		event_ui.clear_all_slots()
		gathering_task_active = true
		gathering_turns_remaining = 2
		log_message("Task Started: Gathering Herbs (2 turns).")
		_clear_events()

	elif action_id == "resolve_poultice":
		remove_card_from_inventory(slotted.get("herb_slot", {}))
		event_ui.clear_all_slots()
		add_card_to_inventory({"id": "poultice", "title": "Herbal Poultice", "tag": "remedy", "description": "Healing salve."})
		_spawn_legacy_stage_d()

	elif action_id == "welcome_guest":
		remove_card_from_inventory(slotted.get("tea_slot", {}))
		event_ui.clear_all_slots()
		add_card_to_inventory({"id": "village_favor", "title": "Village Favor", "tag": "boon", "description": "Gratitude of guest."})
		current_stage = "COMPLETE"
		_clear_events()
		log_message("LEGACY SCENARIO COMPLETE: Welcomed Guest!")

	elif action_id == "commune_spirits":
		remove_card_from_inventory(slotted.get("tea_slot", {}))
		event_ui.clear_all_slots()
		add_card_to_inventory({"id": "arcane_lore", "title": "Arcane Lore", "tag": "knowledge", "description": "Forest secrets."})
		current_stage = "COMPLETE"
		_clear_events()
		log_message("LEGACY SCENARIO COMPLETE: Communed with Spirits!")

	_update_ui()

func _on_end_turn_pressed() -> void:
	current_turn += 1
	log_message("\nAdvanced to Turn " + str(current_turn) + ".")

	# Legacy Gathering Task
	if active_experiment == 0 and gathering_task_active:
		gathering_turns_remaining -= 1
		if gathering_turns_remaining <= 0:
			gathering_task_active = false
			log_message("Task Completed: Gathering Herbs complete!")
			add_card_to_inventory({"id": "medicinal_herb", "title": "Medicinal Herb", "tag": "herb", "description": "Healing plant."})
			_spawn_legacy_stage_c_poultice()
		else:
			log_message("Task Progress: Gathering Herbs in progress... (" + str(gathering_turns_remaining) + " turns remaining).")

	# Experiment 2 Escalation Engine
	if active_experiment == 2:
		if not exp2_blight_resolved:
			if exp2_blight_stage == 1:
				exp2_blight_stage = 2
				log_message("WORLD EVOLUTION: Crop Blight was neglected! It has spread into SEVERE Blight!")
			elif exp2_blight_stage == 2:
				exp2_blight_stage = 3
				log_message("WORLD EVOLUTION: Severe Blight was neglected! Crop Rot & Famine strike the village!")
				add_card_to_inventory({"id": "villager_grievance", "title": "Villager Grievance", "tag": "grievance", "description": "Villagers resent your neglect."})

		if not exp2_blacksmith_resolved and exp2_blacksmith_stage == 1:
			exp2_blacksmith_stage = 2
			log_message("WORLD EVOLUTION: Blacksmith request neglected! He damaged his forge and feels resentful.")
			add_card_to_inventory({"id": "resentful_blacksmith", "title": "Resentful Blacksmith", "tag": "grievance", "description": "Blacksmith refuses cheap service."})

		if not exp2_merchant_resolved and exp2_merchant_stage == 1:
			exp2_merchant_stage = 2
			log_message("WORLD EVOLUTION: Merchant's Sun-Gem offer neglected! A rival wizard purchased it.")

		_refresh_exp2_events()

	# Update active event deadlines
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
