extends CanvasLayer

const ItemEnumsRef = preload("res://scripts/items/ItemEnums.gd")
const ItemDataRef = preload("res://scripts/items/ItemData.gd")
const InventoryStateRef = preload("res://scripts/items/InventoryState.gd")

const SLOT_KIND_INVENTORY := "inventory"
const SLOT_KIND_EQUIPMENT := "equipment"

@export_range(1, 64, 1) var shared_inventory_slot_count: int = 9

@onready var summon_button: Button = $BottomCenterUI/ButtonsRow/SummonButton
@onready var equipment_draw_button: Button = $BottomCenterUI/ButtonsRow/EquipmentDrawButton
@onready var draw_notice_label: Label = $BottomCenterUI/DrawNoticeLabel
@onready var bottom_center_ui: Control = $BottomCenterUI
@onready var inventory_root: Control = $InventoryRoot
@onready var inventory_title_label: Label = $InventoryRoot/InventoryPanel/MarginContainer/VBoxContainer/InventoryTitle
@onready var inventory_slots_root: HBoxContainer = $InventoryRoot/InventoryPanel/MarginContainer/VBoxContainer/InventorySlots
@onready var status_root: Control = $StatusRoot
@onready var status_panel: PanelContainer = $StatusRoot/StatusPanel
@onready var strength_label: Label = $StatusRoot/StatusPanel/MarginContainer/HBoxContainer/StatsPanel/StrengthLabel
@onready var agility_label: Label = $StatusRoot/StatusPanel/MarginContainer/HBoxContainer/StatsPanel/AgilityLabel
@onready var intelligence_label: Label = $StatusRoot/StatusPanel/MarginContainer/HBoxContainer/StatsPanel/IntelligenceLabel
@onready var hero_health_label: Label = $StatusRoot/StatusPanel/MarginContainer/HBoxContainer/StatsPanel/HeroHealthLabel
@onready var physical_attack_label: Label = $StatusRoot/StatusPanel/MarginContainer/HBoxContainer/StatsPanel/PhysicalAttackLabel
@onready var magic_attack_label: Label = $StatusRoot/StatusPanel/MarginContainer/HBoxContainer/StatsPanel/MagicAttackLabel
@onready var attack_speed_label: Label = $StatusRoot/StatusPanel/MarginContainer/HBoxContainer/StatsPanel/AttackSpeedLabel
@onready var equipment_slots_root: GridContainer = $StatusRoot/StatusPanel/MarginContainer/HBoxContainer/EquipPanel/EquipSlots
@onready var enemy_status_root: Control = $EnemyStatusRoot
@onready var enemy_status_panel: PanelContainer = $EnemyStatusRoot/EnemyStatusPanel
@onready var enemy_health_label: Label = $EnemyStatusRoot/EnemyStatusPanel/MarginContainer/VBoxContainer/EnemyHealthLabel
@onready var tooltip_panel: PanelContainer = $TooltipPanel
@onready var tooltip_label: Label = $TooltipPanel/MarginContainer/TooltipLabel

var _playground: Node2D = null
var _selected_hero: Hero = null
var _selected_enemy: Area2D = null
var _shared_inventory: InventoryState = null
var _inventory_slots: Array[ItemSlotUI] = []
var _equipment_slots: Dictionary = {}
var _registered_hero_ids: Dictionary = {}
var _registered_enemy_ids: Dictionary = {}
var _slot_drag_in_progress: bool = false
var _draw_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _draw_notice_serial: int = 0


func _ready() -> void:
	_playground = get_parent() as Node2D
	summon_button.pressed.connect(_on_summon_button_pressed)
	equipment_draw_button.pressed.connect(_on_equipment_draw_button_pressed)
	_draw_rng.randomize()
	_cache_slot_nodes()
	_connect_slot_signals()
	_setup_shared_inventory()
	_register_existing_heroes()
	_connect_hero_container()
	_register_existing_enemies()
	_connect_world_root_for_enemies()
	status_root.visible = false
	enemy_status_root.visible = false
	tooltip_panel.visible = false
	draw_notice_label.visible = false
	_refresh_ui()


func _input(event: InputEvent) -> void:
	if tooltip_panel.visible and event is InputEventMouseMotion:
		_update_tooltip_position()


