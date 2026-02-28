extends VBoxContainer

## 장비 상점 카드 및 리롤을 관리하는 패널입니다.

const ItemEnumsRef = preload("res://scripts/items/ItemEnums.gd")
const ItemDataRef = preload("res://scripts/items/ItemData.gd")

signal gold_changed(new_amount: int)
signal item_purchased(hero: Hero, slot: int, item: ItemData, cost: int)
signal card_hover_started(slot: int, item: ItemData)
signal card_hover_ended()

@export_group("ShopPanel 상점/리롤 설정")
## 상점 카드 호버 시 확대 배율입니다.
@export_range(1.0, 2.0, 0.05) var card_hover_scale: float = 1.3

@onready var gold_label: Label = $GoldLabel
@onready var weapon_card: Button = $CardsRow/WeaponCard
@onready var armor_card: Button = $CardsRow/ArmorCard
@onready var boots_card: Button = $CardsRow/BootsCard
@onready var reroll_button: Button = $"../RerollColumn/RerollButton"
@onready var reroll_count_label: Label = $"../RerollColumn/RerollCountLabel"
@onready var reroll_cost_label: Label = $"../RerollColumn/RerollCostLabel"

var _bound_hero: Hero = null
var _draw_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _economy: Node = null

var _card_buttons: Dictionary = {}
var _shop_cards: Dictionary = {}


func _ready() -> void:
	_draw_rng.randomize()
	_card_buttons = {
		ItemEnumsRef.EquipSlot.WEAPON: weapon_card,
		ItemEnumsRef.EquipSlot.ARMOR: armor_card,
		ItemEnumsRef.EquipSlot.BOOTS: boots_card
	}
	_connect_card_signals()
	reroll_button.pressed.connect(_on_reroll_button_pressed)
	_generate_shop_cards()
	_refresh_all()


func bind_hero(hero: Hero) -> void:
	_bound_hero = hero
	_refresh_all()


func unbind_hero() -> void:
	_bound_hero = null
	_refresh_all()


func bind_economy(economy: Node) -> void:
	_disconnect_economy_signals()
	_economy = economy
	if _economy != null:
		var on_gold_changed: Callable = Callable(self, "_on_economy_gold_changed")
		if _economy.has_signal("gold_changed") and not _economy.is_connected("gold_changed", on_gold_changed):
			_economy.connect("gold_changed", on_gold_changed)
		var on_reroll_state_changed: Callable = Callable(self, "_on_economy_reroll_state_changed")
		if _economy.has_signal("reroll_state_changed") and not _economy.is_connected("reroll_state_changed", on_reroll_state_changed):
			_economy.connect("reroll_state_changed", on_reroll_state_changed)
	_generate_shop_cards()
	_refresh_all()


func set_gold(amount: int) -> void:
	if _economy != null and _economy.has_method("set_starting_gold"):
		_economy.call("set_starting_gold", amount)
	else:
		gold_changed.emit(maxi(0, amount))
	_generate_shop_cards()
	_refresh_all()


func get_gold() -> int:
	if _economy == null:
		return 0
	if not _economy.has_method("get_gold"):
		return 0
	return int(_economy.call("get_gold"))


func _connect_card_signals() -> void:
	for slot: int in _card_buttons.keys():
		var button: Button = _card_buttons[slot]
		button.pressed.connect(_on_shop_card_pressed.bind(slot))
		button.mouse_entered.connect(_on_card_mouse_entered.bind(slot))
		button.mouse_exited.connect(_on_card_mouse_exited.bind(slot))


func _disconnect_economy_signals() -> void:
	if _economy == null:
		return
	var on_gold_changed: Callable = Callable(self, "_on_economy_gold_changed")
	if _economy.has_signal("gold_changed") and _economy.is_connected("gold_changed", on_gold_changed):
		_economy.disconnect("gold_changed", on_gold_changed)
	var on_reroll_state_changed: Callable = Callable(self, "_on_economy_reroll_state_changed")
	if _economy.has_signal("reroll_state_changed") and _economy.is_connected("reroll_state_changed", on_reroll_state_changed):
		_economy.disconnect("reroll_state_changed", on_reroll_state_changed)


func _on_economy_gold_changed(new_amount: int) -> void:
	gold_changed.emit(new_amount)
	_refresh_all()


func _on_economy_reroll_state_changed(_free_remaining: int, _free_total: int, _current_cost: int) -> void:
	_refresh_all()


func _exit_tree() -> void:
	_disconnect_economy_signals()


func _generate_shop_cards() -> void:
	_shop_cards.clear()
	for slot: int in ItemEnumsRef.all_equip_slots():
		var item: ItemData = _roll_item_for_slot(slot)
		_shop_cards[slot] = {
			"item": item,
			"cost": _get_item_cost(item),
			"purchased": false
		}


func _roll_item_for_slot(slot: int) -> ItemData:
	var item_db: Node = _get_item_database()
	if item_db == null:
		return null
	if not bool(item_db.call("is_ready")):
		return null
	var item_type: int = _item_type_for_slot(slot)
	return item_db.call("roll_draw_item_for_type", _draw_rng, item_type) as ItemData


func _get_item_database() -> Node:
	return get_tree().root.get_node_or_null("ItemDatabase")


func _item_type_for_slot(slot: int) -> int:
	match slot:
		ItemEnumsRef.EquipSlot.ARMOR:
			return ItemEnumsRef.ItemType.ARMOR
		ItemEnumsRef.EquipSlot.BOOTS:
			return ItemEnumsRef.ItemType.BOOTS
		_:
			return ItemEnumsRef.ItemType.WEAPON


