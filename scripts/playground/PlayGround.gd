extends Node2D

const HeroSpawnResolverRef = preload("res://scripts/playground/domain/HeroSpawnResolver.gd")

@export_group("플레이그라운드 기본")
## 전투에서 사용할 히어로 씬 리소스입니다.
@export var hero_scene: PackedScene
## 코어 노드 경로입니다.
@export var core_path: NodePath
## 우클릭 이동 마커 노드 경로입니다.
@export var move_command_marker_path: NodePath
## 전장 맵 서비스 노드 경로입니다.
@export var battle_map_path: NodePath = NodePath("../BattleMapSlot/BattleMap")

@export_group("히어로 클래스 배치")
## 소환 순서별 히어로 클래스 배열(0=전사, 1=궁수, 2=마법사, 3=암살자)입니다.
@export var hero_spawn_class_order: PackedInt32Array = PackedInt32Array([0, 1, 2, 3])

@onready var hero_container: Node2D = $HeroContainer
@onready var _battle_map: BattleMap = get_node_or_null(battle_map_path) as BattleMap

var _range_overlay_active_hero: Hero = null
var _spawn_resolver = HeroSpawnResolverRef.new()


func _ready() -> void:
	if _battle_map == null:
		push_error("PlayGround: BattleMap node is missing.")
		return
	_battle_map.clear_range_overlay()


func set_battle_map(map: BattleMap) -> void:
	if _battle_map != null:
		_battle_map.clear_range_overlay()
	_battle_map = map
	if _battle_map == null:
		return
	_battle_map.rebuild_navigation()
	if _range_overlay_active_hero != null and is_instance_valid(_range_overlay_active_hero):
		_redraw_attack_range_overlay(_range_overlay_active_hero)
	else:
		_battle_map.clear_range_overlay()


func get_tile_size_px() -> int:
	if _battle_map == null:
		return 32
	return _battle_map.get_tile_size_px()


func get_play_area_center_global() -> Vector2:
	var core: Node2D = get_node_or_null(core_path) as Node2D
	if core != null:
		return core.global_position
	return global_position


func world_to_cell(world_pos: Vector2) -> Vector2i:
	if _battle_map == null:
		return Vector2i.ZERO
	return _battle_map.world_to_cell(world_pos)


func cell_to_world_center(cell: Vector2i) -> Vector2:
	if _battle_map == null:
		return Vector2(cell.x * get_tile_size_px(), cell.y * get_tile_size_px())
	return _battle_map.cell_to_world_center(cell)


func is_walkable_cell(cell: Vector2i) -> bool:
	if _battle_map == null:
		return false
	return _battle_map.is_walkable_cell(cell)


func build_world_path_to_target(from_world: Vector2, target_world: Vector2) -> Array[Vector2]:
	if _battle_map == null:
		return []
	return _battle_map.build_world_path(from_world, target_world)


func show_move_command_marker(world_pos: Vector2) -> void:
	var marker: Node = get_node_or_null(move_command_marker_path)
	if marker == null:
		return
	if not marker.has_method("show_marker"):
		return
	marker.call("show_marker", world_pos)


func get_current_gold() -> int:
	var hero_hud: Node = get_node_or_null("HeroHUD")
	if hero_hud == null:
		return -1
	if not hero_hud.has_method("get_current_gold"):
		return -1
	return int(hero_hud.call("get_current_gold"))


func set_hero_attack_range_overlay(hero: Hero, visible: bool) -> void:
	if _battle_map == null:
		return
	if not visible:
		if _range_overlay_active_hero == null or _range_overlay_active_hero == hero:
			_range_overlay_active_hero = null
			_battle_map.clear_range_overlay()
		return
	if hero == null or not is_instance_valid(hero):
		_range_overlay_active_hero = null
		_battle_map.clear_range_overlay()
		return
	_range_overlay_active_hero = hero
	_redraw_attack_range_overlay(hero)


func summon_hero() -> Hero:
	if hero_scene == null:
		push_warning("PlayGround: hero_scene is not set")
		return null
	if _battle_map == null:
		push_warning("PlayGround: battle_map is not set")
		return null

	var spawn_cell: Vector2i = _find_spawn_cell()
	var hero: Hero = hero_scene.instantiate()
	hero.playground = self
	hero_container.add_child(hero)

	var hero_count: int = hero_container.get_child_count()
	hero.hero_display_name = "용사 %d" % hero_count
	_apply_spawn_class(hero, hero_count)
	hero.global_position = cell_to_world_center(spawn_cell)
	return hero


func _apply_spawn_class(hero: Hero, hero_count: int) -> void:
	if hero == null:
		return
	if hero_spawn_class_order.is_empty():
		return
	var order_index: int = maxi(0, hero_count - 1) % hero_spawn_class_order.size()
	var class_id: int = int(hero_spawn_class_order[order_index])
	hero.hero_class = clampi(class_id, Hero.HeroClass.WARRIOR, Hero.HeroClass.ASSASSIN)


func _find_spawn_cell() -> Vector2i:
	if _battle_map == null:
		return Vector2i.ZERO

	var center_cell: Vector2i = world_to_cell(get_play_area_center_global())
	if _spawn_resolver == null:
		return center_cell
	if not _spawn_resolver.has_method("find_spawn_cell"):
		return center_cell
	var resolved_cell_var: Variant = _spawn_resolver.find_spawn_cell(_battle_map, center_cell, Callable(self, "_is_cell_occupied_by_hero"))
	if resolved_cell_var is Vector2i:
		return resolved_cell_var as Vector2i
	return center_cell


func _is_cell_occupied_by_hero(cell: Vector2i) -> bool:
	for node: Node in hero_container.get_children():
		if not is_instance_valid(node):
			continue
		var hero: Hero = node as Hero
		if hero == null:
			continue
		if world_to_cell(hero.global_position) == cell:
			return true
	return false


func _redraw_attack_range_overlay(hero: Hero) -> void:
	if _battle_map == null:
		return
	if hero == null or not is_instance_valid(hero):
		_battle_map.clear_range_overlay()
		return
	if not hero.has_method("get_attack_range_tile_span"):
		_battle_map.clear_range_overlay()
		return

	var center_cell: Vector2i = world_to_cell(hero.global_position)
	if hero.has_method("get_attack_origin_cell"):
		center_cell = Vector2i(hero.call("get_attack_origin_cell"))
	var span: int = maxi(1, int(hero.call("get_attack_range_tile_span")))
	var radius: int = span / 2

	var next_fill_cells: Array[Vector2i] = []
	var next_border_cells: Array[Vector2i] = []
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			var cell: Vector2i = center_cell + Vector2i(x, y)
			if not _battle_map.is_cell_in_bounds(cell):
				continue
			if cell != center_cell:
				next_fill_cells.append(cell)
			next_border_cells.append(cell)

	_battle_map.set_range_overlay(next_fill_cells, next_border_cells)