func _unhandled_input(event: InputEvent) -> void:
	if not status_root.visible and not enemy_status_root.visible:
		return
	if _slot_drag_in_progress:
		return
	if event is not InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if _is_click_inside_ui(mb.position):
		return
	_clear_selection()


func _setup_shared_inventory() -> void:
	_shared_inventory = InventoryStateRef.new(shared_inventory_slot_count)
	_populate_shared_inventory_from_item_database()
	_shared_inventory.changed.connect(_on_shared_inventory_changed)


func _cache_slot_nodes() -> void:
	_inventory_slots.clear()
	for child: Node in inventory_slots_root.get_children():
		if child is ItemSlotUI:
			_inventory_slots.append(child)
	_inventory_slots.sort_custom(func(a: ItemSlotUI, b: ItemSlotUI) -> bool: return a.slot_index < b.slot_index)

	_equipment_slots.clear()
	for child: Node in equipment_slots_root.get_children():
		if child is ItemSlotUI:
			_equipment_slots[(child as ItemSlotUI).slot_index] = child


func _connect_slot_signals() -> void:
	for slot: ItemSlotUI in _inventory_slots:
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_right_clicked.connect(_on_slot_right_clicked)
		slot.slot_hover_started.connect(_on_slot_hover_started)
		slot.slot_hover_ended.connect(_on_slot_hover_ended)
		slot.slot_drop_requested.connect(_on_slot_drop_requested)
		slot.slot_drag_started.connect(_on_slot_drag_started)
		slot.slot_drag_ended.connect(_on_slot_drag_ended)
	for slot_node: ItemSlotUI in _equipment_slots.values():
		slot_node.slot_clicked.connect(_on_slot_clicked)
		slot_node.slot_right_clicked.connect(_on_slot_right_clicked)
		slot_node.slot_hover_started.connect(_on_slot_hover_started)
		slot_node.slot_hover_ended.connect(_on_slot_hover_ended)
		slot_node.slot_drop_requested.connect(_on_slot_drop_requested)
		slot_node.slot_drag_started.connect(_on_slot_drag_started)
		slot_node.slot_drag_ended.connect(_on_slot_drag_ended)


func _connect_hero_container() -> void:
	if _playground == null:
		return
	var hero_container: Node = _playground.get_node_or_null("HeroContainer")
	if hero_container == null:
		return
	hero_container.child_entered_tree.connect(_on_hero_container_child_entered_tree)


func _connect_world_root_for_enemies() -> void:
	var world_root: Node = get_tree().current_scene
	if world_root == null:
		return
	world_root.child_entered_tree.connect(_on_world_child_entered_tree)


func _register_existing_heroes() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"hero"):
		_register_hero(node)


func _register_existing_enemies() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		_register_enemy(node)


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
	node.tree_exited.connect(_on_hero_tree_exited.bind(hero_id))


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

	var clicked_callable := Callable(self, "_on_enemy_clicked")
	if not node.is_connected("enemy_clicked", clicked_callable):
		node.connect("enemy_clicked", clicked_callable)
	if node.has_signal("enemy_moved"):
		var moved_callable := Callable(self, "_on_enemy_moved")
		if not node.is_connected("enemy_moved", moved_callable):
			node.connect("enemy_moved", moved_callable)
	if node.has_signal("health_changed"):
		var health_callable := Callable(self, "_on_enemy_health_changed").bind(node)
		if not node.is_connected("health_changed", health_callable):
			node.connect("health_changed", health_callable)
	var tree_exit_callable := _on_enemy_tree_exited.bind(enemy_id)
	if not node.tree_exited.is_connected(tree_exit_callable):
		node.tree_exited.connect(tree_exit_callable)


func _on_hero_container_child_entered_tree(node: Node) -> void:
	_register_hero(node)


func _on_world_child_entered_tree(node: Node) -> void:
	_register_enemy(node)


func _on_summon_button_pressed() -> void:
	if _playground == null:
		return
	if not _playground.has_method("summon_hero"):
		return
	var hero: Node = _playground.call("summon_hero")
	if hero == null:
		return
	_register_hero(hero)


