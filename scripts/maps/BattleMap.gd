extends Node2D
class_name BattleMap

@export_group("맵 타일 레이어 경로")
## 이동 가능한 바닥 타일 레이어 경로입니다.
@export var ground_tiles_path: NodePath = NodePath("GroundTiles")
## 이동 불가(충돌) 타일 레이어 경로입니다.
@export var blocked_tiles_path: NodePath = NodePath("BlockedTiles")
## 장식 그림자 타일 레이어 경로입니다.
@export var deco_shadow_tiles_path: NodePath = NodePath("DecoShadowTiles")
## 장식 식생 타일 레이어 경로입니다.
@export var deco_plant_tiles_path: NodePath = NodePath("DecoPlantTiles")
## 장식 오브젝트 타일 레이어 경로입니다.
@export var deco_props_tiles_path: NodePath = NodePath("DecoPropsTiles")
## 사거리 채움 오버레이 레이어 경로입니다.
@export var range_overlay_fill_path: NodePath = NodePath("RangeOverlayFill")
## 사거리 테두리 오버레이 레이어 경로입니다.
@export var range_overlay_border_path: NodePath = NodePath("RangeOverlayBorder")

@export_group("맵 규칙")
## 타일 한 칸 크기(px)입니다.
@export_range(8, 128, 1) var tile_size_px: int = 32
## 바닥 타일이 비어있을 때 자동 생성하는 반경(타일)입니다.
@export var default_fill_half_extents_tiles: Vector2i = Vector2i(20, 11)
## 기본 바닥 타일 Source ID입니다.
@export var walkable_source_id: int = 0
## 기본 바닥 타일 Atlas 좌표입니다.
@export var walkable_atlas_coords: Vector2i = Vector2i(0, 0)
## 코어 노드 경로입니다.
@export var core_path: NodePath = NodePath("../../CoreRoot")
## 코어 점유 타일 크기(가로x세로)입니다.
@export var core_footprint_tiles: Vector2i = Vector2i(3, 3)

@export_group("오버레이 타일")
## 사거리 오버레이 타일 Source ID입니다.
@export var range_overlay_source_id: int = 0
## 사거리 오버레이 채움 Atlas 좌표입니다.
@export var range_overlay_fill_atlas_coords: Vector2i = Vector2i(0, 0)
## 사거리 오버레이 테두리 Atlas 좌표입니다.
@export var range_overlay_border_atlas_coords: Vector2i = Vector2i(1, 0)

@export_group("레이아웃 프리셋")
## 맵 자동 페인팅 프리셋입니다. 0=사용 안함, 1=전투맵01, 2=전투맵02
@export_enum("사용 안함:0", "전투맵01:1", "전투맵02:2") var layout_preset: int = 0
## 장식/차단 레이어가 비어있을 때 프리셋 자동 페인팅을 수행합니다.
@export var auto_paint_layout_if_empty: bool = true

@onready var _ground_tiles: TileMapLayer = get_node_or_null(ground_tiles_path) as TileMapLayer
@onready var _blocked_tiles: TileMapLayer = get_node_or_null(blocked_tiles_path) as TileMapLayer
@onready var _deco_shadow_tiles: TileMapLayer = get_node_or_null(deco_shadow_tiles_path) as TileMapLayer
@onready var _deco_plant_tiles: TileMapLayer = get_node_or_null(deco_plant_tiles_path) as TileMapLayer
@onready var _deco_props_tiles: TileMapLayer = get_node_or_null(deco_props_tiles_path) as TileMapLayer
@onready var _range_overlay_fill_tiles: TileMapLayer = get_node_or_null(range_overlay_fill_path) as TileMapLayer
@onready var _range_overlay_border_tiles: TileMapLayer = get_node_or_null(range_overlay_border_path) as TileMapLayer

var _astar: AStarGrid2D = AStarGrid2D.new()
var _walkable_rect: Rect2i = Rect2i()
var _range_overlay_fill_cells: Array[Vector2i] = []
var _range_overlay_border_cells: Array[Vector2i] = []


func _ready() -> void:
	if _ground_tiles == null:
		push_error("BattleMap: GroundTiles node is missing.")
		return
	_ensure_default_ground_tiles()
	if auto_paint_layout_if_empty:
		_apply_layout_preset_if_needed()
	rebuild_navigation()
	clear_range_overlay()


func get_tile_size_px() -> int:
	return maxi(1, tile_size_px)


func get_walkable_rect() -> Rect2i:
	return _walkable_rect


func is_cell_in_bounds(cell: Vector2i) -> bool:
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


