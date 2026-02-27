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
## 초기 골드 입력이 없을 때 사용할 기본값입니다.
@export_range(0, 99999, 1) var fallback_starting_gold: int = 100
## 무료 리롤 가능 횟수입니다.
@export_range(0, 20, 1) var free_reroll_uses: int = 5

@onready var gold_label: Label = $GoldLabel
@onready var weapon_card: Button = $CardsRow/WeaponCard
@onready var armor_card: Button = $CardsRow/ArmorCard
@onready var boots_card: Button = $CardsRow/BootsCard
@onready var reroll_button: Button = $"../RerollColumn/RerollButton"
@onready var reroll_count_label: Label = $"../RerollColumn/RerollCountLabel"
@onready var reroll_cost_label: Label = $"../RerollColumn/RerollCostLabel"

var _bound_hero: Hero = null
var _draw_rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _card_buttons: Dictionary = {}
var _shop_cards: Dictionary = {}

var _current_gold: int = 0
var _free_reroll_remaining: int = 0
var _paid_reroll_count: int = 0


func _ready() -> void:
	_draw_rng.randomize()
	_card_buttons = {
		ItemEnumsRef.EquipSlot.WEAPON: weapon_card,
		ItemEnumsRef.EquipSlot.ARMOR: armor_card,
		ItemEnumsRef.EquipSlot.BOOTS: boots_card
	}
	_connect_card_signals()
	reroll_button.pressed.connect(_on_reroll_button_pressed)
	_current_gold = fallback_starting_gold
	_reset_shop_state()
	_refresh_all()


func bind_hero(hero: Hero) -> void:
	_bound_hero = hero
	_refresh_all()


func unbind_hero() -> void:
	_bound_hero = null
	_refresh_all()


func set_gold(amount: int) -> void:
	_current_gold = maxi(0, amount)
	_reset_shop_state()
	_refresh_all()
	gold_changed.emit(_current_gold)


func get_gold() -> int:
	return _current_gold


func _connect_card_signals() -> void:
	for slot: int in _card_buttons.keys():
		var button: Button = _card_buttons[slot]
		button.pressed.connect(_on_shop_card_pressed.bind(slot))
		button.mouse_entered.connect(_on_card_mouse_entered.bind(slot))
		button.mouse_exited.connect(_on_card_mouse_exited.bind(slot))


func _reset_shop_state() -> void:
	_free_reroll_remaining = free_reroll_uses
	_paid_reroll_count = 0
	_generate_shop_cards()


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
	if _current_gold < cost:
		_flash_gold_insufficient()
		return
	if not _bound_hero.can_equip_item(slot, item):
		return
	if not _bound_hero.equip_item(slot, item):
		return
	_current_gold -= cost
	card["purchased"] = true
	_shop_cards[slot] = card
	item_purchased.emit(_bound_hero, slot, item, cost)
	gold_changed.emit(_current_gold)
	_refresh_all()


func _on_reroll_button_pressed() -> void:
	var reroll_cost: int = _get_current_reroll_cost()
	if reroll_cost > 0:
		if _current_gold < reroll_cost:
			_flash_gold_insufficient()
			return
		_current_gold -= reroll_cost
		_paid_reroll_count += 1
	else:
		_free_reroll_remaining = maxi(0, _free_reroll_remaining - 1)
	_generate_shop_cards()
	gold_changed.emit(_current_gold)
	_refresh_all()


func _get_current_reroll_cost() -> int:
	if _free_reroll_remaining > 0:
		return 0
	return 10 * (_paid_reroll_count + 1)


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
	gold_label.text = "골드: %d" % _current_gold
	gold_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	reroll_count_label.text = "무료 리롤: %d/%d" % [_free_reroll_remaining, free_reroll_uses]
	var reroll_cost: int = _get_current_reroll_cost()
	if reroll_cost <= 0:
		reroll_cost_label.text = "현재 비용: 무료"
	else:
		reroll_cost_label.text = "현재 비용: %dG" % reroll_cost


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
		button.disabled = purchased or _bound_hero == null or not is_instance_valid(_bound_hero) or hero_dead


func _flash_gold_insufficient() -> void:
	gold_label.modulate = Color(1.0, 0.45, 0.45, 1.0)
	var base_x: float = gold_label.position.x
	var tween := create_tween()
	tween.tween_property(gold_label, "position:x", base_x + 3.0, 0.05)
	tween.tween_property(gold_label, "position:x", base_x - 3.0, 0.05)
	tween.tween_property(gold_label, "position:x", base_x, 0.05)
	tween.tween_interval(0.3)
	tween.tween_callback(func(): gold_label.modulate = Color.WHITE)
