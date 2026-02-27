extends CanvasLayer

const ItemEnumsRef = preload("res://scripts/items/ItemEnums.gd")
const ItemDataRef = preload("res://scripts/items/ItemData.gd")
@export_group("HeroInterface 표시/상점 기본값")
## 히어로 초상화 표시 배율입니다.
@export_range(1.0, 4.0, 0.1) var portrait_scale: float = 2.0
## 상점 카드 호버 시 확대 배율입니다.
@export_range(1.0, 2.0, 0.05) var card_hover_scale: float = 1.3
## 초기 골드 입력이 없을 때 사용할 기본값입니다.
@export_range(0, 99999, 1) var fallback_starting_gold: int = 100
## 무료 리롤 가능 횟수입니다.
@export_range(0, 20, 1) var free_reroll_uses: int = 5

@onready var hero_interface_root: Control = $HeroInterfaceRoot
@onready var hero_name_label: Label = $HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/PortraitColumn/NameLabel
@onready var portrait_sprite: AnimatedSprite2D = $HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/PortraitColumn/PortraitFrame/PortraitCenter/PortraitSprite

@onready var weapon_slot: ItemSlotUI = $HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/EquipColumn/EquipSlots/WeaponSlot
@onready var armor_slot: ItemSlotUI = $HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/EquipColumn/EquipSlots/ArmorSlot
@onready var boots_slot: ItemSlotUI = $HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/EquipColumn/EquipSlots/BootsSlot

@onready var level_label: Label = $HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/StatColumn/LevelRow/LevelLabel
@onready var exp_bar: TextureProgressBar = $HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/StatColumn/LevelRow/ExpBar
@onready var exp_label: Label = $HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/StatColumn/LevelRow/ExpLabel
@onready var strength_label: Label = $HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/StatColumn/StrengthLabel
@onready var agility_label: Label = $HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/StatColumn/AgilityLabel
@onready var intelligence_label: Label = $HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/StatColumn/IntelligenceLabel
@onready var range_label: Label = $HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/StatColumn/RangeLabel

@onready var gold_label: Label = $HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/ShopColumn/GoldLabel
@onready var weapon_card: Button = $HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/ShopColumn/CardsRow/WeaponCard
@onready var armor_card: Button = $HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/ShopColumn/CardsRow/ArmorCard
@onready var boots_card: Button = $HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/ShopColumn/CardsRow/BootsCard

@onready var reroll_button: Button = $HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/RerollColumn/RerollButton
@onready var reroll_count_label: Label = $HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/RerollColumn/RerollCountLabel
@onready var reroll_cost_label: Label = $HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/RerollColumn/RerollCostLabel

@onready var enemy_status_root: Control = $EnemyStatusRoot
@onready var enemy_health_label: Label = $EnemyStatusRoot/EnemyStatusPanel/MarginContainer/VBoxContainer/EnemyHealthLabel

var _playground: Node2D = null
var _selected_hero: Hero = null
var _selected_enemy: Area2D = null
var _registered_hero_ids: Dictionary = {}
var _registered_enemy_ids: Dictionary = {}
var _draw_rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _equipment_slots: Dictionary = {}
var _card_buttons: Dictionary = {}
var _shop_cards: Dictionary = {}

var _current_gold: int = 0
var _free_reroll_remaining: int = 0
var _paid_reroll_count: int = 0

var _portrait_source_anim: AnimatedSprite2D = null


func _ready() -> void:
	_playground = get_parent() as Node2D
	_draw_rng.randomize()

	_equipment_slots = {
		ItemEnumsRef.EquipSlot.WEAPON: weapon_slot,
		ItemEnumsRef.EquipSlot.ARMOR: armor_slot,
		ItemEnumsRef.EquipSlot.BOOTS: boots_slot
	}
	_card_buttons = {
		ItemEnumsRef.EquipSlot.WEAPON: weapon_card,
		ItemEnumsRef.EquipSlot.ARMOR: armor_card,
		ItemEnumsRef.EquipSlot.BOOTS: boots_card
	}

	_connect_card_signals()
	reroll_button.pressed.connect(_on_reroll_button_pressed)

	_register_existing_heroes()
	_connect_hero_container()
	_register_existing_enemies()
	_connect_world_root_for_enemies()

	portrait_sprite.scale = Vector2.ONE * portrait_scale
	hero_interface_root.visible = false
	enemy_status_root.visible = false
	enemy_health_label.text = "체력: - / -"

	_current_gold = fallback_starting_gold
	_reset_shop_state()
	_refresh_all_ui()


