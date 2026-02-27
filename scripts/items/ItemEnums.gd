extends RefCounted
class_name ItemEnums

enum ItemType {
	WEAPON,
	ARMOR,
	BOOTS
}

enum EquipSlot {
	WEAPON,
	ARMOR,
	BOOTS
}


static func default_slot_for_item(item_type: int) -> int:
	match item_type:
		ItemType.WEAPON:
			return EquipSlot.WEAPON
		ItemType.ARMOR:
			return EquipSlot.ARMOR
		ItemType.BOOTS:
			return EquipSlot.BOOTS
		_:
			return EquipSlot.WEAPON


static func item_type_label(item_type: int) -> String:
	match item_type:
		ItemType.WEAPON:
			return "무기"
		ItemType.ARMOR:
			return "방어구"
		ItemType.BOOTS:
			return "신발"
		_:
			return "알 수 없음"


static func equip_slot_label(slot: int) -> String:
	match slot:
		EquipSlot.WEAPON:
			return "무기"
		EquipSlot.ARMOR:
			return "방어구"
		EquipSlot.BOOTS:
			return "신발"
		_:
			return "미지정"


static func all_equip_slots() -> Array[int]:
	return [
		EquipSlot.WEAPON,
		EquipSlot.ARMOR,
		EquipSlot.BOOTS
	]
