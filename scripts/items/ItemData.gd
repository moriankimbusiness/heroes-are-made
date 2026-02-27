extends Resource
class_name ItemData

const ItemEnumsRef = preload("res://scripts/items/ItemEnums.gd")

const MAX_ENHANCE_LEVEL := 15

enum ItemTier {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}
@export_group("아이템 기본 정보")
@export var item_id: StringName = &""
@export var display_name: String = ""
@export var item_type: int = ItemEnumsRef.ItemType.WEAPON
@export var tier: int = ItemTier.COMMON
@export_group("아이템 스탯 보너스")
@export_range(-999, 999, 1) var strength_bonus: int = 0
@export_range(-999, 999, 1) var agility_bonus: int = 0
@export_range(-999, 999, 1) var intelligence_bonus: int = 0
@export_range(-999.0, 9999.0, 0.1) var physical_attack_bonus: float = 0.0
@export_range(-999.0, 9999.0, 0.1) var magic_attack_bonus: float = 0.0
@export_group("강화")
@export_range(0, MAX_ENHANCE_LEVEL, 1) var enhance_level: int = 0


func duplicate_item() -> ItemData:
	return duplicate(true) as ItemData


func can_combine_with(other: ItemData) -> bool:
	if other == null:
		return false
	if item_id == StringName():
		return false
	if enhance_level >= MAX_ENHANCE_LEVEL:
		return false
	return item_id == other.item_id and item_type == other.item_type and enhance_level == other.enhance_level


static func tier_label(value: int) -> String:
	match value:
		ItemTier.COMMON:
			return "일반"
		ItemTier.UNCOMMON:
			return "고급"
		ItemTier.RARE:
			return "희귀"
		ItemTier.EPIC:
			return "영웅"
		ItemTier.LEGENDARY:
			return "전설"
		_:
			return "미지정"