func set_starting_gold(value: int) -> void:
	_current_gold = maxi(0, value)
	_reset_shop_state()
	_refresh_all_ui()


func _connect_card_signals() -> void:
	for slot: int in _card_buttons.keys():
		var button: Button = _card_buttons[slot]
		button.pressed.connect(_on_shop_card_pressed.bind(slot))
		button.mouse_entered.connect(_on_card_mouse_entered.bind(slot))
		button.mouse_exited.connect(_on_card_mouse_exited.bind(slot))


func _register_existing_heroes() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"hero"):
		_register_hero(node)


func _connect_hero_container() -> void:
	if _playground == null:
		return
	var hero_container: Node = _playground.get_node_or_null("HeroContainer")
	if hero_container == null:
		return
	hero_container.child_entered_tree.connect(_on_hero_container_child_entered_tree)


func _register_hero(node: Node) -> void:
	if node == null:
		return
	if not (node is Hero):
		return
	if not node.has_signal("hero_clicked"):
		return

	var hero_id: int = node.get_instance_id()
	if _registered_hero_ids.has(hero_id):
		return
	_registered_hero_ids[hero_id] = true

	node.connect("hero_clicked", Callable(self, "_on_hero_clicked"))
	node.connect("hero_moved", Callable(self, "_on_hero_moved"))
	node.connect("hero_stats_changed", Callable(self, "_on_hero_stats_changed"))
	node.connect("equipment_changed", Callable(self, "_on_hero_equipment_changed"))
	node.connect("health_changed", Callable(self, "_on_hero_health_changed"))
	if node.has_signal("progression_changed"):
		node.connect("progression_changed", Callable(self, "_on_hero_progression_changed"))
	node.tree_exited.connect(_on_hero_tree_exited.bind(hero_id))


func _register_existing_enemies() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		_register_enemy(node)


func _connect_world_root_for_enemies() -> void:
	var world_root: Node = get_tree().current_scene
	if world_root == null:
		return
	world_root.child_entered_tree.connect(_on_world_child_entered_tree)


func _register_enemy(node: Node) -> void:
	if node == null:
		return
	if not (node is Area2D):
		return
	if not node.is_in_group(&"enemy"):
		return
	if not node.has_signal("enemy_clicked"):
		return

	var enemy_id: int = node.get_instance_id()
	if _registered_enemy_ids.has(enemy_id):
		return
	_registered_enemy_ids[enemy_id] = true

	node.connect("enemy_clicked", Callable(self, "_on_enemy_clicked"))
	if node.has_signal("health_changed"):
		var health_callable := Callable(self, "_on_enemy_health_changed").bind(node)
		node.connect("health_changed", health_callable)
	node.tree_exited.connect(_on_enemy_tree_exited.bind(enemy_id))


func _on_hero_container_child_entered_tree(node: Node) -> void:
	_register_hero(node)


func _on_world_child_entered_tree(node: Node) -> void:
	_register_enemy(node)


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if _is_click_inside_ui(mb.position):
		return

	if mb.button_index == MOUSE_BUTTON_LEFT:
		_clear_selection()
		return

	if mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	if _selected_hero == null or not is_instance_valid(_selected_hero):
		return
	if _selected_hero.has_method("is_dead") and bool(_selected_hero.call("is_dead")):
		return
	if not _selected_hero.has_method("issue_move_command"):
		return
	var world_target: Vector2 = _get_world_mouse_position()
	_selected_hero.call("issue_move_command", world_target)
	if _playground != null and _playground.has_method("show_move_command_marker"):
		_playground.call("show_move_command_marker", world_target)
	get_viewport().set_input_as_handled()


func _get_world_mouse_position() -> Vector2:
	if _playground != null:
		return _playground.get_global_mouse_position()
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		return camera.get_global_mouse_position()
	return get_viewport().get_mouse_position()


func _on_hero_clicked(hero: Hero) -> void:
	_select_hero(hero)


func _on_enemy_clicked(enemy: Area2D) -> void:
	_select_enemy(enemy)


func _on_hero_moved(hero: Hero, _world_position: Vector2) -> void:
	if hero != _selected_hero:
		return
	_sync_portrait_from_source()