func _on_equipment_draw_button_pressed() -> void:
	if _shared_inventory == null:
		return
	var empty_slot: int = _shared_inventory.find_first_empty_slot()
	if empty_slot < 0:
		_show_draw_notice("인벤토리가 가득 찼습니다.", Color(1.0, 0.6, 0.6, 1.0))
		return

	var item_db: Node = _get_item_database()
	if item_db == null:
		_show_draw_notice("아이템 DB를 찾을 수 없습니다.", Color(1.0, 0.6, 0.6, 1.0))
		return
	if not bool(item_db.call("is_ready")):
		_show_draw_notice("아이템 DB가 준비되지 않았습니다.", Color(1.0, 0.6, 0.6, 1.0))
		return

	var rolled_item: ItemData = item_db.call("roll_draw_item", _draw_rng) as ItemData
	if rolled_item == null:
		_show_draw_notice("장비 뽑기 풀을 확인해 주세요.", Color(1.0, 0.6, 0.6, 1.0))
		return
	_shared_inventory.set_item(empty_slot, rolled_item)
	_show_draw_notice("획득: %s" % _resolve_item_display_name(rolled_item), Color(0.7, 1.0, 0.75, 1.0))


func _on_hero_clicked(hero: Hero) -> void:
	_select_hero(hero)


func _on_enemy_clicked(enemy: Area2D) -> void:
	_select_enemy(enemy)


func _on_hero_moved(hero: Hero, _world_position: Vector2) -> void:
	if hero != _selected_hero:
		return
	_update_status_position()


func _on_enemy_moved(enemy: Area2D, _world_position: Vector2) -> void:
	if enemy != _selected_enemy:
		return
	_update_enemy_status_position()


func _on_hero_stats_changed(hero: Hero, _stats: HeroStats) -> void:
	if hero != _selected_hero:
		return
	_refresh_stat_labels()


func _on_hero_health_changed(hero: Hero, current: float, max_value: float, _ratio: float) -> void:
	if hero != _selected_hero:
		return
	_refresh_hero_health_from_values(current, max_value)


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
	call_deferred("_on_enemy_tree_exited_deferred", enemy_id)


func _on_enemy_tree_exited_deferred(enemy_id: int) -> void:
	var enemy_obj: Object = instance_from_id(enemy_id)
	if enemy_obj != null and enemy_obj is Node and (enemy_obj as Node).is_inside_tree():
		return
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
	if _selected_enemy != null:
		_deselect_enemy()
	_selected_hero = hero
	status_root.visible = true
	_refresh_ui()
	_update_status_position()


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
	tooltip_panel.visible = false
	_refresh_enemy_health_label()
	_update_enemy_status_position()


func _deselect_hero() -> void:
	_selected_hero = null
	status_root.visible = false
	tooltip_panel.visible = false
	_refresh_ui()


func _deselect_enemy() -> void:
	if _selected_enemy != null and is_instance_valid(_selected_enemy):
		_set_enemy_attack_range_preview(_selected_enemy, false)
	_selected_enemy = null
	enemy_status_root.visible = false
	enemy_health_label.text = "체력: - / -"
	tooltip_panel.visible = false


func _set_enemy_attack_range_preview(enemy: Area2D, visible: bool) -> void:
	if enemy == null:
		return
	if not is_instance_valid(enemy):
		return
	if not enemy.has_method("set_attack_range_preview_visible"):
		return
	enemy.call("set_attack_range_preview_visible", visible)


func _clear_selection() -> void:
	if _selected_hero != null:
		_deselect_hero()
	if _selected_enemy != null:
		_deselect_enemy()


func _refresh_ui() -> void:
	_refresh_inventory_slots()
	_refresh_equipment_slots()
	_refresh_stat_labels()
	_refresh_hero_health_label()


func _refresh_inventory_slots() -> void:
	var slot_count: int = _shared_inventory.get_slot_count() if _shared_inventory != null else shared_inventory_slot_count
	inventory_title_label.text = "공용 인벤토리 (%d칸)" % slot_count
	for slot: ItemSlotUI in _inventory_slots:
		var item: ItemData = _shared_inventory.get_item(slot.slot_index) if _shared_inventory != null else null
		slot.set_item(item)


func _refresh_equipment_slots() -> void:
	for slot_id: int in _equipment_slots.keys():
		var slot_node: ItemSlotUI = _equipment_slots[slot_id]
		if _selected_hero == null or not is_instance_valid(_selected_hero):
			slot_node.set_item(null)
			continue
		slot_node.set_item(_selected_hero.get_equipment_item(slot_id))


