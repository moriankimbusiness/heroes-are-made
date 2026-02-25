extends Node

const ItemDataRef = preload("res://scripts/items/ItemData.gd")
const ItemEnumsRef = preload("res://scripts/items/ItemEnums.gd")

const ITEM_TABLE_PATH := "res://assets/data/items/item_table.json"
const ENHANCE_ATTACK_MULTIPLIERS: Array[float] = [
	1.0, 1.12, 1.26, 1.42, 1.60, 1.80, 2.02, 2.26,
	2.52, 2.80, 3.10, 3.42, 3.76, 4.12, 4.50, 4.90
]
const ENHANCE_STAT_MULTIPLIERS: Array[float] = [
	1.0, 1.05, 1.10, 1.16, 1.22, 1.29, 1.36, 1.44,
	1.52, 1.61, 1.70, 1.80, 1.91, 2.02, 2.14, 2.26
]

var _items_by_id: Dictionary = {}
var _draw_pool: Array[Dictionary] = []
var _starter_inventory_item_ids: Array[StringName] = []
var _is_ready: bool = false


func _ready() -> void:
	_is_ready = _load_from_json()


func is_ready() -> bool:
	return _is_ready


func get_item(item_id: StringName) -> ItemData:
	if not _items_by_id.has(item_id):
		return null
	return _items_by_id[item_id] as ItemData


func create_item_instance_by_id(item_id: StringName) -> ItemData:
	var template: ItemData = get_item(item_id)
	if template == null:
		return null
	return template.duplicate_item()


func get_starter_inventory_item_ids() -> Array[StringName]:
	return _starter_inventory_item_ids.duplicate()


func get_max_enhance_level() -> int:
	return ItemDataRef.MAX_ENHANCE_LEVEL


func get_enhance_attack_multiplier(level: int) -> float:
	return _get_multiplier_from_table(ENHANCE_ATTACK_MULTIPLIERS, level, 0.12)


func get_enhance_stat_multiplier(level: int) -> float:
	return _get_multiplier_from_table(ENHANCE_STAT_MULTIPLIERS, level, 0.05)


func roll_draw_item(rng: RandomNumberGenerator) -> ItemData:
	if not _is_ready:
		return null
	if _draw_pool.is_empty():
		return null
	var total_weight: float = 0.0
	for entry: Dictionary in _draw_pool:
		total_weight += float(entry["weight"])
	if total_weight <= 0.0:
		return null

	var picker: RandomNumberGenerator = rng
	if picker == null:
		picker = RandomNumberGenerator.new()
		picker.randomize()

	var roll: float = picker.randf() * total_weight
	var cumulative: float = 0.0
	for entry: Dictionary in _draw_pool:
		cumulative += float(entry["weight"])
		if roll <= cumulative:
			var selected: ItemData = entry["item"] as ItemData
			return selected.duplicate_item() if selected != null else null

	var fallback: ItemData = _draw_pool.back()["item"] as ItemData
	return fallback.duplicate_item() if fallback != null else null


func _load_from_json() -> bool:
	if not FileAccess.file_exists(ITEM_TABLE_PATH):
		return _fatal("Missing item table: %s" % ITEM_TABLE_PATH)

	var file: FileAccess = FileAccess.open(ITEM_TABLE_PATH, FileAccess.READ)
	if file == null:
		return _fatal("Failed to open item table: %s (error=%d)" % [ITEM_TABLE_PATH, FileAccess.get_open_error()])

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fatal("Invalid JSON root. Dictionary expected.")
	var root: Dictionary = parsed

	_items_by_id.clear()
	_draw_pool.clear()
	_starter_inventory_item_ids.clear()

	if not _parse_items(root):
		return false
	if not _parse_draw_pool(root):
		return false
	if not _parse_starter_inventory(root):
		return false

	return true


func _parse_items(root: Dictionary) -> bool:
	if not root.has("items"):
		return _fatal("Missing required key: items")
	if typeof(root["items"]) != TYPE_ARRAY:
		return _fatal("items must be an array")
	var items: Array = root["items"]
	if items.is_empty():
		return _fatal("items must not be empty")

	for i: int in items.size():
		var raw_item: Variant = items[i]
		var context := "items[%d]" % i
		if typeof(raw_item) != TYPE_DICTIONARY:
			return _fatal("%s must be a dictionary" % context)
		var item_dict: Dictionary = raw_item

		if not item_dict.has("id") or typeof(item_dict["id"]) != TYPE_STRING:
			return _fatal("%s.id must be a string" % context)
		var item_id_text: String = String(item_dict["id"]).strip_edges()
		if item_id_text.is_empty():
			return _fatal("%s.id must not be empty" % context)
		var item_id := StringName(item_id_text)
		if _items_by_id.has(item_id):
			return _fatal("Duplicate item id: %s" % item_id_text)

		if not item_dict.has("name") or typeof(item_dict["name"]) != TYPE_STRING:
			return _fatal("%s.name must be a string" % context)

		if not item_dict.has("type") or typeof(item_dict["type"]) != TYPE_STRING:
			return _fatal("%s.type must be a string" % context)
		var item_type: int = _resolve_item_type(String(item_dict["type"]), context)
		if item_type < 0:
			return false
		if not item_dict.has("tier") or typeof(item_dict["tier"]) != TYPE_STRING:
			return _fatal("%s.tier must be a string" % context)
		var tier: int = _resolve_item_tier(String(item_dict["tier"]), context)
		if tier < 0:
			return false

		var item := ItemDataRef.new() as ItemData
		item.item_id = item_id
		item.display_name = String(item_dict["name"])
		item.item_type = item_type
		item.tier = tier

		if item_dict.has("str"):
			var strength_value: Variant = item_dict["str"]
			if typeof(strength_value) != TYPE_INT and typeof(strength_value) != TYPE_FLOAT:
				return _fatal("%s.str must be a number" % context)
			item.strength_bonus = int(roundi(float(strength_value)))
		if item_dict.has("agi"):
			var agility_value: Variant = item_dict["agi"]
			if typeof(agility_value) != TYPE_INT and typeof(agility_value) != TYPE_FLOAT:
				return _fatal("%s.agi must be a number" % context)
			item.agility_bonus = int(roundi(float(agility_value)))
		if item_dict.has("int"):
			var intelligence_value: Variant = item_dict["int"]
			if typeof(intelligence_value) != TYPE_INT and typeof(intelligence_value) != TYPE_FLOAT:
				return _fatal("%s.int must be a number" % context)
			item.intelligence_bonus = int(roundi(float(intelligence_value)))
		if item_dict.has("patk"):
			var physical_value: Variant = item_dict["patk"]
			if typeof(physical_value) != TYPE_INT and typeof(physical_value) != TYPE_FLOAT:
				return _fatal("%s.patk must be a number" % context)
			item.physical_attack_bonus = float(physical_value)
		if item_dict.has("matk"):
			var magic_value: Variant = item_dict["matk"]
			if typeof(magic_value) != TYPE_INT and typeof(magic_value) != TYPE_FLOAT:
				return _fatal("%s.matk must be a number" % context)
			item.magic_attack_bonus = float(magic_value)

		_items_by_id[item_id] = item

	return true


