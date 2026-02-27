extends Node2D

@export_group("플레이그라운드 기본")
## 전투에서 사용할 히어로 씬 리소스입니다.
@export var hero_scene: PackedScene
## 코어 노드 경로입니다.
@export var core_path: NodePath
## 우클릭 이동 마커 노드 경로입니다.
@export var move_command_marker_path: NodePath
## 이동 가능 바닥 타일 레이어 경로입니다.
@export var ground_tiles_path: NodePath = NodePath("GroundTiles")
## 이동 불가 타일 레이어 경로입니다.
@export var blocked_tiles_path: NodePath = NodePath("BlockedTiles")
## 사거리 채움 오버레이 타일 레이어 경로입니다.
@export var range_overlay_fill_path: NodePath = NodePath("RangeOverlayFill")
## 사거리 테두리 오버레이 타일 레이어 경로입니다.
@export var range_overlay_border_path: NodePath = NodePath("RangeOverlayBorder")

@export_group("타일 전장 설정")
## 타일 한 칸 크기(px)입니다.
@export_range(8, 128, 1) var tile_size_px: int = 32
## 바닥 타일이 비어있을 때 자동 생성하는 반경(타일)입니다.
@export var default_fill_half_extents_tiles: Vector2i = Vector2i(20, 11)
## 바닥 타일 Source ID입니다.
@export var walkable_source_id: int = 0
## 바닥 타일 Atlas 좌표입니다.
@export var walkable_atlas_coords: Vector2i = Vector2i(0, 0)
## 코어 점유 타일 크기(가로x세로)입니다.
@export var core_footprint_tiles: Vector2i = Vector2i(3, 3)
@export_group("사거리 오버레이")
## 사거리 오버레이 타일 Source ID입니다.
@export var range_overlay_source_id: int = 0
## 사거리 오버레이 채움 Atlas 좌표입니다.
@export var range_overlay_fill_atlas_coords: Vector2i = Vector2i(0, 0)
## 사거리 오버레이 테두리 Atlas 좌표입니다.
@export var range_overlay_border_atlas_coords: Vector2i = Vector2i(1, 0)

@export_group("히어로 클래스 배치")
## 소환 순서별 히어로 클래스 배열(0=전사, 1=궁수, 2=마법사, 3=암살자)입니다.
@export var hero_spawn_class_order: PackedInt32Array = PackedInt32Array([0, 1, 2, 3])

@onready var hero_container: Node2D = $HeroContainer
@onready var _ground_tiles: TileMapLayer = get_node_or_null(ground_tiles_path) as TileMapLayer
@onready var _blocked_tiles: TileMapLayer = get_node_or_null(blocked_tiles_path) as TileMapLayer
@onready var _range_overlay_fill_tiles: TileMapLayer = get_node_or_null(range_overlay_fill_path) as TileMapLayer
@onready var _range_overlay_border_tiles: TileMapLayer = get_node_or_null(range_overlay_border_path) as TileMapLayer

var _astar: AStarGrid2D = AStarGrid2D.new()
var _walkable_rect: Rect2i = Rect2i()
var _range_overlay_fill_cells: Array[Vector2i] = []
var _range_overlay_border_cells: Array[Vector2i] = []
var _range_overlay_active_hero: Hero = null


func _ready() -> void:
	if _ground_tiles == null:
		push_error("PlayGround: GroundTiles node is missing.")
		return
	_ensure_default_ground_tiles()
	_rebuild_grid_graph()
	_clear_attack_range_overlay()


func get_tile_size_px() -> int:
	return maxi(1, tile_size_px)


func get_play_area_center_global() -> Vector2:
	var core: Node2D = get_node_or_null(core_path) as Node2D
	if core != null:
		return core.global_position
	return global_position


func world_to_cell(world_pos: Vector2) -> Vector2i:
	if _ground_tiles == null:
		return Vector2i.ZERO
	var local_pos: Vector2 = _ground_tiles.to_local(world_pos)
	return _ground_tiles.local_to_map(local_pos)


func cell_to_world_center(cell: Vector2i) -> Vector2:
	if _ground_tiles == null:
		return Vector2(cell.x * get_tile_size_px(), cell.y * get_tile_size_px())
	var local_pos: Vector2 = _ground_tiles.map_to_local(cell)
	return _ground_tiles.to_global(local_pos)


func is_walkable_cell(cell: Vector2i) -> bool:
	if _ground_tiles == null:
		return false
	if _ground_tiles.get_cell_source_id(cell) == -1:
		return false
	if _blocked_tiles != null and _blocked_tiles.get_cell_source_id(cell) != -1:
		return false
	if _is_cell_in_core_footprint(cell):
		return false
	return true


