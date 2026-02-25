extends PanelContainer
class_name ItemSlotUI

const ItemEnumsRef = preload("res://scripts/items/ItemEnums.gd")

signal slot_clicked(slot_kind: String, slot_index: int)
signal slot_hover_started(slot_kind: String, slot_index: int)
signal slot_hover_ended(slot_kind: String, slot_index: int)
signal slot_drop_requested(source_kind: String, source_index: int, target_kind: String, target_index: int)
signal slot_drag_started
signal slot_drag_ended

const SLOT_KIND_INVENTORY := "inventory"
const SLOT_KIND_EQUIPMENT := "equipment"

const FEEDBACK_NONE := 0
const FEEDBACK_OK := 1
const FEEDBACK_FAIL := 2

@export_enum("inventory", "equipment") var slot_kind: String = SLOT_KIND_INVENTORY
@export var slot_index: int = -1
@export var empty_label_text: String = ""

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var level_label: Label = $MarginContainer/VBoxContainer/LevelLabel

var item: ItemData = null

var _style_box: StyleBoxFlat = null
var _hovered: bool = false
var _pressed: bool = false
var _drag_started_this_press: bool = false
var _drag_feedback_state: int = FEEDBACK_NONE


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_style_box = StyleBoxFlat.new()
	_style_box.bg_color = Color(0.06, 0.07, 0.09, 0.85)
	_style_box.border_width_left = 2
	_style_box.border_width_top = 2
	_style_box.border_width_right = 2
	_style_box.border_width_bottom = 2
	_style_box.corner_radius_top_left = 4
	_style_box.corner_radius_top_right = 4
	_style_box.corner_radius_bottom_right = 4
	_style_box.corner_radius_bottom_left = 4
	add_theme_stylebox_override("panel", _style_box)
	set_item(null)
	_clear_drag_feedback()


func set_item(new_item: ItemData) -> void:
	item = new_item
	if item == null:
		name_label.text = empty_label_text
		level_label.text = ""
	else:
		var title := item.display_name
		if title.is_empty():
			title = String(item.item_id)
		name_label.text = title
		level_label.text = "+%d" % item.enhance_level if item.enhance_level > 0 else ""


func clear_drag_feedback() -> void:
	_clear_drag_feedback()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item == null:
		return null
	_drag_started_this_press = true
	slot_drag_started.emit()
	var preview := Label.new()
	preview.text = name_label.text
	preview.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	preview.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	preview.add_theme_constant_override("outline_size", 4)
	set_drag_preview(preview)
	return {
		"source_kind": slot_kind,
		"source_index": slot_index,
		"item": item
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var source_kind: String = str(data.get("source_kind", ""))
	var source_index: int = int(data.get("source_index", -1))
	if not data.get("item") is ItemData:
		return false
	var source_item: ItemData = data.get("item")
	if source_item == null:
		return false

	if slot_kind == SLOT_KIND_INVENTORY:
		return _can_drop_to_inventory(source_kind, source_index, source_item)
	if slot_kind == SLOT_KIND_EQUIPMENT:
		return _can_drop_to_equipment(source_kind, source_index, source_item)
	return false


func _can_drop_to_inventory(source_kind: String, source_index: int, source_item: ItemData) -> bool:
	if source_kind == SLOT_KIND_INVENTORY:
		if source_index == slot_index:
			return false
		if item != null:
			if item.can_combine_with(source_item):
				_set_drag_feedback(FEEDBACK_OK)
			else:
				_set_drag_feedback(FEEDBACK_FAIL)
		else:
			_set_drag_feedback(FEEDBACK_NONE)
		return true

	if source_kind == SLOT_KIND_EQUIPMENT:
		if item == null:
			_set_drag_feedback(FEEDBACK_NONE)
			return true
		var can_swap_back: bool = ItemEnumsRef.default_slot_for_item(item.item_type) == source_index
		if can_swap_back:
			_set_drag_feedback(FEEDBACK_OK)
		else:
			_set_drag_feedback(FEEDBACK_FAIL)
		return can_swap_back

	return false


func _can_drop_to_equipment(source_kind: String, _source_index: int, source_item: ItemData) -> bool:
	if source_kind != SLOT_KIND_INVENTORY:
		return false
	var is_match: bool = ItemEnumsRef.default_slot_for_item(source_item.item_type) == slot_index
	if is_match:
		_set_drag_feedback(FEEDBACK_OK)
	else:
		_set_drag_feedback(FEEDBACK_FAIL)
	return is_match


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var source_kind: String = str(data.get("source_kind", ""))
	var source_index: int = int(data.get("source_index", -1))
	slot_drop_requested.emit(source_kind, source_index, slot_kind, slot_index)
	_clear_drag_feedback()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_pressed = true
			_drag_started_this_press = false
		else:
			if _pressed and not _drag_started_this_press:
				slot_clicked.emit(slot_kind, slot_index)
			_pressed = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_pressed = false
		_drag_started_this_press = false
		_clear_drag_feedback()
		slot_drag_ended.emit()


func _on_mouse_entered() -> void:
	_hovered = true
	slot_hover_started.emit(slot_kind, slot_index)
	if _drag_feedback_state == FEEDBACK_NONE:
		_update_border_color()


func _on_mouse_exited() -> void:
	_hovered = false
	slot_hover_ended.emit(slot_kind, slot_index)
	_clear_drag_feedback()


func _set_drag_feedback(state: int) -> void:
	_drag_feedback_state = state
	_update_border_color()


func _clear_drag_feedback() -> void:
	_drag_feedback_state = FEEDBACK_NONE
	_update_border_color()


func _update_border_color() -> void:
	if _style_box == null:
		return
	match _drag_feedback_state:
		FEEDBACK_OK:
			_style_box.border_color = Color(0.32, 1.0, 0.45, 1.0)
		FEEDBACK_FAIL:
			_style_box.border_color = Color(1.0, 0.34, 0.34, 1.0)
		_:
			if _hovered:
				_style_box.border_color = Color(1.0, 1.0, 1.0, 1.0)
			else:
				_style_box.border_color = Color(0.42, 0.45, 0.5, 1.0)