func _on_hero_stats_changed(hero: Hero, _stats: HeroStats) -> void:
	if hero != _selected_hero:
		return
	_refresh_stat_labels()


func _on_hero_health_changed(hero: Hero, _current: float, _max_value: float, _ratio: float) -> void:
	if hero != _selected_hero:
		return
	_refresh_stat_labels()


func _on_hero_progression_changed(hero: Hero, _level: int, _current_exp: int, _required_exp: int) -> void:
	if hero != _selected_hero:
		return
	_refresh_progression_labels()


func _on_hero_equipment_changed(hero: Hero, _slot: int, _item: ItemData) -> void:
	if hero != _selected_hero:
		return
	_refresh_equipment_slots()
	_refresh_stat_labels()


func _on_enemy_health_changed(current: float, max_value: float, _ratio: float, enemy: Area2D) -> void:
	if enemy != _selected_enemy:
		return
	_refresh_enemy_health_from_values(current, max_value)


func _on_hero_tree_exited(hero_id: int) -> void:
	_registered_hero_ids.erase(hero_id)
	if _selected_hero == null:
		return
	if not is_instance_valid(_selected_hero):
		_deselect_hero()
		return
	if _selected_hero.get_instance_id() != hero_id:
		return
	_deselect_hero()


func _on_enemy_tree_exited(enemy_id: int) -> void:
	_registered_enemy_ids.erase(enemy_id)
	if _selected_enemy == null:
		return
	if not is_instance_valid(_selected_enemy):
		_deselect_enemy()
		return
	if _selected_enemy.get_instance_id() != enemy_id:
		return
	_deselect_enemy()


func _select_hero(hero: Hero) -> void:
	if hero == null:
		return
	if not is_instance_valid(hero):
		return
	if _selected_hero != null and _selected_hero != hero and is_instance_valid(_selected_hero):
		_set_hero_selected_visual(_selected_hero, false)
		_set_hero_attack_range_preview(_selected_hero, false)
	if _selected_enemy != null:
		_deselect_enemy()
	_selected_hero = hero
	_set_hero_selected_visual(_selected_hero, true)
	_set_hero_attack_range_preview(_selected_hero, true)
	hero_interface_root.visible = true
	_bind_portrait_source(hero)
	_refresh_all_ui()


func _deselect_hero() -> void:
	if _selected_hero != null and is_instance_valid(_selected_hero):
		_set_hero_selected_visual(_selected_hero, false)
		_set_hero_attack_range_preview(_selected_hero, false)
	_unbind_portrait_source()
	_selected_hero = null
	hero_interface_root.visible = false
	_refresh_all_ui()


func _select_enemy(enemy: Area2D) -> void:
	if enemy == null:
		return
	if not is_instance_valid(enemy):
		return
	if _selected_hero != null:
		_deselect_hero()
	if _selected_enemy != null and _selected_enemy != enemy and is_instance_valid(_selected_enemy):
		_set_enemy_attack_range_preview(_selected_enemy, false)
	_selected_enemy = enemy
	_set_enemy_attack_range_preview(_selected_enemy, true)
	enemy_status_root.visible = true
	_refresh_enemy_health_label()


func _deselect_enemy() -> void:
	if _selected_enemy != null and is_instance_valid(_selected_enemy):
		_set_enemy_attack_range_preview(_selected_enemy, false)
	_selected_enemy = null
	enemy_status_root.visible = false
	enemy_health_label.text = "체력: - / -"


func _clear_selection() -> void:
	if _selected_hero != null:
		_deselect_hero()
	if _selected_enemy != null:
		_deselect_enemy()


func _set_enemy_attack_range_preview(enemy: Area2D, visible: bool) -> void:
	if enemy == null:
		return
	if not is_instance_valid(enemy):
		return
	if not enemy.has_method("set_attack_range_preview_visible"):
		return
	enemy.call("set_attack_range_preview_visible", visible)


func _set_hero_selected_visual(hero: Hero, selected: bool) -> void:
	if hero == null:
		return
	if not is_instance_valid(hero):
		return
	if not hero.has_method("set_selected_visual"):
		return
	hero.call("set_selected_visual", selected)


