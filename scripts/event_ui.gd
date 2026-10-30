class_name EventUI
extends PanelContainer

signal action_triggered(event_ui, action_id: String)
signal slot_card_changed(event_ui)
signal slot_clicked(event_ui, slot_ui)

var event_data: Dictionary = {}
var deadline_turns: int = -1 # -1 means no deadline
var is_persistent: bool = true

@onready var title_label: Label = $MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var deadline_label: Label = $MarginContainer/VBoxContainer/HeaderContainer/DeadlineLabel
@onready var desc_label: Label = $MarginContainer/VBoxContainer/DescLabel
@onready var slots_container: HBoxContainer = $MarginContainer/VBoxContainer/SlotsContainer
@onready var action_buttons_container: HBoxContainer = $MarginContainer/VBoxContainer/ActionButtonsContainer

var slot_ui_scene: PackedScene = preload("res://scenes/slot_ui.tscn")
var slot_instances: Array = []

func setup(p_event_data: Dictionary) -> void:
	# Create a deep duplicate of event data so instances do not share mutable state
	event_data = p_event_data.duplicate(true)
	deadline_turns = event_data.get("deadline", -1)
	update_ui()

func update_ui() -> void:
	if not is_inside_tree():
		await ready

	title_label.text = event_data.get("title", "Event")
	desc_label.text = event_data.get("description", "")

	if deadline_turns >= 0:
		deadline_label.visible = true
		deadline_label.text = "Deadline: " + str(deadline_turns) + " turn(s)"
		if deadline_turns == 0:
			deadline_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		else:
			deadline_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	else:
		deadline_label.visible = false

	_update_style()
	_rebuild_slots()
	_update_action_buttons()

func _update_style() -> void:
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6

	style.bg_color = Color(0.14, 0.16, 0.22)
	style.border_color = Color(0.4, 0.45, 0.55)
	style.set_border_width_all(2)

	add_theme_stylebox_override("panel", style)

func _rebuild_slots() -> void:
	# Keep existing slotted cards if re-building or setup for the first time
	var current_slotted: Dictionary = {}
	for slot_ui in slot_instances:
		if is_instance_valid(slot_ui):
			if not slot_ui.slotted_card_data.is_empty():
				current_slotted[slot_ui.slot_id] = slot_ui.slotted_card_data
			slot_ui.queue_free()
	slot_instances.clear()

	var slots_def = event_data.get("slots", [])
	for slot_def in slots_def:
		var slot_id = slot_def.get("id", "slot")
		var slot_label = slot_def.get("label", "Slot")
		var req_tag = slot_def.get("req_tag", "any")

		var slot_inst = slot_ui_scene.instantiate()
		slots_container.add_child(slot_inst)
		slot_inst.setup(slot_id, slot_label, req_tag)

		# Restore slotted card if available
		if current_slotted.has(slot_id):
			slot_inst.slot_card(current_slotted[slot_id])

		slot_inst.card_slotted.connect(_on_slot_changed)
		slot_inst.card_unslotted.connect(_on_slot_changed)
		slot_inst.slot_clicked.connect(func(s_inst): slot_clicked.emit(self, s_inst))
		slot_instances.append(slot_inst)

func _on_slot_changed(_slot_ui, _card_data: Dictionary) -> void:
	_update_action_buttons()
	slot_card_changed.emit(self)

func get_staged_action_id() -> String:
	var actions_def = event_data.get("actions", [])
	for action_def in actions_def:
		var action_id = action_def.get("id", "")
		var required_slots = action_def.get("required_slots", [])
		var can_execute = true
		for req_slot_id in required_slots:
			var found_filled = false
			for slot_inst in slot_instances:
				if slot_inst.slot_id == req_slot_id and not slot_inst.slotted_card_data.is_empty():
					found_filled = true
					break
			if not found_filled:
				can_execute = false
				break
		if can_execute and not required_slots.is_empty():
			return action_id
	return ""

func _update_action_buttons() -> void:
	for child in action_buttons_container.get_children():
		child.queue_free()

	var staged_id = get_staged_action_id()
	var actions_def = event_data.get("actions", [])
	for action_def in actions_def:
		var action_id = action_def.get("id", "act")
		var action_label = action_def.get("label", "Resolve")

		var btn = Button.new()
		if action_id == staged_id:
			btn.text = "[STAGED FOR END TURN] " + action_label
			btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		else:
			btn.text = action_label

		# Disable direct clicking during turn so resolution occurs strictly on End Turn
		btn.disabled = true
		action_buttons_container.add_child(btn)

func get_slotted_cards() -> Dictionary:
	var result = {}
	for slot_inst in slot_instances:
		result[slot_inst.slot_id] = slot_inst.slotted_card_data
	return result

func clear_all_slots() -> Array:
	var removed = []
	for slot_inst in slot_instances:
		if not slot_inst.slotted_card_data.is_empty():
			removed.append(slot_inst.clear_slot())
	return removed
