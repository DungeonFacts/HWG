extends Control

var current_turn: int = 1
var current_stage: String = "Active"
var active_experiment: int = 10 # 10 (Unified Run), 1, 2, 3, or 0 (Legacy)

# Inventory data (Tableau)
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

# Unified Run State Trackers
var village_unrest: int = 0
var village_favor: int = 0
var spirit_favor: int = 0
var arcane_insight: int = 0
var great_work_progress: int = 0
var totem_progress: int = 0
var game_over: bool = false
var game_over_reason: String = ""

# Unified Run Event States
var unified_blight_stage: int = 0 # 0=None, 1=Mild, 2=Severe, 3=Famine
var unified_blight_resolved: bool = false
var unified_merchant_stage: int = 0 # 0=None, 1=SunGem, 2=Leftovers
var unified_merchant_resolved: bool = false
var unified_child_active: bool = false
var unified_child_resolved: bool = false
var unified_smith_active: bool = false
var unified_smith_resolved: bool = false
var unified_spirit_shrine_active: bool = false
var unified_spirit_shrine_resolved: bool = false
var unified_storm_active: bool = false
var unified_storm_resolved: bool = false
var unified_coppice_active: bool = false
var unified_coppice_resolved: bool = false
var unified_shroom_active: bool = false
var unified_shroom_resolved: bool = false
var unified_dispute_active: bool = false
var unified_dispute_resolved: bool = false
var unified_leyline_active: bool = false
var unified_leyline_resolved: bool = false

# Experiment 1 State
var exp1_yew_committed: bool = false

# Experiment 2 State
var exp2_wand_progress: int = 0
var exp2_blight_stage: int = 1
var exp2_blight_resolved: bool = false
var exp2_blacksmith_stage: int = 1
var exp2_blacksmith_resolved: bool = false
var exp2_merchant_stage: int = 1
var exp2_merchant_resolved: bool = false

# Experiment 3 State
var exp3_wood_acquired: bool = false
var exp3_chosen_path: String = ""
var exp3_patient_progress: int = 0

# Legacy State
var gathering_task_active: bool = false
var gathering_turns_remaining: int = 0

func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	_setup_exp_selector()
	switch_experiment(10)

func log_message(text: String) -> void:
	if log_label:
		log_label.append_text("[Turn " + str(current_turn) + "] " + text + "\n")

func _setup_exp_selector() -> void:
	exp_selector.clear()
	exp_selector.add_item("Unified Game Run (30-Min Run)", 10)
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
	game_over = false
	game_over_reason = ""
	inventory_cards.clear()
	_deselect_card()
	_clear_events()
	if log_label:
		log_label.clear()

	match exp_id:
		10:
			_setup_unified_run()
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
	var new_card = card_data.duplicate(true)
	if not new_card.has("instance_id"):
		new_card["instance_id"] = str(randi()) + "_" + str(new_card.get("id", "card"))
	inventory_cards.append(new_card)
	_refresh_inventory_ui()

func remove_card_from_inventory(card_data: Dictionary) -> bool:
	for i in range(inventory_cards.size()):
		var c = inventory_cards[i]
		var match_id = false
		if c.has("instance_id") and card_data.has("instance_id"):
			match_id = (c["instance_id"] == card_data["instance_id"])
		else:
			match_id = (c.get("id") == card_data.get("id"))

		if match_id:
			inventory_cards.remove_at(i)
			if selected_card_data == card_data:
				_deselect_card()
			_refresh_inventory_ui()
			return true
	return false

func process_card_expiry() -> void:
	var cards_to_remove = []
	for card in inventory_cards:
		if card.get("is_locked", false):
			continue
		if card.has("expires_in_turns"):
			card["expires_in_turns"] -= 1
			if card["expires_in_turns"] <= 0:
				cards_to_remove.append(card)

	for expired_card in cards_to_remove:
		log_message("CARD EXPIRED: '" + expired_card.get("title", "Card") + "' has faded away.")
		remove_card_from_inventory(expired_card)

func _deselect_card() -> void:
	selected_card_data = {}
	if selected_card_ui != null and is_instance_valid(selected_card_ui):
		selected_card_ui.set_selected(false)
		selected_card_ui = null

func get_all_slotted_instance_ids() -> Array:
	var slotted_ids = []
	for event_inst in events_container.get_children():
		if is_instance_valid(event_inst) and event_inst.has_method("get_slotted_cards"):
			var slotted = event_inst.get_slotted_cards()
			for slot_id in slotted:
				var card = slotted[slot_id]
				if not card.is_empty() and card.has("instance_id"):
					slotted_ids.append(card["instance_id"])
	return slotted_ids

func _refresh_inventory_ui() -> void:
	for child in inventory_container.get_children():
		child.queue_free()

	var slotted_ids = get_all_slotted_instance_ids()

	for card_data in inventory_cards:
		var instance_id = card_data.get("instance_id", "")
		if instance_id != "" and instance_id in slotted_ids:
			continue
		if card_data.get("is_locked", false):
			continue

		var card_inst = card_ui_scene.instantiate()
		inventory_container.add_child(card_inst)
		card_inst.setup(card_data, false)
		card_inst.card_selected.connect(_on_inventory_card_selected)