func _refresh_stat_labels() -> void:
	if _selected_hero == null or not is_instance_valid(_selected_hero):
		strength_label.text = "힘: -"
		agility_label.text = "민첩: -"
		intelligence_label.text = "지능: -"
		physical_attack_label.text = "물리공격력: -"
		magic_attack_label.text = "마법공격력: -"
		attack_speed_label.text = "공격속도: -"
		return
	var stats: HeroStats = _selected_hero.get_current_stats()
	_set_signed_int_label(strength_label, "힘", int(stats.strength))
	_set_signed_int_label(agility_label, "민첩", int(stats.agility))
	_set_signed_int_label(intelligence_label, "지능", int(stats.intelligence))
	physical_attack_label.text = "물리공격력: %.1f" % float(stats.physical_attack)
	magic_attack_label.text = "마법공격력: %.1f" % float(stats.magic_attack)
	attack_speed_label.text = "공격속도: %.2f APS" % float(stats.attacks_per_second)
	physical_attack_label.modulate = Color(1, 1, 1, 1)
	magic_attack_label.modulate = Color(1, 1, 1, 1)
	attack_speed_label.modulate = Color(1, 1, 1, 1)


func _refresh_hero_health_label() -> void:
	if _selected_hero == null or not is_instance_valid(_selected_hero):
		hero_health_label.text = "체력: - / -"
		return
	if not _selected_hero.has_method("get_current_health"):
		hero_health_label.text = "체력: - / -"
		return
	if not _selected_hero.has_method("get_max_health"):
		hero_health_label.text = "체력: - / -"
		return
	var current: float = float(_selected_hero.call("get_current_health"))
	var max_value: float = float(_selected_hero.call("get_max_health"))
	_refresh_hero_health_from_values(current, max_value)


func _refresh_hero_health_from_values(current: float, max_value: float) -> void:
	var current_int: int = int(roundf(current))
	var max_int: int = int(roundf(max_value))
	hero_health_label.text = "체력: %d / %d" % [current_int, max_int]


func _set_signed_int_label(label: Label, prefix: String, value: int) -> void:
	label.text = "%s: %s" % [prefix, _format_signed_int(value)]
	if value < 0:
		label.modulate = Color(1.0, 0.5, 0.5, 1.0)
	else:
		label.modulate = Color(1, 1, 1, 1)


func _format_signed_int(value: int) -> String:
	if value > 0:
		return "+%d" % value
	return "%d" % value


func _format_signed_float(value: float) -> String:
	return "%+0.1f" % value


func _on_slot_clicked(slot_kind: String, slot_index: int) -> void:
	if slot_kind == SLOT_KIND_INVENTORY:
		_try_equip_inventory_click(slot_index)
	elif slot_kind == SLOT_KIND_EQUIPMENT:
		_try_unequip_click(slot_index)


func _on_slot_right_clicked(slot_kind: String, slot_index: int) -> void:
	if slot_kind != SLOT_KIND_INVENTORY:
		return
	_try_auto_combine_inventory_click(slot_index)


func _try_equip_inventory_click(inventory_index: int) -> bool:
	if _selected_hero == null or not is_instance_valid(_selected_hero):
		return false
	if _shared_inventory == null:
		return false
	var inventory_item: ItemData = _shared_inventory.get_item(inventory_index)
	if inventory_item == null:
		return false
	var target_slot: int = ItemEnumsRef.default_slot_for_item(inventory_item.item_type)
	if not _selected_hero.can_equip_item(target_slot, inventory_item):
		return false
	var equipped_item: ItemData = _selected_hero.get_equipment_item(target_slot)
	if not _selected_hero.equip_item(target_slot, inventory_item):
		return false
	_shared_inventory.set_item(inventory_index, equipped_item)
	return true


func _try_unequip_click(slot: int) -> bool:
	if _selected_hero == null or not is_instance_valid(_selected_hero):
		return false
	if _shared_inventory == null:
		return false
	var equipped_item: ItemData = _selected_hero.get_equipment_item(slot)
	if equipped_item == null:
		return false
	var empty_slot: int = _shared_inventory.find_first_empty_slot()
	if empty_slot < 0:
		return false
	var removed: ItemData = _selected_hero.unequip_item(slot)
	if removed == null:
		return false
	_shared_inventory.set_item(empty_slot, removed)
	return true