func _set_hero_attack_range_preview(hero: Hero, visible: bool) -> void:
	if hero == null:
		return
	if not is_instance_valid(hero):
		return
	if not hero.has_method("set_attack_range_preview_visible"):
		return
	hero.call("set_attack_range_preview_visible", visible)


func _bind_portrait_source(hero: Hero) -> void:
	_unbind_portrait_source()
	if hero == null:
		return
	var source: AnimatedSprite2D = hero.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if source == null:
		return
	_portrait_source_anim = source
	if not _portrait_source_anim.frame_changed.is_connected(_on_portrait_source_frame_changed):
		_portrait_source_anim.frame_changed.connect(_on_portrait_source_frame_changed)
	if not _portrait_source_anim.animation_changed.is_connected(_on_portrait_source_animation_changed):
		_portrait_source_anim.animation_changed.connect(_on_portrait_source_animation_changed)
	_sync_portrait_from_source()


func _unbind_portrait_source() -> void:
	if _portrait_source_anim != null and is_instance_valid(_portrait_source_anim):
		if _portrait_source_anim.frame_changed.is_connected(_on_portrait_source_frame_changed):
			_portrait_source_anim.frame_changed.disconnect(_on_portrait_source_frame_changed)
		if _portrait_source_anim.animation_changed.is_connected(_on_portrait_source_animation_changed):
			_portrait_source_anim.animation_changed.disconnect(_on_portrait_source_animation_changed)
	_portrait_source_anim = null
	portrait_sprite.stop()
	portrait_sprite.sprite_frames = null


func _on_portrait_source_frame_changed() -> void:
	_sync_portrait_from_source()


func _on_portrait_source_animation_changed() -> void:
	_sync_portrait_from_source()


func _sync_portrait_from_source() -> void:
	if _portrait_source_anim == null:
		return
	if not is_instance_valid(_portrait_source_anim):
		return
	portrait_sprite.scale = Vector2.ONE * portrait_scale
	portrait_sprite.sprite_frames = _portrait_source_anim.sprite_frames
	if portrait_sprite.sprite_frames == null:
		portrait_sprite.stop()
		return
	if not portrait_sprite.sprite_frames.has_animation(_portrait_source_anim.animation):
		portrait_sprite.stop()
		return
	if portrait_sprite.animation != _portrait_source_anim.animation:
		portrait_sprite.animation = _portrait_source_anim.animation
	if _portrait_source_anim.is_playing():
		if not portrait_sprite.is_playing():
			portrait_sprite.play(portrait_sprite.animation)
	else:
		portrait_sprite.stop()
	portrait_sprite.frame = _portrait_source_anim.frame
	portrait_sprite.flip_h = _portrait_source_anim.flip_h
	portrait_sprite.speed_scale = _portrait_source_anim.speed_scale


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
	if _selected_hero == null or not is_instance_valid(_selected_hero):
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
		gold_label.modulate = Color(1.0, 0.45, 0.45, 1.0)
		return
	if not _selected_hero.can_equip_item(slot, item):
		return
	if not _selected_hero.equip_item(slot, item):
		return
	_current_gold -= cost
	card["purchased"] = true
	_shop_cards[slot] = card
	_refresh_all_ui()


func _on_reroll_button_pressed() -> void:
	var reroll_cost: int = _get_current_reroll_cost()
	if reroll_cost > 0:
		if _current_gold < reroll_cost:
			gold_label.modulate = Color(1.0, 0.45, 0.45, 1.0)
			return
		_current_gold -= reroll_cost
		_paid_reroll_count += 1
	else:
		_free_reroll_remaining = maxi(0, _free_reroll_remaining - 1)
	_generate_shop_cards()
	_refresh_all_ui()


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


func _on_card_mouse_exited(slot: int) -> void:
	var button: Button = _card_buttons.get(slot) as Button
	if button == null:
		return
	button.scale = Vector2.ONE


func _refresh_all_ui() -> void:
	_refresh_hero_header()
	_refresh_progression_labels()
	_refresh_stat_labels()
	_refresh_equipment_slots()
	_refresh_gold_and_reroll_labels()
	_refresh_card_buttons()


func _refresh_hero_header() -> void:
	if _selected_hero == null or not is_instance_valid(_selected_hero):
		hero_name_label.text = "히어로 미선택"
		return
	hero_name_label.text = _selected_hero.get_display_name()
	_sync_portrait_from_source()


