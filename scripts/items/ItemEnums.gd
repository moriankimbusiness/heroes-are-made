extends RefCounted
class_name ItemEnums

enum ItemType {
	WEAPON,
	HELMET,
	ARMOR,
	SHIELD,
	BOOTS
}

enum EquipSlot {
	HEAD,
	LEFT_HAND,
	BODY,
	RIGHT_HAND,
	FEET
}


static func default_slot_for_item(item_type: int) -> int:
	match item_type:
		ItemType.HELMET:
			return EquipSlot.HEAD
		ItemType.ARMOR:
			return EquipSlot.BODY
		ItemType.SHIELD:
			return EquipSlot.LEFT_HAND
		ItemType.BOOTS:
			return EquipSlot.FEET
		_:
			return EquipSlot.RIGHT_HAND


static func item_type_label(item_type: int) -> String:
	match item_type:
		ItemType.WEAPON:
			return "무기"
		ItemType.HELMET:
			return "투구"
		ItemType.ARMOR:
			return "갑옷"
		ItemType.SHIELD:
			return "방패"
		ItemType.BOOTS:
			return "신발"
		_:
			return "알 수 없음"


static func equip_slot_label(slot: int) -> String:
	match slot:
		EquipSlot.HEAD:
			return "머리"
		EquipSlot.LEFT_HAND:
			return "왼손"
		EquipSlot.BODY:
			return "몸"
		EquipSlot.RIGHT_HAND:
			return "오른손"
		EquipSlot.FEET:
			return "발"
		_:
			return "미지정"


static func all_equip_slots() -> Array[int]:
	return [
		EquipSlot.HEAD,
		EquipSlot.LEFT_HAND,
		EquipSlot.BODY,
		EquipSlot.RIGHT_HAND,
		EquipSlot.FEET
	]
