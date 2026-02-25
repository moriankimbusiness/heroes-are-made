extends RefCounted
class_name EquipmentState

const ItemEnumsRef = preload("res://scripts/items/ItemEnums.gd")

signal changed(slot: int, item: ItemData)

var _slots: Dictionary = {}


func _init() -> void:
	for slot: int in ItemEnumsRef.all_equip_slots():
		_slots[slot] = null


func get_item(slot: int) -> ItemData:
	if not _slots.has(slot):
		return null
	return _slots[slot]


func set_item(slot: int, item: ItemData) -> void:
	if not _slots.has(slot):
		return
	_slots[slot] = item
	changed.emit(slot, item)


func remove_item(slot: int) -> ItemData:
	if not _slots.has(slot):
		return null
	var existing: ItemData = _slots[slot]
	_slots[slot] = null
	changed.emit(slot, null)
	return existing


func get_all_slots() -> Array[int]:
	return ItemEnumsRef.all_equip_slots()
