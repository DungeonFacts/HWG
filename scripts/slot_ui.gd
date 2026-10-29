class_name SlotUI
extends PanelContainer

signal card_slotted(slot_ui, card_data: Dictionary)
signal card_unslotted(slot_ui, card_data: Dictionary)
signal slot_clicked(slot_ui)

var slot_id: String = ""
var required_tag: String = "any"
var slot_label_text: String = "Slot"
var slotted_card_data: Dictionary = {}

@onready var slot_title_label: Label = $MarginContainer/VBoxContainer/SlotTitleLabel
@onready var req_label: Label = $MarginContainer/VBoxContainer/ReqLabel
@onready var card_container: MarginContainer = $MarginContainer/VBoxContainer/CardContainer
@onready var clear_button: Button = $MarginContainer/VBoxContainer/ClearButton

var card_ui_scene: PackedScene = preload("res://scenes/card_ui.tscn")
var slotted_card_instance = null

func setup(p_slot_id: String, p_label: String, p_required_tag: String = "any") -> void:
	slot_id = p_slot_id
	slot_label_text = p_label
	required_tag = p_required_tag
	update_ui()

func update_ui() -> void:
	if not is_inside_tree():
		await ready

	slot_title_label.text = slot_label_text
	req_label.text = "Requires: [" + required_tag.capitalize() + "]"

	_update_style()

	# Clear previous instance
	if slotted_card_instance != null and is_instance_valid(slotted_card_instance):
		slotted_card_instance.queue_free()
		slotted_card_instance = null

	if slotted_card_data.is_empty():
		card_container.visible = false
		clear_button.visible = false
		req_label.visible = true
	else:
		card_container.visible = true
		clear_button.visible = true
		req_label.visible = false

		var card_inst = card_ui_scene.instantiate()
		card_container.add_child(card_inst)
		card_inst.setup(slotted_card_data, true)
		slotted_card_instance = card_inst

func _update_style() -> void:
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6

	if slotted_card_data.is_empty():
		style.bg_color = Color(0.12, 0.14, 0.18, 0.8)
		style.border_color = Color(0.3, 0.35, 0.45)
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.15, 0.22, 0.2)
		style.border_color = Color(0.3, 0.6, 0.4)
		style.set_border_width_all(2)

	add_theme_stylebox_override("panel", style)

func accepts_card(card_data: Dictionary) -> bool:
	if not slotted_card_data.is_empty():
		return false
	if required_tag == "any":
		return true
	var card_tag = card_data.get("tag", "")
	if card_tag == required_tag:
		return true
	var tags = card_data.get("tags", [])
	if required_tag in tags:
		return true
	return false

func slot_card(card_data: Dictionary) -> bool:
	if not accepts_card(card_data):
		return false
	slotted_card_data = card_data
	update_ui()
	card_slotted.emit(self, card_data)
	return true

func clear_slot() -> Dictionary:
	if slotted_card_data.is_empty():
		return {}
	var removed_card = slotted_card_data
	slotted_card_data = {}
	update_ui()
	card_unslotted.emit(self, removed_card)
	return removed_card

func _on_clear_button_pressed() -> void:
	clear_slot()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		slot_clicked.emit(self)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.get("type") == "card":
		return accepts_card(data.get("card_data", {}))
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.get("type") == "card":
		var card_data = data.get("card_data", {})
		slot_card(card_data)
