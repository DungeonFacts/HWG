class_name CardUI
extends PanelContainer

signal card_selected(card_ui: CardUI)

var card_data: Dictionary = {}
var is_selected: bool = false
var is_in_slot: bool = false

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var tag_label: Label = $MarginContainer/VBoxContainer/TagLabel
@onready var expiry_label: Label = get_node_or_null("MarginContainer/VBoxContainer/ExpiryLabel")

func setup(p_card_data: Dictionary, p_in_slot: bool = false) -> void:
	card_data = p_card_data
	is_in_slot = p_in_slot
	update_ui()

func update_ui() -> void:
	if not is_inside_tree():
		await ready
	if card_data.is_empty():
		title_label.text = ""
		tag_label.text = ""
		tooltip_text = ""
		return

	var title_text = card_data.get("title", "Unknown Card")
	if card_data.get("is_locked", false):
		title_text += " [LOCKED]"
	title_label.text = title_text

	tag_label.text = "[" + card_data.get("tag", "item").capitalize() + "]"

	if expiry_label:
		if card_data.has("expires_in_turns") and card_data["expires_in_turns"] >= 0:
			expiry_label.visible = true
			expiry_label.text = "Expires: " + str(card_data["expires_in_turns"]) + "t"
		else:
			expiry_label.visible = false

	# Tooltip contains full description and tags
	var tooltip_content = title_text + "\nTag: " + card_data.get("tag", "item") + "\n"
	if card_data.has("expires_in_turns"):
		tooltip_content += "Expires in: " + str(card_data["expires_in_turns"]) + " turn(s)\n"
	tooltip_content += "\n" + card_data.get("description", "")
	tooltip_text = tooltip_content

	_update_style()

func set_selected(selected: bool) -> void:
	is_selected = selected
	_update_style()

func _update_style() -> void:
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8

	if is_selected:
		style.bg_color = Color(0.25, 0.45, 0.65)
		style.border_color = Color(0.9, 0.8, 0.3)
		style.set_border_width_all(3)
	elif is_in_slot:
		style.bg_color = Color(0.2, 0.3, 0.25)
		style.border_color = Color(0.4, 0.7, 0.5)
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.18, 0.22, 0.28)
		style.border_color = Color(0.35, 0.4, 0.5)
		style.set_border_width_all(2)

	add_theme_stylebox_override("panel", style)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		card_selected.emit(self)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if is_in_slot:
		return null
	var drag_preview = PanelContainer.new()
	var label = Label.new()
	label.text = card_data.get("title", "Card")
	drag_preview.add_child(label)
	set_drag_preview(drag_preview)
	card_selected.emit(self)
	return {
		"type": "card",
		"card_data": card_data,
		"source_ui": self
	}