func build_world_path_to_target(from_world: Vector2, target_world: Vector2) -> Array[Vector2]:
	if _ground_tiles == null:
		return []
	if _walkable_rect.size.x <= 0 or _walkable_rect.size.y <= 0:
		_rebuild_grid_graph()
	if _walkable_rect.size.x <= 0 or _walkable_rect.size.y <= 0:
		return []

	var from_cell: Vector2i = world_to_cell(from_world)
	var target_cell: Vector2i = world_to_cell(target_world)
	if not _is_cell_in_graph_bounds(from_cell):
		return []
	if not _is_cell_in_graph_bounds(target_cell):
		return []
	if not is_walkable_cell(target_cell):
		return []
	if _astar.is_point_solid(from_cell):
		return []
	if _astar.is_point_solid(target_cell):
		return []

	var id_path = _astar.get_id_path(from_cell, target_cell)
	if id_path.is_empty():
		return []

	var world_path: Array[Vector2] = []
	for cell_variant in id_path:
		var cell: Vector2i = cell_variant
		var point: Vector2 = cell_to_world_center(cell)
		if world_path.is_empty() and point.distance_to(from_world) <= float(get_tile_size_px()) * 0.2:
			continue
		world_path.append(point)

	if world_path.is_empty():
		world_path.append(cell_to_world_center(target_cell))
	return world_path


func show_move_command_marker(world_pos: Vector2) -> void:
	var marker: Node = get_node_or_null(move_command_marker_path)
	if marker == null:
		return
	if not marker.has_method("show_marker"):
		return
	marker.call("show_marker", world_pos)


func set_hero_attack_range_overlay(hero: Hero, visible: bool) -> void:
	if not _has_range_overlay_layers():
		return
	if not visible:
		if _range_overlay_active_hero == null or _range_overlay_active_hero == hero:
			_range_overlay_active_hero = null
			_clear_attack_range_overlay()
		return
	if hero == null or not is_instance_valid(hero):
		_range_overlay_active_hero = null
		_clear_attack_range_overlay()
		return
	_range_overlay_active_hero = hero
	_redraw_attack_range_overlay(hero)


func summon_hero() -> Hero:
	if hero_scene == null:
		push_warning("PlayGround: hero_scene is not set")
		return null
	var hero: Hero = hero_scene.instantiate()
	hero.playground = self
	hero_container.add_child(hero)

	var hero_count: int = hero_container.get_child_count()
	hero.hero_display_name = "용사 %d" % hero_count
	_apply_spawn_class(hero, hero_count)
	hero.global_position = cell_to_world_center(_find_spawn_cell(hero))
	return hero


func _apply_spawn_class(hero: Hero, hero_count: int) -> void:
	if hero == null:
		return
	if hero_spawn_class_order.is_empty():
		return
	var order_index: int = maxi(0, hero_count - 1) % hero_spawn_class_order.size()
	var class_id: int = int(hero_spawn_class_order[order_index])
	hero.hero_class = clampi(class_id, Hero.HeroClass.WARRIOR, Hero.HeroClass.ASSASSIN)


func _find_spawn_cell(_hero: Hero) -> Vector2i:
	var center_cell: Vector2i = world_to_cell(get_play_area_center_global())
	if is_walkable_cell(center_cell) and not _is_cell_occupied_by_hero(center_cell):
		return center_cell

	for radius: int in range(1, 16):
		for y: int in range(-radius, radius + 1):
			for x: int in range(-radius, radius + 1):
				if abs(x) != radius and abs(y) != radius:
					continue
				var candidate: Vector2i = center_cell + Vector2i(x, y)
				if not _is_cell_in_graph_bounds(candidate):
					continue
				if not is_walkable_cell(candidate):
					continue
				if _is_cell_occupied_by_hero(candidate):
					continue
				return candidate

	for y: int in range(_walkable_rect.position.y, _walkable_rect.position.y + _walkable_rect.size.y):
		for x: int in range(_walkable_rect.position.x, _walkable_rect.position.x + _walkable_rect.size.x):
			var candidate: Vector2i = Vector2i(x, y)
			if not is_walkable_cell(candidate):
				continue
			if _is_cell_occupied_by_hero(candidate):
				continue
			return candidate
	return center_cell


func _is_cell_occupied_by_hero(cell: Vector2i) -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"hero"):
		if not is_instance_valid(node):
			continue
		var hero: Hero = node as Hero
		if hero == null:
			continue
		if world_to_cell(hero.global_position) == cell:
			return true
	return false


