extends CanvasLayer

## 히어로/적 선택 상태를 관리하고 자식 패널에 데이터를 위임하는 오케스트레이터입니다.

signal hero_selected(hero: Hero)
signal hero_deselected()
signal enemy_selected(enemy: Area2D)
signal enemy_deselected()

@onready var hero_interface_root: Control = $HeroInterfaceRoot
@onready var hero_info_panel: PanelContainer = $HeroInterfaceRoot/InterfacePanel
@onready var shop_panel: VBoxContainer = $HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/ShopColumn
@onready var enemy_status_panel: Control = $EnemyStatusRoot
@onready var _battle_economy: Node = $BattleEconomy

var _playground: Node2D = null
var _selected_hero: Hero = null
var _selected_enemy: Area2D = null
var _registered_hero_ids: Dictionary = {}
var _registered_enemy_ids: Dictionary = {}


func _ready() -> void:
	_playground = get_parent() as Node2D
	hero_interface_root.visible = false

	_register_existing_heroes()
	_connect_hero_container()
	_register_existing_enemies()
	_connect_scene_tree_for_enemies()
	_connect_shop_preview_signals()
	_connect_range_stat_hover_signal()
	_bind_shop_economy()


func _connect_shop_preview_signals() -> void:
	if shop_panel == null:
		return
	if shop_panel.has_signal("card_hover_started"):
		shop_panel.connect("card_hover_started", Callable(self, "_on_shop_card_hover_started"))
	if shop_panel.has_signal("card_hover_ended"):
		shop_panel.connect("card_hover_ended", Callable(self, "_on_shop_card_hover_ended"))


func _on_shop_card_hover_started(slot: int, item: ItemData) -> void:
	if hero_info_panel != null and hero_info_panel.has_method("show_stat_preview"):
		hero_info_panel.call("show_stat_preview", slot, item)


func _on_shop_card_hover_ended() -> void:
	if hero_info_panel != null and hero_info_panel.has_method("clear_stat_preview"):
		hero_info_panel.call("clear_stat_preview")


func _connect_range_stat_hover_signal() -> void:
	if hero_info_panel == null:
		return
	if hero_info_panel.has_signal("range_stat_hover_changed"):
		hero_info_panel.connect("range_stat_hover_changed", Callable(self, "_on_range_stat_hover_changed"))


func _on_range_stat_hover_changed(hovered: bool) -> void:
	if _selected_hero == null or not is_instance_valid(_selected_hero):
		return
	_set_hero_attack_range_preview(_selected_hero, hovered)


func set_starting_gold(value: int) -> void:
	if shop_panel != null and shop_panel.has_method("set_gold"):
		shop_panel.call("set_gold", value)


func get_current_gold() -> int:
	if _battle_economy != null and _battle_economy.has_method("get_gold"):
		return int(_battle_economy.call("get_gold"))
	if shop_panel != null and shop_panel.has_method("get_gold"):
		return int(shop_panel.call("get_gold"))
	return -1


func _bind_shop_economy() -> void:
	if _battle_economy == null:
		return
	if shop_panel == null:
		return
	if not shop_panel.has_method("bind_economy"):
		return
	shop_panel.call("bind_economy", _battle_economy)


# -- Entity registration ------------------------------------------------------

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
	node.tree_exited.connect(_on_hero_tree_exited.bind(hero_id))


func _register_existing_enemies() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		_register_enemy(node)


func _connect_scene_tree_for_enemies() -> void:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return
	var on_node_added: Callable = Callable(self, "_on_scene_tree_node_added")
	if scene_tree.is_connected("node_added", on_node_added):
		return
	scene_tree.connect("node_added", on_node_added)


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
	node.tree_exited.connect(_on_enemy_tree_exited.bind(enemy_id))


func _on_hero_container_child_entered_tree(node: Node) -> void:
	_register_hero(node)


func _on_scene_tree_node_added(node: Node) -> void:
	_register_enemy(node)


# -- Input handling ------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_hotkey(event)
		return

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
	var issued: bool = bool(_selected_hero.call("issue_move_command", world_target))
	if issued and _playground != null and _playground.has_method("show_move_command_marker"):
		var marker_target: Vector2 = world_target
		if _selected_hero.has_method("get_move_order_target"):
			marker_target = Vector2(_selected_hero.call("get_move_order_target"))
		_playground.call("show_move_command_marker", marker_target)
	get_viewport().set_input_as_handled()


func _handle_hotkey(event: InputEventKey) -> void:
	match event.keycode:
		KEY_1:
			_select_hero_by_index(0)
		KEY_2:
			_select_hero_by_index(1)
		KEY_3:
			_select_hero_by_index(2)
		KEY_4:
			_select_hero_by_index(3)
		KEY_TAB:
			_cycle_hero_selection(-1 if event.shift_pressed else 1)