func _on_slot_drop_requested(source_kind: String, source_index: int, target_kind: String, target_index: int) -> void:
	if _shared_inventory == null:
		return
	if target_kind == SLOT_KIND_INVENTORY and source_kind == SLOT_KIND_INVENTORY:
		_apply_inventory_to_inventory_drop(source_index, target_index)
	elif target_kind == SLOT_KIND_EQUIPMENT and source_kind == SLOT_KIND_INVENTORY:
		_apply_inventory_to_equipment_drop(source_index, target_index)
	elif target_kind == SLOT_KIND_INVENTORY and source_kind == SLOT_KIND_EQUIPMENT:
		_apply_equipment_to_inventory_drop(source_index, target_index)
	_clear_all_drag_feedback()


func _apply_inventory_to_inventory_drop(source_index: int, target_index: int) -> bool:
	if source_index == target_index:
		return false
	var source_item: ItemData = _shared_inventory.get_item(source_index)
	if source_item == null:
		return false
	var target_item: ItemData = _shared_inventory.get_item(target_index)
	if _try_combine_inventory_items(source_index, target_index):
		return true
	_shared_inventory.swap_items(source_index, target_index)
	return true


func _try_auto_combine_inventory_click(source_index: int) -> bool:
	if _shared_inventory == null:
		return false
	var source_item: ItemData = _shared_inventory.get_item(source_index)
	if source_item == null:
		return false

	var target_index: int = _find_matching_combine_target_index(source_item, source_index)
	if target_index < 0:
		return false

	return _try_combine_inventory_items(source_index, target_index)


func _find_matching_combine_target_index(source_item: ItemData, source_index: int) -> int:
	for i: int in _shared_inventory.get_slot_count():
		if i == source_index:
			continue
		var candidate: ItemData = _shared_inventory.get_item(i)
		if candidate == null:
			continue
		if candidate.can_combine_with(source_item):
			return i
	return -1


func _try_combine_inventory_items(source_index: int, target_index: int) -> bool:
	if _shared_inventory == null:
		return false
	if source_index == target_index:
		return false
	var source_item: ItemData = _shared_inventory.get_item(source_index)
	var target_item: ItemData = _shared_inventory.get_item(target_index)
	if source_item == null or target_item == null:
		return false
	if not target_item.can_combine_with(source_item):
		return false
	if target_item.enhance_level >= _get_max_enhance_level():
		return false
	target_item.enhance_level += 1
	_shared_inventory.set_item(target_index, target_item)
	_shared_inventory.set_item(source_index, null)
	return true


func _apply_inventory_to_equipment_drop(source_inventory_index: int, target_equip_slot: int) -> bool:
	if _selected_hero == null or not is_instance_valid(_selected_hero):
		return false
	var inventory_item: ItemData = _shared_inventory.get_item(source_inventory_index)
	if inventory_item == null:
		return false
	if not _selected_hero.can_equip_item(target_equip_slot, inventory_item):
		return false
	var equipped_item: ItemData = _selected_hero.get_equipment_item(target_equip_slot)
	if not _selected_hero.equip_item(target_equip_slot, inventory_item):
		return false
	_shared_inventory.set_item(source_inventory_index, equipped_item)
	return true


func _apply_equipment_to_inventory_drop(source_equip_slot: int, target_inventory_index: int) -> bool:
	if _selected_hero == null or not is_instance_valid(_selected_hero):
		return false
	var equipped_item: ItemData = _selected_hero.get_equipment_item(source_equip_slot)
	if equipped_item == null:
		return false

	var target_item: ItemData = _shared_inventory.get_item(target_inventory_index)
	if target_item == null:
		var removed: ItemData = _selected_hero.unequip_item(source_equip_slot)
		if removed == null:
			return false
		_shared_inventory.set_item(target_inventory_index, removed)
		return true

	if not _selected_hero.can_equip_item(source_equip_slot, target_item):
		return false
	var swapped_out: ItemData = _selected_hero.unequip_item(source_equip_slot)
	if swapped_out == null:
		return false
	if not _selected_hero.equip_item(source_equip_slot, target_item):
		_selected_hero.equip_item(source_equip_slot, swapped_out)
		return false
	_shared_inventory.set_item(target_inventory_index, swapped_out)
	return true


func _on_slot_drag_started() -> void:
	_slot_drag_in_progress = true
	tooltip_panel.visible = false
	_clear_all_drag_feedback()