func _ensure_default_ground_tiles() -> void:
	if _ground_tiles == null:
		return
	var used_rect: Rect2i = _ground_tiles.get_used_rect()
	if used_rect.size.x > 0 and used_rect.size.y > 0:
		return
	if walkable_source_id < 0:
		push_warning("PlayGround: walkable_source_id is invalid, default ground fill skipped.")
		return

	var center_cell: Vector2i = world_to_cell(get_play_area_center_global())
	for y: int in range(-default_fill_half_extents_tiles.y, default_fill_half_extents_tiles.y + 1):
		for x: int in range(-default_fill_half_extents_tiles.x, default_fill_half_extents_tiles.x + 1):
			var cell: Vector2i = center_cell + Vector2i(x, y)
			_ground_tiles.set_cell(cell, walkable_source_id, walkable_atlas_coords, 0)


func _rebuild_grid_graph() -> void:
	if _ground_tiles == null:
		_walkable_rect = Rect2i()
		return
	var used_rect: Rect2i = _ground_tiles.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		_walkable_rect = Rect2i()
		return

	_walkable_rect = used_rect
	_astar = AStarGrid2D.new()
	_astar.region = _walkable_rect
	_astar.cell_size = Vector2(float(get_tile_size_px()), float(get_tile_size_px()))
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()

	for y: int in range(_walkable_rect.position.y, _walkable_rect.position.y + _walkable_rect.size.y):
		for x: int in range(_walkable_rect.position.x, _walkable_rect.position.x + _walkable_rect.size.x):
			var cell: Vector2i = Vector2i(x, y)
			if not is_walkable_cell(cell):
				_astar.set_point_solid(cell, true)


func _is_cell_in_graph_bounds(cell: Vector2i) -> bool:
	if _walkable_rect.size.x <= 0 or _walkable_rect.size.y <= 0:
		return false
	if cell.x < _walkable_rect.position.x:
		return false
	if cell.y < _walkable_rect.position.y:
		return false
	if cell.x >= _walkable_rect.position.x + _walkable_rect.size.x:
		return false
	if cell.y >= _walkable_rect.position.y + _walkable_rect.size.y:
		return false
	return true


func _is_cell_in_core_footprint(cell: Vector2i) -> bool:
	var core: Node2D = get_node_or_null(core_path) as Node2D
	if core == null:
		return false
	var footprint: Vector2i = Vector2i(maxi(1, core_footprint_tiles.x), maxi(1, core_footprint_tiles.y))
	var half: Vector2i = Vector2i(footprint.x / 2, footprint.y / 2)
	var center_cell: Vector2i = world_to_cell(core.global_position)
	var min_cell: Vector2i = center_cell - half
	var max_cell: Vector2i = min_cell + footprint - Vector2i.ONE
	return cell.x >= min_cell.x and cell.x <= max_cell.x and cell.y >= min_cell.y and cell.y <= max_cell.y


func _has_range_overlay_layers() -> bool:
	return _range_overlay_fill_tiles != null and _range_overlay_border_tiles != null


func _redraw_attack_range_overlay(hero: Hero) -> void:
	if not _has_range_overlay_layers():
		return
	if hero == null or not is_instance_valid(hero):
		_clear_attack_range_overlay()
		return
	if not hero.has_method("get_attack_range_tile_span"):
		_clear_attack_range_overlay()
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
			if not _is_overlay_cell_renderable(cell):
				continue
			next_fill_cells.append(cell)
			if abs(x) == radius or abs(y) == radius:
				next_border_cells.append(cell)

	_clear_cells(_range_overlay_fill_tiles, _range_overlay_fill_cells)
	_clear_cells(_range_overlay_border_tiles, _range_overlay_border_cells)
	_range_overlay_fill_cells = next_fill_cells
	_range_overlay_border_cells = next_border_cells
	_apply_cells(_range_overlay_fill_tiles, _range_overlay_fill_cells, range_overlay_source_id, range_overlay_fill_atlas_coords)
	_apply_cells(_range_overlay_border_tiles, _range_overlay_border_cells, range_overlay_source_id, range_overlay_border_atlas_coords)


func _clear_attack_range_overlay() -> void:
	if not _has_range_overlay_layers():
		return
	_clear_cells(_range_overlay_fill_tiles, _range_overlay_fill_cells)
	_clear_cells(_range_overlay_border_tiles, _range_overlay_border_cells)
	_range_overlay_fill_cells.clear()
	_range_overlay_border_cells.clear()


func _clear_cells(layer: TileMapLayer, cells: Array[Vector2i]) -> void:
	if layer == null:
		return
	for cell: Vector2i in cells:
		layer.set_cell(cell, -1)


func _apply_cells(layer: TileMapLayer, cells: Array[Vector2i], source_id: int, atlas_coords: Vector2i) -> void:
	if layer == null:
		return
	if source_id < 0:
		return
	for cell: Vector2i in cells:
		layer.set_cell(cell, source_id, atlas_coords, 0)


func _is_overlay_cell_renderable(cell: Vector2i) -> bool:
	return _is_cell_in_graph_bounds(cell)