func _select_hero_by_index(index: int) -> void:
	var heroes: Array[Node] = get_tree().get_nodes_in_group(&"hero")
	if index < 0 or index >= heroes.size():
		return
	var hero: Node = heroes[index]
	if hero is Hero:
		_select_hero(hero as Hero)


func _cycle_hero_selection(direction: int) -> void:
	var heroes: Array[Node] = get_tree().get_nodes_in_group(&"hero")
	if heroes.is_empty():
		return
	if _selected_hero == null or not is_instance_valid(_selected_hero):
		_select_hero(heroes[0] as Hero)
		return
	var current_index: int = heroes.find(_selected_hero)
	if current_index < 0:
		_select_hero(heroes[0] as Hero)
		return
	var next_index: int = (current_index + direction) % heroes.size()
	if next_index < 0:
		next_index += heroes.size()
	_select_hero(heroes[next_index] as Hero)


func _get_world_mouse_position() -> Vector2:
	if _playground != null:
		return _playground.get_global_mouse_position()
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		return camera.get_global_mouse_position()
	return get_viewport().get_mouse_position()


# -- Selection management ------------------------------------------------------

func _on_hero_clicked(hero: Hero) -> void:
	_select_hero(hero)


func _on_enemy_clicked(enemy: Area2D) -> void:
	_select_enemy(enemy)


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
	hero_interface_root.visible = true
	hero_info_panel.call("bind_hero", hero)
	shop_panel.call("bind_hero", hero)
	_sync_selected_hero_range_preview_from_hover_state()
	hero_selected.emit(hero)


func _deselect_hero() -> void:
	if _selected_hero != null and is_instance_valid(_selected_hero):
		_set_hero_selected_visual(_selected_hero, false)
		_set_hero_attack_range_preview(_selected_hero, false)
	_selected_hero = null
	hero_interface_root.visible = false
	hero_info_panel.call("unbind_hero")
	shop_panel.call("unbind_hero")
	hero_deselected.emit()


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
	enemy_status_panel.call("bind_enemy", enemy)
	enemy_selected.emit(enemy)


func _deselect_enemy() -> void:
	if _selected_enemy != null and is_instance_valid(_selected_enemy):
		_set_enemy_attack_range_preview(_selected_enemy, false)
	_selected_enemy = null
	enemy_status_panel.call("unbind_enemy")
	enemy_deselected.emit()


func _clear_selection() -> void:
	if _selected_hero != null:
		_deselect_hero()
	if _selected_enemy != null:
		_deselect_enemy()


# -- Tree exit handlers --------------------------------------------------------

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


func _exit_tree() -> void:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return
	var on_node_added: Callable = Callable(self, "_on_scene_tree_node_added")
	if scene_tree.is_connected("node_added", on_node_added):
		scene_tree.disconnect("node_added", on_node_added)


# -- Visual helpers ------------------------------------------------------------

func _set_enemy_attack_range_preview(enemy: Area2D, show: bool) -> void:
	if enemy == null:
		return
	if not is_instance_valid(enemy):
		return
	if not enemy.has_method("set_attack_range_preview_visible"):
		return
	enemy.call("set_attack_range_preview_visible", show)


func _set_hero_selected_visual(hero: Hero, selected: bool) -> void:
	if hero == null:
		return
	if not is_instance_valid(hero):
		return
	if not hero.has_method("set_selected_visual"):
		return
	hero.call("set_selected_visual", selected)


func _set_hero_attack_range_preview(hero: Hero, show: bool) -> void:
	if hero == null:
		return
	if not is_instance_valid(hero):
		return
	if not hero.has_method("set_attack_range_preview_visible"):
		return
	hero.call("set_attack_range_preview_visible", show)


func _sync_selected_hero_range_preview_from_hover_state() -> void:
	if _selected_hero == null or not is_instance_valid(_selected_hero):
		return
	var should_show: bool = false
	if hero_info_panel != null and hero_info_panel.has_method("is_range_stat_hovered"):
		should_show = bool(hero_info_panel.call("is_range_stat_hovered"))
	_set_hero_attack_range_preview(_selected_hero, should_show)


# -- UI helpers ----------------------------------------------------------------

func _is_click_inside_ui(point: Vector2) -> bool:
	return _contains_point(hero_interface_root, point) \
		or _contains_point(enemy_status_panel, point)


func _contains_point(control: Control, point: Vector2) -> bool:
	if control == null:
		return false
	if not control.visible:
		return false
	return control.get_global_rect().has_point(point)