func _on_slot_drag_ended() -> void:
	_slot_drag_in_progress = false
	_clear_all_drag_feedback()


func _clear_all_drag_feedback() -> void:
	for slot: ItemSlotUI in _inventory_slots:
		slot.clear_drag_feedback()
	for slot_node: ItemSlotUI in _equipment_slots.values():
		slot_node.clear_drag_feedback()


func _on_slot_hover_started(slot_kind: String, slot_index: int) -> void:
	var hovered_item: ItemData = _get_slot_item(slot_kind, slot_index)
	if hovered_item == null:
		tooltip_panel.visible = false
		return
	tooltip_label.text = _build_item_detail_text(hovered_item)
	tooltip_panel.visible = true
	_update_tooltip_position()


func _on_slot_hover_ended(_slot_kind: String, _slot_index: int) -> void:
	tooltip_panel.visible = false


func _get_slot_item(slot_kind: String, slot_index: int) -> ItemData:
	if slot_kind == SLOT_KIND_INVENTORY:
		return _shared_inventory.get_item(slot_index) if _shared_inventory != null else null
	if slot_kind == SLOT_KIND_EQUIPMENT:
		if _selected_hero == null or not is_instance_valid(_selected_hero):
			return null
		return _selected_hero.get_equipment_item(slot_index)
	return null


func _build_item_detail_text(item: ItemData) -> String:
	var lines: Array[String] = []
	var title := item.display_name
	if title.is_empty():
		title = String(item.item_id)
	title = "[%s] %s" % [ItemDataRef.tier_label(item.tier), title]
	if item.enhance_level > 0:
		title = "%s +%d" % [title, item.enhance_level]
	lines.append(title)
	lines.append("종류: %s" % ItemEnumsRef.item_type_label(item.item_type))
	var stat_multiplier: float = _resolve_enhance_stat_multiplier(item.enhance_level)
	var attack_multiplier: float = _resolve_enhance_attack_multiplier(item.enhance_level)
	if item.strength_bonus != 0:
		var final_strength: int = int(roundi(float(item.strength_bonus) * stat_multiplier))
		lines.append("힘 %s (기본 %s x%.2f)" % [_format_signed_int(final_strength), _format_signed_int(item.strength_bonus), stat_multiplier])
	if item.agility_bonus != 0:
		var final_agility: int = int(roundi(float(item.agility_bonus) * stat_multiplier))
		lines.append("민첩 %s (기본 %s x%.2f)" % [_format_signed_int(final_agility), _format_signed_int(item.agility_bonus), stat_multiplier])
	if item.intelligence_bonus != 0:
		var final_intelligence: int = int(roundi(float(item.intelligence_bonus) * stat_multiplier))
		lines.append("지능 %s (기본 %s x%.2f)" % [_format_signed_int(final_intelligence), _format_signed_int(item.intelligence_bonus), stat_multiplier])
	if not is_zero_approx(item.physical_attack_bonus):
		var final_physical: float = item.physical_attack_bonus * attack_multiplier
		lines.append("물리 %s (기본 %s x%.2f)" % [_format_signed_float(final_physical), _format_signed_float(item.physical_attack_bonus), attack_multiplier])
	if not is_zero_approx(item.magic_attack_bonus):
		var final_magic: float = item.magic_attack_bonus * attack_multiplier
		lines.append("마법 %s (기본 %s x%.2f)" % [_format_signed_float(final_magic), _format_signed_float(item.magic_attack_bonus), attack_multiplier])
	if item.enhance_level >= _get_max_enhance_level():
		lines.append("강화 상한 도달 (+%d)" % _get_max_enhance_level())
	if lines.size() == 2:
		lines.append("추가 스텟 없음")
	return "\n".join(lines)


func _on_shared_inventory_changed() -> void:
	_refresh_inventory_slots()


func _update_tooltip_position() -> void:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var target := mouse_pos + Vector2(18, 18)
	var viewport_size := get_viewport().get_visible_rect().size
	var tip_size := tooltip_panel.size
	target.x = clampf(target.x, 8.0, maxf(8.0, viewport_size.x - tip_size.x - 8.0))
	target.y = clampf(target.y, 8.0, maxf(8.0, viewport_size.y - tip_size.y - 8.0))
	tooltip_panel.position = target