func _on_inventory_card_selected(card_ui) -> void:
	if card_ui.card_data.get("is_locked", false):
		log_message("Cannot select '" + card_ui.card_data.get("title", "Card") + "': Card is locked in an active event!")
		return
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

	if active_experiment == 10:
		wizard_desc_label.text = "Cards: " + str(inventory_cards.size()) + "\n" + \
			"Village Favor: " + str(village_favor) + " | Unrest: " + str(village_unrest) + "/5\n" + \
			"Spirit Favor: " + str(spirit_favor) + "/5 | Insight: " + str(arcane_insight)
	else:
		wizard_desc_label.text = "Status: Active Guardian\nCards in Hand: " + str(inventory_cards.size())

# ==============================================================================
# UNIFIED GAME RUN (30-MINUTE RECOMBINATORY RUN)
# ==============================================================================
func _setup_unified_run() -> void:
	village_unrest = 0
	village_favor = 0
	spirit_favor = 0
	arcane_insight = 0
	great_work_progress = 0
	totem_progress = 0
	game_over = false

	unified_blight_stage = 1
	unified_blight_resolved = false
	unified_merchant_stage = 1
	unified_merchant_resolved = false
	unified_child_active = false
	unified_child_resolved = false
	unified_smith_active = false
	unified_smith_resolved = false
	unified_spirit_shrine_active = false
	unified_spirit_shrine_resolved = false
	unified_storm_active = false
	unified_storm_resolved = false
	unified_coppice_active = false
	unified_coppice_resolved = false
	unified_shroom_active = false
	unified_shroom_resolved = false
	unified_dispute_active = false
	unified_dispute_resolved = false
	unified_leyline_active = false
	unified_leyline_resolved = false

	exp_title_label.text = "Hedge Wizard — Unified Recombinatory Run"
	exp_desc_label.text = "Assign cards to events, then click End Turn. Manage village unrest, spirit favor, and complete the Great Work of Magick!"

	log_message("=== UNIFIED GAME RUN INITIALIZED ===")
	log_message("Welcome, Hedge Wizard. Allocate your cards across active situations before clicking End Turn.")

	add_card_to_inventory(wizard_card_def.duplicate())
	add_card_to_inventory({
		"id": "silver_shilling",
		"title": "Silver Shilling",
		"tag": "currency",
		"description": "Hard coin earned from trade."
	})
	add_card_to_inventory({
		"id": "medicinal_herb",
		"title": "Medicinal Herb",
		"tag": "herb",
		"description": "A healing forest plant."
	})
	add_card_to_inventory({
		"id": "forbidden_grimoire",
		"title": "Forbidden Grimoire",
		"tag": "grimoire",
		"description": "A dark tome containing esoteric arcane knowledge."
	})

	_refresh_unified_events()

func count_negative_cards() -> Array:
	var neg_cards = []
	for card in inventory_cards:
		var tag = card.get("tag", "")
		var id = card.get("id", "")
		if tag in ["grievance", "curse", "blighted_soil", "path_constraint"] or id in ["villager_grievance", "resentful_blacksmith", "blighted_soil", "forest_curse"] or card.get("is_negative", false):
			neg_cards.append(card)
	return neg_cards