func build_world_path(from_world: Vector2, target_world: Vector2) -> Array[Vector2]:
	if _ground_tiles == null:
		return []
	if _walkable_rect.size.x <= 0 or _walkable_rect.size.y <= 0:
		rebuild_navigation()
	if _walkable_rect.size.x <= 0 or _walkable_rect.size.y <= 0:
		return []

	var from_cell: Vector2i = world_to_cell(from_world)
	var target_cell: Vector2i = world_to_cell(target_world)
	if not is_cell_in_bounds(from_cell):
		return []
	if not is_cell_in_bounds(target_cell):
		return []
	if not is_walkable_cell(target_cell):
		return []
	if _astar.is_point_solid(from_cell):
		return []
	if _astar.is_point_solid(target_cell):
		return []

	var id_path: Array[Vector2i] = _astar.get_id_path(from_cell, target_cell)
	if id_path.is_empty():
		return []

	var world_path: Array[Vector2] = []
	for cell: Vector2i in id_path:
		var point: Vector2 = cell_to_world_center(cell)
		if world_path.is_empty() and point.distance_to(from_world) <= float(get_tile_size_px()) * 0.2:
			continue
		world_path.append(point)

	if world_path.is_empty():
		world_path.append(cell_to_world_center(target_cell))
	return world_path


func rebuild_navigation() -> void:
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


func set_range_overlay(fill_cells: Array[Vector2i], border_cells: Array[Vector2i]) -> void:
	if not _has_range_overlay_layers():
		return
	_clear_cells(_range_overlay_fill_tiles, _range_overlay_fill_cells)
	_clear_cells(_range_overlay_border_tiles, _range_overlay_border_cells)

	_range_overlay_fill_cells = []
	for cell: Vector2i in fill_cells:
		if is_cell_in_bounds(cell):
			_range_overlay_fill_cells.append(cell)

	_range_overlay_border_cells = []
	for cell: Vector2i in border_cells:
		if is_cell_in_bounds(cell):
			_range_overlay_border_cells.append(cell)

	_apply_cells(_range_overlay_fill_tiles, _range_overlay_fill_cells, range_overlay_source_id, range_overlay_fill_atlas_coords)
	_apply_cells(_range_overlay_border_tiles, _range_overlay_border_cells, range_overlay_source_id, range_overlay_border_atlas_coords)


func clear_range_overlay() -> void:
	if not _has_range_overlay_layers():
		return
	_clear_cells(_range_overlay_fill_tiles, _range_overlay_fill_cells)
	_clear_cells(_range_overlay_border_tiles, _range_overlay_border_cells)
	_range_overlay_fill_cells.clear()
	_range_overlay_border_cells.clear()


func _get_play_area_center_global() -> Vector2:
	var core: Node2D = get_node_or_null(core_path) as Node2D
	if core != null:
		return core.global_position
	return global_position


func _ensure_default_ground_tiles() -> void:
	if _ground_tiles == null:
		return
	var used_rect: Rect2i = _ground_tiles.get_used_rect()
	if used_rect.size.x > 0 and used_rect.size.y > 0:
		return
	if walkable_source_id < 0:
		push_warning("BattleMap: walkable_source_id is invalid, default ground fill skipped.")
		return

	var center_cell: Vector2i = world_to_cell(_get_play_area_center_global())
	for y: int in range(-default_fill_half_extents_tiles.y, default_fill_half_extents_tiles.y + 1):
		for x: int in range(-default_fill_half_extents_tiles.x, default_fill_half_extents_tiles.x + 1):
			var cell: Vector2i = center_cell + Vector2i(x, y)
			_ground_tiles.set_cell(cell, walkable_source_id, walkable_atlas_coords, 0)


func _apply_layout_preset_if_needed() -> void:
	if layout_preset <= 0:
		return
	if _ground_tiles == null or _blocked_tiles == null or _deco_shadow_tiles == null or _deco_plant_tiles == null or _deco_props_tiles == null:
		return
	if _deco_plant_tiles.get_used_rect().size.x > 0:
		return
	if _deco_props_tiles.get_used_rect().size.x > 0:
		return

	var rect: Rect2i = _ground_tiles.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return

	_clear_layer(_blocked_tiles)
	_clear_layer(_deco_shadow_tiles)
	_clear_layer(_deco_plant_tiles)
	_clear_layer(_deco_props_tiles)

	if layout_preset == 1:
		_paint_layout_01(rect)
	elif layout_preset == 2:
		_paint_layout_02(rect)


func _paint_layout_01(rect: Rect2i) -> void:
	var y_center: int = rect.position.y + rect.size.y / 2
	var stone_variants: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(2, 1)]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 10_001

	for x: int in range(rect.position.x, rect.position.x + rect.size.x):
		for y: int in range(y_center - 1, y_center + 2):
			var stone_cell: Vector2i = Vector2i(x, y)
			var atlas: Vector2i = stone_variants[int(rng.randi() % stone_variants.size())]
			_ground_tiles.set_cell(stone_cell, 1, atlas, 0)

	_place_top_bottom_deco(rect, y_center, rng, 0)