func _update_status_position() -> void:
	if _selected_hero == null or not is_instance_valid(_selected_hero):
		return
	var target: Vector2 = _selected_hero.get_status_anchor_canvas_position()
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := status_panel.size
	target.x = clampf(target.x, 0.0, maxf(0.0, viewport_size.x - panel_size.x))
	target.y = clampf(target.y, 0.0, maxf(0.0, viewport_size.y - panel_size.y))
	status_root.position = target


func _update_enemy_status_position() -> void:
	if _selected_enemy == null or not is_instance_valid(_selected_enemy):
		return
	var target: Vector2
	if _selected_enemy.has_method("get_status_anchor_canvas_position"):
		target = _selected_enemy.call("get_status_anchor_canvas_position")
	else:
		target = _selected_enemy.get_global_transform_with_canvas().origin
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := enemy_status_panel.size
	target.x = clampf(target.x, 0.0, maxf(0.0, viewport_size.x - panel_size.x))
	target.y = clampf(target.y, 0.0, maxf(0.0, viewport_size.y - panel_size.y))
	enemy_status_root.position = target


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
	return _contains_point(status_panel, point) \
		or _contains_point(enemy_status_panel, point) \
		or _contains_point(inventory_root, point) \
		or _contains_point(bottom_center_ui, point) \
		or _contains_point(tooltip_panel, point)


func _contains_point(control: Control, point: Vector2) -> bool:
	if control == null:
		return false
	if not control.visible:
		return false
	return control.get_global_rect().has_point(point)


func _populate_shared_inventory_from_item_database() -> void:
	var item_db: Node = _get_item_database()
	if item_db == null:
		return
	if not bool(item_db.call("is_ready")):
		return
	var starter_ids: Array = item_db.call("get_starter_inventory_item_ids")
	for i: int in mini(starter_ids.size(), _shared_inventory.get_slot_count()):
		var item_id: Variant = starter_ids[i]
		if not (item_id is String or item_id is StringName):
			continue
		var item: ItemData = item_db.call("create_item_instance_by_id", StringName(item_id)) as ItemData
		if item == null:
			continue
		_shared_inventory.set_item(i, item)


func _get_item_database() -> Node:
	return get_tree().root.get_node_or_null("ItemDatabase")


func _get_max_enhance_level() -> int:
	if _selected_hero != null and is_instance_valid(_selected_hero):
		return _selected_hero.get_max_enhance_level()
	var item_db: Node = _get_item_database()
	if item_db != null and item_db.has_method("get_max_enhance_level"):
		return int(item_db.call("get_max_enhance_level"))
	return ItemDataRef.MAX_ENHANCE_LEVEL


func _resolve_enhance_attack_multiplier(level: int) -> float:
	if _selected_hero != null and is_instance_valid(_selected_hero):
		return _selected_hero.get_enhance_attack_multiplier(level)
	var item_db: Node = _get_item_database()
	if item_db != null and item_db.has_method("get_enhance_attack_multiplier"):
		return float(item_db.call("get_enhance_attack_multiplier", level))
	return 1.0 + float(clampi(level, 0, _get_max_enhance_level())) * 0.12


func _resolve_enhance_stat_multiplier(level: int) -> float:
	if _selected_hero != null and is_instance_valid(_selected_hero):
		return _selected_hero.get_enhance_stat_multiplier(level)
	var item_db: Node = _get_item_database()
	if item_db != null and item_db.has_method("get_enhance_stat_multiplier"):
		return float(item_db.call("get_enhance_stat_multiplier", level))
	return 1.0 + float(clampi(level, 0, _get_max_enhance_level())) * 0.05


func _resolve_item_display_name(item: ItemData) -> String:
	if item == null:
		return "알 수 없는 아이템"
	if not item.display_name.is_empty():
		return item.display_name
	if item.item_id != StringName():
		return String(item.item_id)
	return "알 수 없는 아이템"


func _show_draw_notice(message: String, tint: Color) -> void:
	_draw_notice_serial += 1
	var serial: int = _draw_notice_serial
	draw_notice_label.text = message
	draw_notice_label.modulate = tint
	draw_notice_label.visible = true
	var hide_timer: SceneTreeTimer = get_tree().create_timer(1.5)
	hide_timer.timeout.connect(_on_draw_notice_hide_timeout.bind(serial))


func _on_draw_notice_hide_timeout(serial: int) -> void:
	if serial != _draw_notice_serial:
		return
	draw_notice_label.visible = false