func _refresh_unified_events() -> void:
	_clear_events()

	if game_over:
		return

	# --- MASS MITIGATION EVENTS (Triggers when 3+ negative cards accumulate) ---
	var negatives = count_negative_cards()
	if negatives.size() >= 3:
		_add_event({
			"id": "uni_evt_mass_mitigate",
			"title": "[MASS MITIGATION] Grand Village & Land Reconciliation",
			"description": "CRISIS THRESHOLD REACHED: 3+ grievances/corruptions have accumulated! Slot 3 negative cards + 1 Resource or Wizard to cleanse them.",
			"deadline": -1,
			"slots": [
				{"id": "neg_1", "label": "Grievance / Curse 1", "req_tag": "any"},
				{"id": "neg_2", "label": "Grievance / Curse 2", "req_tag": "any"},
				{"id": "neg_3", "label": "Grievance / Curse 3", "req_tag": "any"},
				{"id": "cost_slot", "label": "Silver / Herb / Wizard", "req_tag": "any"}
			],
			"actions": [
				{"id": "uni_mass_mitigate_feast", "label": "Hold Grand Feast (3 Cards + Silver/Herb)", "required_slots": ["neg_1", "neg_2", "neg_3", "cost_slot"]},
				{"id": "uni_mass_mitigate_ritual", "label": "Purification Ritual (3 Cards + Wizard)", "required_slots": ["neg_1", "neg_2", "neg_3", "cost_slot"]}
			]
		})

	# Permanent Activity 1: Forage Sacred Woods
	_add_event({
		"id": "uni_act_forage",
		"title": "Activity: Forage Sacred Woods",
		"description": "Slot Wizard to gather medicinal herbs or yew wood from the surrounding forests.",
		"deadline": -1,
		"slots": [
			{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"}
		],
		"actions": [
			{"id": "uni_forage", "label": "Forage Woods (1 Turn)", "required_slots": ["wizard_slot"]}
		]
	})

	# Permanent Activity 2: Study Grimoire
	_add_event({
		"id": "uni_act_study",
		"title": "Activity: Study Forbidden Grimoire",
		"description": "Slot Wizard + Grimoire to decode ancient runes and gain Arcane Insight.",
		"deadline": -1,
		"slots": [
			{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
			{"id": "grimoire_slot", "label": "Grimoire", "req_tag": "grimoire"}
		],
		"actions": [
			{"id": "uni_study", "label": "Study Grimoire", "required_slots": ["wizard_slot", "grimoire_slot"]}
		]
	})

	# Permanent Activity 3: Brew Potent Remedy
	_add_event({
		"id": "uni_act_brew",
		"title": "Activity: Brew Potent Remedy",
		"description": "Slot Wizard + Medicinal Herb to brew a miracle potion.",
		"deadline": -1,
		"slots": [
			{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
			{"id": "herb_slot", "label": "Herb", "req_tag": "herb"}
		],
		"actions": [
			{"id": "uni_brew", "label": "Brew Potion", "required_slots": ["wizard_slot", "herb_slot"]}
		]
	})

	# Permanent Activity 4: Animate Homunculus
	_add_event({
		"id": "uni_act_homunculus",
		"title": "Activity: Animate Homunculus",
		"description": "Slot Wizard + Herb or Silver to craft a Homunculus assistant (lasts 3 turns) that acts as a Wizard.",
		"deadline": -1,
		"slots": [
			{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
			{"id": "reagent_slot", "label": "Herb / Silver", "req_tag": "any"}
		],
		"actions": [
			{"id": "uni_animate_homunculus", "label": "Animate Homunculus", "required_slots": ["wizard_slot", "reagent_slot"]}
		]
	})

	# Ambition 1: Carve Spirit Totem (Multi-turn 2 turns)
	if totem_progress < 2:
		_add_event({
			"id": "uni_amb_totem",
			"title": "Ambition: Carve Spirit Totem (" + str(totem_progress) + "/2)",
			"description": "Slot Wizard + Wood to carve a totem honoring nature spirits. (Progress saved if paused).",
			"deadline": -1,
			"slots": [
				{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
				{"id": "wood_slot", "label": "Wood / Yew", "req_tag": "yew_heartwood"}
			],
			"actions": [
				{"id": "uni_work_totem", "label": "Carve Totem (1 Turn)", "required_slots": ["wizard_slot", "wood_slot"]}
			]
		})

	# Ambition 2: The Great Work of Magick (Win Condition, Multi-turn 3 turns)
	if great_work_progress < 3:
		_add_event({
			"id": "uni_amb_great_work",
			"title": "Masterpiece: The Great Work of Magick (" + str(great_work_progress) + "/3)",
			"description": "Channel supreme magic into a masterpiece ritual. Requires Wizard + Arcane Insight card or Gem.",
			"deadline": -1,
			"slots": [
				{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
				{"id": "reagent_slot", "label": "Insight / Artifact", "req_tag": "any"}
			],
			"actions": [
				{"id": "uni_work_great_work", "label": "Perform Ritual (1 Turn)", "required_slots": ["wizard_slot", "reagent_slot"]}
			]
		})

	# --- DYNAMIC DECK EVENT DRAWS ---
	# 1. Crop Blight Escalation
	if not unified_blight_resolved:
		if unified_blight_stage == 1:
			_add_event({
				"id": "uni_evt_blight",
				"title": "[World] Mild Crop Blight",
				"description": "Fungus threatens crops! Option A: Cure with Medicinal Herb. Option B: Cleanse with Wizard.",
				"deadline": 2,
				"slots": [
					{"id": "herb_slot", "label": "Medicinal Herb", "req_tag": "herb"},
					{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"}
				],
				"actions": [
					{"id": "uni_blight_herb", "label": "Apply Herb", "required_slots": ["herb_slot"]},
					{"id": "uni_blight_wiz", "label": "Wizard Ritual", "required_slots": ["wizard_slot"]}
				]
			})
		elif unified_blight_stage == 2:
			_add_event({
				"id": "uni_evt_blight",
				"title": "[World] SEVERE Crop Blight!",
				"description": "NEGLECT CONSEQUENCE: Blight has spread! Requires Wizard + Herb to cleanse, OR Dark Grimoire ritual.",
				"deadline": 1,
				"slots": [
					{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
					{"id": "herb_slot", "label": "Medicinal Herb", "req_tag": "herb"},
					{"id": "grimoire_slot", "label": "Grimoire", "req_tag": "grimoire"}
				],
				"actions": [
					{"id": "uni_blight_cleanse", "label": "Cleanse (Wizard + Herb)", "required_slots": ["wizard_slot", "herb_slot"]},
					{"id": "uni_blight_dark", "label": "Dark Blood Cleanse (Grimoire)", "required_slots": ["wizard_slot", "grimoire_slot"]}
				]
			})

	# 2. Wandering Merchant
	if not unified_merchant_resolved and current_turn <= 4:
		if unified_merchant_stage == 1:
			_add_event({
				"id": "uni_evt_merchant",
				"title": "[Opportunity] Wandering Merchant: Sun-Gem",
				"description": "Merchant sells a radiant Sun-Gem for 1 Silver Shilling.",
				"deadline": 1,
				"slots": [
					{"id": "silver_slot", "label": "Silver Shilling", "req_tag": "currency"}
				],
				"actions": [
					{"id": "uni_buy_sungem", "label": "Buy Sun-Gem (1 Silver)", "required_slots": ["silver_slot"]}
				]
			})
		elif unified_merchant_stage == 2:
			_add_event({
				"id": "uni_evt_merchant",
				"title": "[Opportunity] Merchant's Leftovers",
				"description": "Sun-Gem was sold! Merchant now sells Scrap Metal for 1 Silver Shilling.",
				"deadline": 1,
				"slots": [
					{"id": "silver_slot", "label": "Silver Shilling", "req_tag": "currency"}
				],
				"actions": [
					{"id": "uni_buy_scrap", "label": "Buy Scrap Metal (1 Silver)", "required_slots": ["silver_slot"]}
				]
			})

	# 3. Sick Villager Child (Spawns turn >= 2)
	if current_turn >= 2 and not unified_child_resolved and not unified_child_active:
		unified_child_active = true

	if unified_child_active and not unified_child_resolved:
		_add_event({
			"id": "uni_evt_child",
			"title": "[Petitioner] Sick Villager Child",
			"description": "A distraught mother seeks help for her feverish child. Option A: Potent Remedy. Option B: Wizard Ritual.",
			"deadline": 2,
			"slots": [
				{"id": "remedy_slot", "label": "Potent Remedy", "req_tag": "remedy"},
				{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"}
			],
			"actions": [
				{"id": "uni_heal_remedy", "label": "Give Remedy", "required_slots": ["remedy_slot"]},
				{"id": "uni_heal_wiz", "label": "Heal Ritual (Wizard)", "required_slots": ["wizard_slot"]}
			]
		})

	# 4. Blacksmith Anomaly (Spawns turn >= 3)
	if current_turn >= 3 and not unified_smith_resolved and not unified_smith_active:
		unified_smith_active = true

	if unified_smith_active and not unified_smith_resolved:
		_add_event({
			"id": "uni_evt_smith",
			"title": "[Petitioner] Blacksmith's Forge Anomaly",
			"description": "Blacksmith asks for aid with a strange forge heat. Option A: Wizard help. Option B: Pay 1 Silver for materials.",
			"deadline": 2,
			"slots": [
				{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
				{"id": "silver_slot", "label": "Silver Shilling", "req_tag": "currency"}
			],
			"actions": [
				{"id": "uni_smith_wiz", "label": "Cool Forge (Wizard)", "required_slots": ["wizard_slot"]},
				{"id": "uni_smith_silver", "label": "Pay Materials (1 Silver)", "required_slots": ["silver_slot"]}
			]
		})

	# 5. Sylph Spirit Shrine (Spawns turn >= 4)
	if current_turn >= 4 and not unified_spirit_shrine_resolved and not unified_spirit_shrine_active:
		unified_spirit_shrine_active = true

	if unified_spirit_shrine_active and not unified_spirit_shrine_resolved:
		_add_event({
			"id": "uni_evt_spirit",
			"title": "[Shrine] Sylph Spirit Apparition",
			"description": "A nature spirit manifests. Offer Herbal Infusion for Spirit Favor, or Silver for a Forest Blessing.",
			"deadline": 2,
			"slots": [
				{"id": "herb_slot", "label": "Herb / Offering", "req_tag": "herb"},
				{"id": "silver_slot", "label": "Silver Shilling", "req_tag": "currency"}
			],
			"actions": [
				{"id": "uni_spirit_herb", "label": "Offer Herb (+1 Spirit Favor)", "required_slots": ["herb_slot"]},
				{"id": "uni_spirit_silver", "label": "Offer Silver (Forest Blessing)", "required_slots": ["silver_slot"]}
			]
		})

	# 6. Valley Shadow Storm Crisis (Spawns turn >= 5)
	if current_turn >= 5 and not unified_storm_resolved and not unified_storm_active:
		unified_storm_active = true

	if unified_storm_active and not unified_storm_resolved:
		_add_event({
			"id": "uni_evt_storm",
			"title": "[CRISIS] Valley Shadow Storm!",
			"description": "Dark forces storm the valley! Resolve with Wizard + Sun-Gem, Potent Remedy, OR Forest Blessing.",
			"deadline": 2,
			"slots": [
				{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
				{"id": "boon_slot", "label": "Gem / Remedy / Blessing", "req_tag": "any"}
			],
			"actions": [
				{"id": "uni_ward_storm", "label": "Repel Shadow Storm", "required_slots": ["wizard_slot", "boon_slot"]}
			]
		})

	# 7. Forest Coppice Dilemma (Spawns turn >= 2)
	if current_turn >= 2 and not unified_coppice_resolved and not unified_coppice_active:
		unified_coppice_active = true

	if unified_coppice_active and not unified_coppice_resolved:
		_add_event({
			"id": "uni_evt_coppice",
			"title": "[Dilemma] Sacred Coppice Timber Choice",
			"description": "Spirits protect the sacred coppice, but villagers want firewood! Option A (Protect): Wizard + Herb -> 3 Cards (Blessing, Yew Wood, Wild Berries) [+2 Spirit Favor, +1 Unrest]. Option B (Harvest): Wizard -> 3 Cards (Timber, Timber, Silver) [+1 Village Favor, -1 Spirit Favor].",
			"deadline": 2,
			"slots": [
				{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
				{"id": "herb_slot", "label": "Herb (Option A)", "req_tag": "herb"}
			],
			"actions": [
				{"id": "uni_coppice_protect", "label": "Protect Coppice (Wizard + Herb -> 3 Cards)", "required_slots": ["wizard_slot", "herb_slot"]},
				{"id": "uni_coppice_harvest", "label": "Harvest Timber (Wizard -> 3 Cards)", "required_slots": ["wizard_slot"]}
			]
		})

	# 8. Rare Star-Mushroom Foraging (Spawns turn >= 3)
	if current_turn >= 3 and not unified_shroom_resolved and not unified_shroom_active:
		unified_shroom_active = true

	if unified_shroom_active and not unified_shroom_resolved:
		_add_event({
			"id": "uni_evt_shroom",
			"title": "[Opportunity] Star-Mushroom Harvest",
			"description": "Luminous star-mushrooms bloom! Option A: Harvest with Herb + Silver -> Yields 3 Cards (Star Mushroom Reagent, Potent Remedy, Arcane Dust), BUT imposes a Forest Lord Curse! Option B: Ignore.",
			"deadline": 2,
			"slots": [
				{"id": "herb_slot", "label": "Herb", "req_tag": "herb"},
				{"id": "silver_slot", "label": "Silver Shilling", "req_tag": "currency"}
			],
			"actions": [
				{"id": "uni_shroom_harvest", "label": "Harvest Star-Mushrooms (Herb + Silver -> 3 Cards + Curse)", "required_slots": ["herb_slot", "silver_slot"]}
			]
		})

	# 9. Village Council Dispute (Spawns turn >= 4)
	if current_turn >= 4 and not unified_dispute_resolved and not unified_dispute_active:
		unified_dispute_active = true

	if unified_dispute_active and not unified_dispute_resolved:
		_add_event({
			"id": "uni_evt_dispute",
			"title": "[Petitioner] Village Council Dispute",
			"description": "Factions quarrel over land! Option A: Broker Peace with Wizard + Silver -> Yields 3 Cards (Village Favor, Village Gratitude, Ancient Scroll) [+2 Favor, -1 Unrest, -1 Spirit Favor].",
			"deadline": 2,
			"slots": [
				{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
				{"id": "silver_slot", "label": "Silver Shilling", "req_tag": "currency"}
			],
			"actions": [
				{"id": "uni_dispute_broker", "label": "Broker Peace (Wizard + Silver -> 3 Cards)", "required_slots": ["wizard_slot", "silver_slot"]}
			]
		})

	# 10. Sunken Leyline Shrine (Spawns turn >= 5)
	if current_turn >= 5 and not unified_leyline_resolved and not unified_leyline_active:
		unified_leyline_active = true

	if unified_leyline_active and not unified_leyline_resolved:
		_add_event({
			"id": "uni_evt_leyline",
			"title": "[Ancient Mystery] Sunken Leyline Shrine",
			"description": "An ancient leyline shrine surges! Siphon magic with Wizard + Insight / Grimoire -> Yields 3 Cards (Arcane Insight x2, Sun-Gem Artifact), BUT corrupts the land with Blighted Soil!",
			"deadline": 2,
			"slots": [
				{"id": "wizard_slot", "label": "Wizard", "req_tag": "wizard"},
				{"id": "reagent_slot", "label": "Insight / Grimoire", "req_tag": "any"}
			],
			"actions": [
				{"id": "uni_leyline_siphon", "label": "Siphon Leyline Power (Wizard + Reagent -> 3 Cards + Blighted Soil)", "required_slots": ["wizard_slot", "reagent_slot"]}
			]
		})

func _check_unified_win_loss() -> void:
	if game_over:
		return

	if village_unrest >= 5:
		game_over = true
		current_stage = "DEFEAT"
		log_message("\n==========================================")
		log_message("DEFEAT: Village Mob Revolt! Unrest reached max limit. Villagers banished you.")
		log_message("==========================================")

	elif spirit_favor <= -3:
		game_over = true
		current_stage = "DEFEAT"
		log_message("\n==========================================")
		log_message("DEFEAT: Wrath of the Spirits! Angry spirits cursed your realm.")
		log_message("==========================================")

	elif spirit_favor >= 5:
		game_over = true
		current_stage = "VICTORY"
		log_message("\n==========================================")
		log_message("VICTORY! Favored Scion of the Rain God! Eternal divine favor achieved!")
		log_message("==========================================")

	elif great_work_progress >= 3:
		game_over = true
		current_stage = "VICTORY"
		log_message("\n==========================================")
		log_message("VICTORY! Completed the Great Work of Magick! You are a Legendary Archmage!")
		log_message("==========================================")

	elif current_turn >= 15 and village_unrest < 3 and spirit_favor >= 0:
		game_over = true
		current_stage = "VICTORY"
		log_message("\n==========================================")
		log_message("VICTORY! Guardian of the Realm! You protected the valley for 15 turns in balance.")
		log_message("==========================================")

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
	event_inst.slot_card_changed.connect(func(_ev): _refresh_inventory_ui())

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
		if not removed.is_empty():
			log_message("Removed card '" + removed.get("title", "") + "' from " + slot_ui.slot_label_text)

func _on_event_action_triggered(event_ui, action_id: String) -> void:
	var slotted = event_ui.get_slotted_cards()

	# --- UNIFIED GAME RUN ACTIONS ---
	if action_id == "uni_forage":
		event_ui.clear_all_slots()
		if randf() > 0.5:
			add_card_to_inventory({"id": "medicinal_herb", "title": "Medicinal Herb", "tag": "herb", "description": "Fresh forest healing herb."})
			log_message("FORAGE RESULT: Gathered a Medicinal Herb from the woods.")
		else:
			add_card_to_inventory({"id": "yew_heartwood", "title": "Yew Heartwood", "tag": "yew_heartwood", "description": "Dense, rare magical timber."})
			log_message("FORAGE RESULT: Discovered rare Yew Heartwood!")

	elif action_id == "uni_study":
		event_ui.clear_all_slots()
		arcane_insight += 1
		add_card_to_inventory({"id": "arcane_insight", "title": "Arcane Insight", "tag": "insight", "description": "Decoded rune knowledge."})
		log_message("STUDY RESULT: Decoded ancient secrets! Arcane Insight is now " + str(arcane_insight) + ".")

	elif action_id == "uni_brew":
		remove_card_from_inventory(slotted.get("herb_slot", {}))
		event_ui.clear_all_slots()
		add_card_to_inventory({"id": "potent_remedy", "title": "Potent Remedy", "tag": "remedy", "description": "A powerful restorative potion."})
		log_message("BREWING: Crafted Potent Remedy from Medicinal Herb!")

	elif action_id == "uni_animate_homunculus":
		var reagent_card = slotted.get("reagent_slot", {})
		var r_tag = reagent_card.get("tag", "")
		if r_tag in ["herb", "currency", "material", "ingredient"]:
			remove_card_from_inventory(reagent_card)
			event_ui.clear_all_slots()
			add_card_to_inventory({
				"id": "homunculus",
				"title": "Arcane Homunculus",
				"tag": "wizard",
				"description": "A temporary magical automaton. Acts as a Wizard for 3 turns.",
				"expires_in_turns": 3
			})
			log_message("ALCHEMY RESULT: Animated an Arcane Homunculus! It will serve as a Wizard assistant for 3 turns.")
		else:
			log_message("ANIMATION FAILED: Homunculus creation requires an Herb, Silver, or Material card!")

	elif action_id == "uni_mass_mitigate_feast":
		remove_card_from_inventory(slotted.get("neg_1", {}))
		remove_card_from_inventory(slotted.get("neg_2", {}))
		remove_card_from_inventory(slotted.get("neg_3", {}))
		var cost_card = slotted.get("cost_slot", {})
		if cost_card.get("id") != "wizard":
			remove_card_from_inventory(cost_card)
		event_ui.clear_all_slots()
		if village_unrest >= 2:
			village_unrest -= 2
		else:
			village_unrest = 0
		village_favor += 1
		log_message("MASS MITIGATION: Held Grand Village Feast! Cleansed 3 negative grievances/curses and restored trust.")
		_refresh_unified_events()

	elif action_id == "uni_mass_mitigate_ritual":
		remove_card_from_inventory(slotted.get("neg_1", {}))
		remove_card_from_inventory(slotted.get("neg_2", {}))
		remove_card_from_inventory(slotted.get("neg_3", {}))
		var cost_card = slotted.get("cost_slot", {})
		if cost_card.get("id") != "wizard":
			remove_card_from_inventory(cost_card)
		event_ui.clear_all_slots()
		spirit_favor += 2
		if village_unrest > 0: village_unrest -= 1
		log_message("MASS MITIGATION: Performed Purification Ritual! Cleansed 3 corruptions and restored spirit harmony (+2 Spirit Favor).")
		_refresh_unified_events()

	elif action_id == "uni_work_totem":
		totem_progress += 1
		log_message("TOTEM AMBITION: Worked on Spirit Totem (" + str(totem_progress) + "/2 turns).")
		if totem_progress < 2:
			for slot_key in slotted:
				var c = slotted[slot_key]
				if not c.is_empty():
					c["is_locked"] = true
			_refresh_inventory_ui()
		else:
			for slot_key in slotted:
				var c = slotted[slot_key]
				if not c.is_empty():
					c["is_locked"] = false
			remove_card_from_inventory(slotted.get("wood_slot", {}))
			event_ui.clear_all_slots()
			spirit_favor += 2
			add_card_to_inventory({"id": "totem_blessing", "title": "Spirit Totem Blessing", "tag": "boon", "description": "Sacred blessing from forest spirits."})
			log_message("TOTEM COMPLETED! Spirit Favor increased by 2! (Spirit Favor: " + str(spirit_favor) + ").")
		_refresh_unified_events()

	elif action_id == "uni_work_great_work":
		remove_card_from_inventory(slotted.get("reagent_slot", {}))
		event_ui.clear_all_slots()
		great_work_progress += 1
		log_message("GREAT WORK RITUAL: Progress advanced (" + str(great_work_progress) + "/3 turns).")
		_check_unified_win_loss()
		_refresh_unified_events()

	elif action_id == "uni_blight_herb":
		remove_card_from_inventory(slotted.get("herb_slot", {}))
		event_ui.clear_all_slots()
		unified_blight_resolved = true
		village_favor += 1
		log_message("WORLD RESPONSE: Cured Mild Crop Blight with Medicinal Herb! (+1 Village Favor).")
		_refresh_unified_events()

	elif action_id == "uni_blight_wiz":
		event_ui.clear_all_slots()
		unified_blight_resolved = true
		log_message("WORLD RESPONSE: Wizard cleansed Crop Blight.")
		_refresh_unified_events()

	elif action_id == "uni_blight_cleanse":
		remove_card_from_inventory(slotted.get("herb_slot", {}))
		event_ui.clear_all_slots()
		unified_blight_resolved = true
		village_favor += 1
		log_message("WORLD RESPONSE: Cleanse ritual saved the crops from Severe Blight!")
		_refresh_unified_events()

	elif action_id == "uni_blight_dark":
		remove_card_from_inventory(slotted.get("grimoire_slot", {}))
		event_ui.clear_all_slots()
		unified_blight_resolved = true
		spirit_favor -= 2
		add_card_to_inventory({"id": "blighted_soil", "title": "Blighted Soil", "tag": "path_constraint", "description": "Corrupted soil; angry spirits curse your blood magic."})
		log_message("DARK RITUAL: Sacrificed soil life to save crops! Spirit Favor lowered by 2.")
		_check_unified_win_loss()
		_refresh_unified_events()

	elif action_id == "uni_buy_sungem":
		remove_card_from_inventory(slotted.get("silver_slot", {}))
		event_ui.clear_all_slots()
		unified_merchant_resolved = true
		add_card_to_inventory({"id": "sun_gem", "title": "Rare Sun-Gem", "tag": "artifact", "description": "A radiant artifact gem."})
		log_message("MERCHANT TRADE: Purchased Rare Sun-Gem!")
		_refresh_unified_events()

	elif action_id == "uni_buy_scrap":
		remove_card_from_inventory(slotted.get("silver_slot", {}))
		event_ui.clear_all_slots()
		unified_merchant_resolved = true
		add_card_to_inventory({"id": "scrap_metal", "title": "Scrap Metal", "tag": "material", "description": "Melted metal scrap."})
		log_message("MERCHANT TRADE: Purchased Scrap Metal!")
		_refresh_unified_events()

	elif action_id == "uni_heal_remedy":
		remove_card_from_inventory(slotted.get("remedy_slot", {}))
		event_ui.clear_all_slots()
		unified_child_resolved = true
		village_favor += 2
		if village_unrest > 0: village_unrest -= 1
		add_card_to_inventory({"id": "village_gratitude", "title": "Village Gratitude", "tag": "boon", "description": "The mother's eternal blessing."})
		log_message("HEALING RESULT: Cured the sick child! (+2 Village Favor, -1 Unrest).")
		_refresh_unified_events()

	elif action_id == "uni_heal_wiz":
		event_ui.clear_all_slots()
		unified_child_resolved = true
		village_favor += 1
		log_message("HEALING RESULT: Wizard restored the child's health!")
		_refresh_unified_events()

	elif action_id == "uni_smith_wiz":
		event_ui.clear_all_slots()
		unified_smith_resolved = true
		village_favor += 1
		log_message("PETITION RESOLVED: Cool forge anomaly for Blacksmith!")
		_refresh_unified_events()

	elif action_id == "uni_smith_silver":
		remove_card_from_inventory(slotted.get("silver_slot", {}))
		event_ui.clear_all_slots()
		unified_smith_resolved = true
		village_favor += 1
		log_message("PETITION RESOLVED: Bought forge metal for Blacksmith!")
		_refresh_unified_events()

	elif action_id == "uni_spirit_herb":
		remove_card_from_inventory(slotted.get("herb_slot", {}))
		event_ui.clear_all_slots()
		unified_spirit_shrine_resolved = true
		spirit_favor += 1
		log_message("SHRINE SACRIFICE: Offered Herb to Sylph Spirit! (+1 Spirit Favor).")
		_check_unified_win_loss()
		_refresh_unified_events()

	elif action_id == "uni_spirit_silver":
		remove_card_from_inventory(slotted.get("silver_slot", {}))
		event_ui.clear_all_slots()
		unified_spirit_shrine_resolved = true
		add_card_to_inventory({"id": "forest_blessing", "title": "Forest Blessing", "tag": "boon", "description": "Divine protection of Sylph Spirit."})
		log_message("SHRINE BLESSING: Received Forest Blessing!")
		_refresh_unified_events()

	elif action_id == "uni_ward_storm":
		remove_card_from_inventory(slotted.get("boon_slot", {}))
		event_ui.clear_all_slots()
		unified_storm_resolved = true
		village_favor += 2
		spirit_favor += 1
		log_message("CRISIS RESOLVED: Successfully repelled the Valley Shadow Storm!")
		_check_unified_win_loss()
		_refresh_unified_events()

	elif action_id == "uni_coppice_protect":
		remove_card_from_inventory(slotted.get("herb_slot", {}))
		event_ui.clear_all_slots()
		unified_coppice_resolved = true
		spirit_favor += 2
		village_unrest += 1
		add_card_to_inventory({"id": "spirit_blessing", "title": "Spirit Blessing", "tag": "boon", "description": "Blessing of the Coppice Spirits."})
		add_card_to_inventory({"id": "yew_heartwood", "title": "Yew Heartwood", "tag": "yew_heartwood", "description": "Rare timber granted by nature."})
		add_card_to_inventory({"id": "wild_berries", "title": "Wild Forest Berries", "tag": "herb", "description": "Sweet, healing forest berries."})
		log_message("COPPICE CHOICE: Protected the Coppice! Gained 3 cards (Spirit Blessing, Yew Heartwood, Berries). (+2 Spirit Favor, +1 Village Unrest).")
		_check_unified_win_loss()
		_refresh_unified_events()

	elif action_id == "uni_coppice_harvest":
		event_ui.clear_all_slots()
		unified_coppice_resolved = true
		village_favor += 1
		spirit_favor -= 1
		add_card_to_inventory({"id": "timber", "title": "Heartwood Timber", "tag": "material", "description": "Strong construction timber."})
		add_card_to_inventory({"id": "timber_extra", "title": "Firewood Logs", "tag": "material", "description": "A pile of firewood for winter."})
		add_card_to_inventory({"id": "silver_shilling", "title": "Silver Shilling", "tag": "currency", "description": "Paid by villagers for firewood."})
		log_message("COPPICE CHOICE: Harvested Timber! Gained 3 cards (Timber x2, Silver). (+1 Village Favor, -1 Spirit Favor).")
		_check_unified_win_loss()
		_refresh_unified_events()

	elif action_id == "uni_shroom_harvest":
		remove_card_from_inventory(slotted.get("herb_slot", {}))
		remove_card_from_inventory(slotted.get("silver_slot", {}))
		event_ui.clear_all_slots()
		unified_shroom_resolved = true
		add_card_to_inventory({"id": "star_mushroom", "title": "Star-Mushroom Reagent", "tag": "ingredient", "description": "A rare glowing fungal reagent."})
		add_card_to_inventory({"id": "potent_remedy", "title": "Potent Remedy", "tag": "remedy", "description": "Brewed remedy from fungal essence."})
		add_card_to_inventory({"id": "arcane_dust", "title": "Arcane Dust", "tag": "insight", "description": "Glowing spore dust."})
		add_card_to_inventory({"id": "forest_curse", "title": "Forest Lord Curse", "tag": "curse", "description": "The Forest Lord's wrath for plundering rare fungi."})
		log_message("SHROOM HARVEST: Harvested Star-Mushrooms! Received 3 valuable reagents, BUT angered the forest (Forest Lord Curse added!).")
		_refresh_unified_events()

	elif action_id == "uni_dispute_broker":
		remove_card_from_inventory(slotted.get("silver_slot", {}))
		event_ui.clear_all_slots()
		unified_dispute_resolved = true
		village_favor += 2
		if village_unrest > 0: village_unrest -= 1
		spirit_favor -= 1
		add_card_to_inventory({"id": "village_favor_card", "title": "Village Favor", "tag": "boon", "description": "Political sway in council."})
		add_card_to_inventory({"id": "village_gratitude", "title": "Village Gratitude", "tag": "boon", "description": "Gratitude of the council elders."})
		add_card_to_inventory({"id": "ancient_scroll", "title": "Ancient Scroll", "tag": "scroll", "description": "Deed scroll containing old lore."})
		log_message("COUNCIL DISPUTE: Brokered council peace! Received 3 cards (Favor, Gratitude, Scroll). (+2 Favor, -1 Unrest, -1 Spirit Favor).")
		_check_unified_win_loss()
		_refresh_unified_events()

	elif action_id == "uni_leyline_siphon":
		var reagent = slotted.get("reagent_slot", {})
		if reagent.get("id") != "wizard":
			remove_card_from_inventory(reagent)
		event_ui.clear_all_slots()
		unified_leyline_resolved = true
		arcane_insight += 2
		add_card_to_inventory({"id": "arcane_insight", "title": "Arcane Insight", "tag": "insight", "description": "Decoded leyline power."})
		add_card_to_inventory({"id": "arcane_insight_2", "title": "Arcane Insight", "tag": "insight", "description": "Deep leyline resonance."})
		add_card_to_inventory({"id": "sun_gem", "title": "Sun-Gem Artifact", "tag": "artifact", "description": "Crystallized leyline energy."})
		add_card_to_inventory({"id": "blighted_soil", "title": "Blighted Soil", "tag": "path_constraint", "description": "Leyline corruption seeped into surrounding earth."})
		log_message("LEYLINE SIPHON: Siphoned power! Received 3 cards (Insight x2, Sun-Gem), BUT land became Blighted Soil!")
		_refresh_unified_events()

	# --- EXPERIMENT 1 ACTIONS ---
	elif action_id == "exp1_craft_wand":
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
	if game_over:
		return

	# 1. Resolve all staged event actions
	var staged_resolutions = []
	for event_inst in events_container.get_children():
		var staged_action = event_inst.get_staged_action_id()
		if staged_action != "":
			staged_resolutions.append({"event": event_inst, "action_id": staged_action})

	for res in staged_resolutions:
		if is_instance_valid(res["event"]):
			_on_event_action_triggered(res["event"], res["action_id"])

	# 2. Process decaying cards in tableau
	process_card_expiry()

	current_turn += 1
	log_message("\nAdvanced to Turn " + str(current_turn) + ".")

	# Unified Game Run Escalation
	if active_experiment == 10:
		if not unified_blight_resolved:
			if unified_blight_stage == 1:
				unified_blight_stage = 2
				log_message("WORLD EVOLUTION: Crop Blight was neglected! It has spread into SEVERE Blight!")
			elif unified_blight_stage == 2:
				unified_blight_stage = 3
				village_unrest += 2
				add_card_to_inventory({"id": "villager_grievance", "title": "Villager Grievance", "tag": "grievance", "description": "Villagers suffer famine and blame you."})
				log_message("WORLD EVOLUTION: Severe Blight resulted in Crop Rot & Famine! (+2 Village Unrest).")

		if not unified_merchant_resolved and unified_merchant_stage == 1:
			unified_merchant_stage = 2
			log_message("WORLD EVOLUTION: Wandering Merchant's Sun-Gem was bought by a rival!")

		if unified_child_active and not unified_child_resolved:
			village_unrest += 1
			add_card_to_inventory({"id": "villager_grievance", "title": "Villager Grievance", "tag": "grievance", "description": "Mother holds a grievance for your neglect."})
			log_message("WORLD EVOLUTION: Distraught mother holds a grievance against you! (+1 Village Unrest).")
			unified_child_resolved = true

		if unified_smith_active and not unified_smith_resolved:
			village_unrest += 1
			add_card_to_inventory({"id": "resentful_blacksmith", "title": "Resentful Blacksmith", "tag": "grievance", "description": "Blacksmith's forge was damaged."})
			log_message("WORLD EVOLUTION: Blacksmith's forge was damaged! (+1 Village Unrest).")
			unified_smith_resolved = true

		_check_unified_win_loss()
		_refresh_unified_events()

	# Legacy Gathering Task
	elif active_experiment == 0 and gathering_task_active:
		gathering_turns_remaining -= 1
		if gathering_turns_remaining <= 0:
			gathering_task_active = false
			log_message("Task Completed: Gathering Herbs complete!")
			add_card_to_inventory({"id": "medicinal_herb", "title": "Medicinal Herb", "tag": "herb", "description": "Healing plant."})
			_spawn_legacy_stage_c_poultice()
		else:
			log_message("Task Progress: Gathering Herbs in progress... (" + str(gathering_turns_remaining) + " turns remaining).")

	# Experiment 2 Escalation Engine
	elif active_experiment == 2:
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