func _paint_layout_02(rect: Rect2i) -> void:
	var y_center: int = rect.position.y + rect.size.y / 2
	var stone_variants: Array[Vector2i] = [Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20_002

	for x: int in range(rect.position.x, rect.position.x + rect.size.x):
		var bend: int = int(round(sin(float(x - rect.position.x) * 0.35) * 1.0))
		for y: int in range(y_center - 1 + bend, y_center + 2 + bend):
			if rng.randf() < 0.08:
				continue
			var stone_cell: Vector2i = Vector2i(x, y)
			var atlas: Vector2i = stone_variants[int(rng.randi() % stone_variants.size())]
			_ground_tiles.set_cell(stone_cell, 1, atlas, 0)

	_place_top_bottom_deco(rect, y_center, rng, 2)


func _place_top_bottom_deco(rect: Rect2i, y_center: int, rng: RandomNumberGenerator, style_offset: int) -> void:
	var plant_variants: Array[Vector2i] = [Vector2i(2 + style_offset, 1), Vector2i(4 + style_offset, 2), Vector2i(6 + style_offset, 3)]
	var props_variants: Array[Vector2i] = [Vector2i(8 + style_offset, 4), Vector2i(10 + style_offset, 5), Vector2i(12 + style_offset, 6)]
	var shadow_variants: Array[Vector2i] = [Vector2i(1, 1), Vector2i(3, 2), Vector2i(5, 3)]

	for x: int in range(rect.position.x + 1, rect.position.x + rect.size.x - 1):
		var top_y: int = rect.position.y + 1 + int(rng.randi() % 4)
		var bottom_y: int = rect.position.y + rect.size.y - 2 - int(rng.randi() % 4)

		if top_y < y_center - 3:
			_paint_deco_cell(Vector2i(x, top_y), rng, plant_variants, props_variants, shadow_variants)
		if bottom_y > y_center + 3:
			_paint_deco_cell(Vector2i(x, bottom_y), rng, plant_variants, props_variants, shadow_variants)

	for i: int in range(8):
		var rock_x_top: int = rect.position.x + 2 + int(rng.randi() % maxi(1, rect.size.x - 4))
		var rock_y_top: int = rect.position.y + int(rng.randi() % 3)
		_paint_big_blocking_prop(Vector2i(rock_x_top, rock_y_top), props_variants, shadow_variants)

		var rock_x_bottom: int = rect.position.x + 2 + int(rng.randi() % maxi(1, rect.size.x - 4))
		var rock_y_bottom: int = rect.position.y + rect.size.y - 1 - int(rng.randi() % 3)
		_paint_big_blocking_prop(Vector2i(rock_x_bottom, rock_y_bottom), props_variants, shadow_variants)


func _paint_deco_cell(
	cell: Vector2i,
	rng: RandomNumberGenerator,
	plant_variants: Array[Vector2i],
	props_variants: Array[Vector2i],
	shadow_variants: Array[Vector2i]
) -> void:
	if rng.randf() < 0.72:
		var plant_atlas: Vector2i = plant_variants[int(rng.randi() % plant_variants.size())]
		_deco_plant_tiles.set_cell(cell, 2, plant_atlas, 0)
		if rng.randf() < 0.65:
			var shadow_atlas: Vector2i = shadow_variants[int(rng.randi() % shadow_variants.size())]
			_deco_shadow_tiles.set_cell(cell + Vector2i(0, 1), 4, shadow_atlas, 0)
	else:
		var props_atlas: Vector2i = props_variants[int(rng.randi() % props_variants.size())]
		_deco_props_tiles.set_cell(cell, 3, props_atlas, 0)
		var shadow_atlas2: Vector2i = shadow_variants[int(rng.randi() % shadow_variants.size())]
		_deco_shadow_tiles.set_cell(cell + Vector2i(0, 1), 4, shadow_atlas2, 0)
		if rng.randf() < 0.45:
			_blocked_tiles.set_cell(cell, 0, Vector2i.ZERO, 0)


func _paint_big_blocking_prop(
	cell: Vector2i,
	props_variants: Array[Vector2i],
	shadow_variants: Array[Vector2i]
) -> void:
	var props_atlas: Vector2i = props_variants[0]
	_deco_props_tiles.set_cell(cell, 3, props_atlas, 0)
	_deco_props_tiles.set_cell(cell + Vector2i(1, 0), 3, props_variants[min(1, props_variants.size() - 1)], 0)
	_deco_shadow_tiles.set_cell(cell + Vector2i(0, 1), 4, shadow_variants[0], 0)
	_deco_shadow_tiles.set_cell(cell + Vector2i(1, 1), 4, shadow_variants[min(1, shadow_variants.size() - 1)], 0)
	_blocked_tiles.set_cell(cell, 0, Vector2i.ZERO, 0)
	_blocked_tiles.set_cell(cell + Vector2i(1, 0), 0, Vector2i.ZERO, 0)


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


func _clear_layer(layer: TileMapLayer) -> void:
	if layer == null:
		return
	layer.clear()


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