func _refresh_progression_labels() -> void:
	if _selected_hero == null or not is_instance_valid(_selected_hero):
		level_label.text = "Level -"
		exp_bar.max_value = 1
		exp_bar.value = 0
		exp_label.text = "0/0"
		return
	var level_value: int = _selected_hero.get_level()
	var current_exp: int = _selected_hero.get_current_exp()
	var required_exp: int = _selected_hero.get_required_exp()
	level_label.text = "Level %d" % level_value
	exp_bar.max_value = maxi(1, required_exp)
	exp_bar.value = clampi(current_exp, 0, required_exp)
	exp_label.text = "%d/%d" % [current_exp, required_exp]


func _refresh_stat_labels() -> void:
	if _selected_hero == null or not is_instance_valid(_selected_hero):
		strength_label.text = "힘: -"
		agility_label.text = "민첩: -"
		intelligence_label.text = "지능: -"
		range_label.text = "사거리: -"
		return
	var stats: HeroStats = _selected_hero.get_current_stats()
	var str_bonus: int = stats.strength - _selected_hero.base_strength
	var agi_bonus: int = stats.agility - _selected_hero.base_agility
	var int_bonus: int = stats.intelligence - _selected_hero.base_intelligence
	var base_range: float = _selected_hero.base_attack_range
	var final_range: float = _selected_hero.get_final_attack_range()
	var range_bonus: float = final_range - base_range

	strength_label.text = _format_stat_line_int("힘", stats.strength, str_bonus)
	agility_label.text = _format_stat_line_int("민첩", stats.agility, agi_bonus)
	intelligence_label.text = _format_stat_line_int("지능", stats.intelligence, int_bonus)
	range_label.text = _format_stat_line_float("사거리", final_range, range_bonus)


func _format_stat_line_int(label: String, total_value: int, bonus_value: int) -> String:
	if bonus_value == 0:
		return "%s: %d" % [label, total_value]
	return "%s: %d(%s)" % [label, total_value, _format_signed_bonus(bonus_value)]


func _format_stat_line_float(label: String, total_value: float, bonus_value: float) -> String:
	if absf(bonus_value) <= 0.05:
		return "%s: %.1f" % [label, total_value]
	return "%s: %.1f(%s)" % [label, total_value, _format_signed_bonus_float(bonus_value)]


func _format_signed_bonus(value: int) -> String:
	if value > 0:
		return "%d▲" % value
	if value < 0:
		return "%d▼" % absi(value)
	return "0"


func _format_signed_bonus_float(value: float) -> String:
	if value > 0.05:
		return "%.1f▲" % value
	if value < -0.05:
		return "%.1f▼" % absf(value)
	return "0"


func _refresh_equipment_slots() -> void:
	for slot: int in _equipment_slots.keys():
		var slot_node: ItemSlotUI = _equipment_slots[slot]
		if _selected_hero == null or not is_instance_valid(_selected_hero):
			slot_node.set_item(null)
			continue
		slot_node.set_item(_selected_hero.get_equipment_item(slot))


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
		button.disabled = purchased or _selected_hero == null or not is_instance_valid(_selected_hero)


func _refresh_enemy_health_label() -> void:
	if _selected_enemy == null or not is_instance_valid(_selected_enemy):
		enemy_health_label.text = "체력: - / -"
		return
	if not _selected_enemy.has_method("get_current_health"):
		enemy_health_label.text = "체력: - / -"
		return
	if not _selected_enemy.has_method("get_max_health"):
		enemy_health_label.text = "체력: - / -"
		return
	var current: float = float(_selected_enemy.call("get_current_health"))
	var max_value: float = float(_selected_enemy.call("get_max_health"))
	_refresh_enemy_health_from_values(current, max_value)


func _refresh_enemy_health_from_values(current: float, max_value: float) -> void:
	var max_int: int = maxi(1, roundi(max_value))
	var current_int: int = clampi(roundi(current), 0, max_int)
	enemy_health_label.text = "체력: %d / %d" % [current_int, max_int]


func _is_click_inside_ui(point: Vector2) -> bool:
	return _contains_point(hero_interface_root, point) \
		or _contains_point(enemy_status_root, point)


func _contains_point(control: Control, point: Vector2) -> bool:
	if control == null:
		return false
	if not control.visible:
		return false
	return control.get_global_rect().has_point(point)