func _parse_draw_pool(root: Dictionary) -> bool:
	if not root.has("pool"):
		return _fatal("Missing required key: pool")
	if typeof(root["pool"]) != TYPE_ARRAY:
		return _fatal("pool must be an array")
	var draw_pool_raw: Array = root["pool"]
	if draw_pool_raw.is_empty():
		return _fatal("pool must not be empty")

	for i: int in draw_pool_raw.size():
		var raw_entry: Variant = draw_pool_raw[i]
		var context := "pool[%d]" % i
		if typeof(raw_entry) != TYPE_DICTIONARY:
			return _fatal("%s must be a dictionary" % context)
		var entry: Dictionary = raw_entry

		if not entry.has("id") or typeof(entry["id"]) != TYPE_STRING:
			return _fatal("%s.id must be a string" % context)
		var item_id := StringName(String(entry["id"]).strip_edges())
		if item_id == StringName():
			return _fatal("%s.id must not be empty" % context)
		var item: ItemData = get_item(item_id)
		if item == null:
			return _fatal("%s references unknown id: %s" % [context, String(item_id)])

		if not entry.has("w"):
			return _fatal("%s.w is required" % context)
		var weight_value: Variant = entry["w"]
		if typeof(weight_value) != TYPE_INT and typeof(weight_value) != TYPE_FLOAT:
			return _fatal("%s.w must be a number" % context)
		var weight: float = float(weight_value)
		if weight <= 0.0:
			return _fatal("%s.w must be greater than 0" % context)

		_draw_pool.append({
			"item": item,
			"weight": weight
		})

	return true


func _parse_starter_inventory(root: Dictionary) -> bool:
	if not root.has("start"):
		return true
	if typeof(root["start"]) != TYPE_ARRAY:
		return _fatal("start must be an array")

	var starter_raw: Array = root["start"]
	for i: int in starter_raw.size():
		var item_id_value: Variant = starter_raw[i]
		var context := "start[%d]" % i
		if typeof(item_id_value) != TYPE_STRING:
			return _fatal("%s must be a string item id" % context)
		var item_id := StringName(String(item_id_value).strip_edges())
		if item_id == StringName():
			return _fatal("%s must not be empty" % context)
		if get_item(item_id) == null:
			return _fatal("%s references unknown item_id: %s" % [context, String(item_id)])
		_starter_inventory_item_ids.append(item_id)

	return true


func _resolve_item_type(item_type_name: String, context: String) -> int:
	match item_type_name.strip_edges().to_upper():
		"WEAPON":
			return ItemEnumsRef.ItemType.WEAPON
		"HELMET":
			return ItemEnumsRef.ItemType.HELMET
		"ARMOR":
			return ItemEnumsRef.ItemType.ARMOR
		"SHIELD":
			return ItemEnumsRef.ItemType.SHIELD
		"BOOTS":
			return ItemEnumsRef.ItemType.BOOTS
		_:
			_fatal("%s.type is invalid: %s" % [context, item_type_name])
			return -1


func _resolve_item_tier(tier_name: String, context: String) -> int:
	match tier_name.strip_edges().to_lower():
		"common":
			return ItemDataRef.ItemTier.COMMON
		"uncommon":
			return ItemDataRef.ItemTier.UNCOMMON
		"rare":
			return ItemDataRef.ItemTier.RARE
		"epic":
			return ItemDataRef.ItemTier.EPIC
		"legendary":
			return ItemDataRef.ItemTier.LEGENDARY
		_:
			_fatal("%s.tier is invalid: %s" % [context, tier_name])
			return -1


func _get_multiplier_from_table(table: Array[float], level: int, fallback_step: float) -> float:
	var clamped_level: int = clampi(level, 0, get_max_enhance_level())
	if table.is_empty():
		return 1.0 + float(clamped_level) * fallback_step
	var index: int = clampi(clamped_level, 0, table.size() - 1)
	return table[index]


func _fatal(message: String) -> bool:
	push_error("ItemDatabase: %s" % message)
	printerr("ItemDatabase: %s" % message)
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.quit(1)
	return false
