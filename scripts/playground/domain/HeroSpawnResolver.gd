extends RefCounted
class_name HeroSpawnResolver

## BattleMap 경계/가용 타일을 기준으로 히어로 스폰 셀을 선택하는 책임을 분리합니다.


func find_spawn_cell(battle_map: BattleMap, center_cell: Vector2i, is_cell_occupied: Callable) -> Vector2i:
	if battle_map == null:
		return Vector2i.ZERO

	if _is_spawnable_cell(battle_map, center_cell, is_cell_occupied):
		return center_cell

	for radius: int in range(1, 16):
		for y: int in range(-radius, radius + 1):
			for x: int in range(-radius, radius + 1):
				if abs(x) != radius and abs(y) != radius:
					continue
				var candidate: Vector2i = center_cell + Vector2i(x, y)
				if _is_spawnable_cell(battle_map, candidate, is_cell_occupied):
					return candidate

	var walkable_rect: Rect2i = battle_map.get_walkable_rect()
	for y: int in range(walkable_rect.position.y, walkable_rect.position.y + walkable_rect.size.y):
		for x: int in range(walkable_rect.position.x, walkable_rect.position.x + walkable_rect.size.x):
			var candidate: Vector2i = Vector2i(x, y)
			if _is_spawnable_cell(battle_map, candidate, is_cell_occupied):
				return candidate
	return center_cell


func _is_spawnable_cell(battle_map: BattleMap, cell: Vector2i, is_cell_occupied: Callable) -> bool:
	if not battle_map.is_cell_in_bounds(cell):
		return false
	if not battle_map.is_walkable_cell(cell):
		return false
	if not is_cell_occupied.is_valid():
		return true
	return not bool(is_cell_occupied.call(cell))
