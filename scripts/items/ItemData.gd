extends Resource
class_name ItemData

const ItemEnumsRef = preload("res://scripts/items/ItemEnums.gd")

@export var item_id: StringName = &""
@export var display_name: String = ""
@export var item_type: int = ItemEnumsRef.ItemType.WEAPON
@export_range(-999, 999, 1) var strength_bonus: int = 0
@export_range(-999, 999, 1) var agility_bonus: int = 0
@export_range(-999, 999, 1) var intelligence_bonus: int = 0
@export_range(-999.0, 9999.0, 0.1) var physical_attack_bonus: float = 0.0
@export_range(-999.0, 9999.0, 0.1) var magic_attack_bonus: float = 0.0
@export_range(0, 99, 1) var enhance_level: int = 0


func duplicate_item() -> ItemData:
	return duplicate(true) as ItemData


func can_combine_with(other: ItemData) -> bool:
	if other == null:
		return false
	if item_id == StringName():
		return false
	return item_id == other.item_id and item_type == other.item_type
