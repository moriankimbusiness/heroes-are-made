extends RefCounted
class_name InventoryState

signal changed

var _slot_count: int = 9
var _slots: Array[ItemData] = []


func _init(slot_count: int = 9) -> void:
	_slot_count = maxi(1, slot_count)
	_slots.resize(_slot_count)


func get_slot_count() -> int:
	return _slot_count


func get_item(index: int) -> ItemData:
	if not _is_valid_index(index):
		return null
	return _slots[index]


func set_item(index: int, item: ItemData) -> void:
	if not _is_valid_index(index):
		return
	_slots[index] = item
	changed.emit()


func remove_item(index: int) -> ItemData:
	if not _is_valid_index(index):
		return null
	var existing: ItemData = _slots[index]
	_slots[index] = null
	changed.emit()
	return existing


func find_first_empty_slot() -> int:
	for i: int in _slot_count:
		if _slots[i] == null:
			return i
	return -1


func swap_items(first_index: int, second_index: int) -> void:
	if not _is_valid_index(first_index):
		return
	if not _is_valid_index(second_index):
		return
	if first_index == second_index:
		return
	var first: ItemData = _slots[first_index]
	_slots[first_index] = _slots[second_index]
	_slots[second_index] = first
	changed.emit()


func _is_valid_index(index: int) -> bool:
	return index >= 0 and index < _slot_count