func _get_item_cost(item: ItemData) -> int:
	if item == null:
		return 0
	match item.tier:
		ItemDataRef.ItemTier.COMMON:
			return 20
		ItemDataRef.ItemTier.UNCOMMON:
			return 30
		ItemDataRef.ItemTier.RARE:
			return 45
		ItemDataRef.ItemTier.EPIC:
			return 65
		ItemDataRef.ItemTier.LEGENDARY:
			return 90
		_:
			return 25


func _on_shop_card_pressed(slot: int) -> void:
	if _bound_hero == null or not is_instance_valid(_bound_hero):
		return
	var card: Dictionary = _shop_cards.get(slot, {})
	if card.is_empty():
		return
	if bool(card.get("purchased", false)):
		return
	var item: ItemData = card.get("item") as ItemData
	if item == null:
		return
	var cost: int = int(card.get("cost", 0))
	if _economy == null:
		return
	if not _economy.has_method("can_afford"):
		return
	if not bool(_economy.call("can_afford", cost)):
		_flash_gold_insufficient()
		return
	if not _bound_hero.can_equip_item(slot, item):
		return
	if not _bound_hero.equip_item(slot, item):
		return
	if not _economy.has_method("try_spend_gold"):
		return
	if not bool(_economy.call("try_spend_gold", cost)):
		_flash_gold_insufficient()
		return
	card["purchased"] = true
	_shop_cards[slot] = card
	item_purchased.emit(_bound_hero, slot, item, cost)
	_refresh_all()


func _on_reroll_button_pressed() -> void:
	if _economy == null:
		return
	if not _economy.has_method("try_consume_reroll"):
		return
	if not bool(_economy.call("try_consume_reroll")):
		_flash_gold_insufficient()
		return
	_generate_shop_cards()
	_refresh_all()


func _get_current_reroll_cost() -> int:
	if _economy == null:
		return 0
	if not _economy.has_method("get_current_reroll_cost"):
		return 0
	return int(_economy.call("get_current_reroll_cost"))


func _on_card_mouse_entered(slot: int) -> void:
	var button: Button = _card_buttons.get(slot) as Button
	if button == null:
		return
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2.ONE * card_hover_scale
	var card: Dictionary = _shop_cards.get(slot, {})
	if not card.is_empty() and not bool(card.get("purchased", false)):
		var item: ItemData = card.get("item") as ItemData
		if item != null:
			card_hover_started.emit(slot, item)


func _on_card_mouse_exited(slot: int) -> void:
	var button: Button = _card_buttons.get(slot) as Button
	if button == null:
		return
	button.scale = Vector2.ONE
	card_hover_ended.emit()


func _refresh_all() -> void:
	_refresh_gold_and_reroll_labels()
	_refresh_card_buttons()


func _refresh_gold_and_reroll_labels() -> void:
	var current_gold: int = get_gold()
	gold_label.text = "골드: %d" % current_gold
	gold_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var free_remaining: int = 0
	var free_total: int = 0
	if _economy != null:
		if _economy.has_method("get_free_reroll_remaining"):
			free_remaining = int(_economy.call("get_free_reroll_remaining"))
		if _economy.has_method("get_free_reroll_uses"):
			free_total = int(_economy.call("get_free_reroll_uses"))
	reroll_count_label.text = "무료 리롤: %d/%d" % [free_remaining, free_total]
	var reroll_cost: int = _get_current_reroll_cost()
	if reroll_cost <= 0:
		reroll_cost_label.text = "현재 비용: 무료"
	else:
		reroll_cost_label.text = "현재 비용: %dG" % reroll_cost
	reroll_button.disabled = _economy == null


func _refresh_card_buttons() -> void:
	for slot: int in _card_buttons.keys():
		var button: Button = _card_buttons[slot]
		button.scale = Vector2.ONE
		var card: Dictionary = _shop_cards.get(slot, {})
		if card.is_empty():
			button.text = "%s\n(없음)" % ItemEnumsRef.equip_slot_label(slot)
			button.disabled = true
			continue
		var item: ItemData = card.get("item") as ItemData
		var purchased: bool = bool(card.get("purchased", false))
		if item == null:
			button.text = "%s\n(아이템 없음)" % ItemEnumsRef.equip_slot_label(slot)
			button.disabled = true
			continue
		var title: String = item.display_name if not item.display_name.is_empty() else String(item.item_id)
		var prefix: String = "[구매완료]\n" if purchased else ""
		var cost: int = int(card.get("cost", 0))
		button.text = "%s%s\n%s\n%dG" % [
			prefix,
			ItemEnumsRef.equip_slot_label(slot),
			title,
			cost
		]
		var hero_dead: bool = _bound_hero != null and is_instance_valid(_bound_hero) and _bound_hero.has_method("is_dead") and bool(_bound_hero.call("is_dead"))
		button.disabled = purchased or _economy == null or _bound_hero == null or not is_instance_valid(_bound_hero) or hero_dead


func _flash_gold_insufficient() -> void:
	gold_label.modulate = Color(1.0, 0.45, 0.45, 1.0)
	var base_x: float = gold_label.position.x
	var tween := create_tween()
	tween.tween_property(gold_label, "position:x", base_x + 3.0, 0.05)
	tween.tween_property(gold_label, "position:x", base_x - 3.0, 0.05)
	tween.tween_property(gold_label, "position:x", base_x, 0.05)
	tween.tween_interval(0.3)
	tween.tween_callback(func(): gold_label.modulate = Color.WHITE)
