extends Node
class_name EnemyTargetSelector

## 적의 대상 감지 및 추적을 관리하는 컴포넌트입니다.

signal detect_target_exited(target: Area2D)
signal attack_target_exited(target: Area2D)

var _detect_area: Area2D
var _attack_range_area: Area2D
var _detected_targets: Array[Area2D] = []
var _attack_targets: Array[Area2D] = []
var _chase_target: Area2D = null


func configure(detect_area: Area2D, attack_range_area: Area2D) -> void:
	_detect_area = detect_area
	_attack_range_area = attack_range_area
	if _detect_area != null:
		_detect_area.area_entered.connect(_on_detect_area_entered)
		_detect_area.area_exited.connect(_on_detect_area_exited)
	if _attack_range_area != null:
		_attack_range_area.area_entered.connect(_on_attack_range_entered)
		_attack_range_area.area_exited.connect(_on_attack_range_exited)


func cleanup() -> void:
	for i: int in range(_detected_targets.size() - 1, -1, -1):
		if not _is_valid_hero_target(_detected_targets[i]):
			_detected_targets.remove_at(i)
	for i: int in range(_attack_targets.size() - 1, -1, -1):
		if not _is_valid_hero_target(_attack_targets[i]):
			_attack_targets.remove_at(i)
	if _chase_target != null and not is_target_detected(_chase_target):
		_chase_target = null


func update_chase_target() -> void:
	_chase_target = _pick_closest_detected_target()


func sync_from_overlaps() -> void:
	if _detect_area != null:
		for area: Area2D in _detect_area.get_overlapping_areas():
			if _is_valid_hero_target(area) and not _detected_targets.has(area):
				_detected_targets.append(area)
	if _attack_range_area != null:
		for area: Area2D in _attack_range_area.get_overlapping_areas():
			if _is_valid_hero_target(area) and not _attack_targets.has(area):
				_attack_targets.append(area)
	update_chase_target()


func get_chase_target() -> Area2D:
	return _chase_target


func is_target_attackable(target: Area2D) -> bool:
	if not _is_valid_hero_target(target):
		return false
	return _detected_targets.has(target) and _attack_targets.has(target)


func is_target_detected(target: Area2D) -> bool:
	if not _is_valid_hero_target(target):
		return false
	return _detected_targets.has(target)


func clear_all() -> void:
	_detected_targets.clear()
	_attack_targets.clear()
	_chase_target = null


func _is_valid_hero_target(target: Area2D) -> bool:
	if not is_instance_valid(target):
		return false
	if not target.is_in_group(&"hero"):
		return false
	if target.has_method("is_dead") and bool(target.call("is_dead")):
		return false
	return true


func _pick_closest_detected_target() -> Area2D:
	var enemy: Node2D = get_parent() as Node2D
	if enemy == null:
		return null
	var enemy_pos: Vector2 = enemy.global_position
	var best: Area2D = null
	var best_dist_sq: float = INF
	for target: Area2D in _detected_targets:
		if not is_target_detected(target):
			continue
		var dist_sq: float = enemy_pos.distance_squared_to(target.global_position)
		if best == null or dist_sq < best_dist_sq:
			best = target
			best_dist_sq = dist_sq
	return best


func _on_detect_area_entered(area: Area2D) -> void:
	if not _is_valid_hero_target(area):
		return
	if not _detected_targets.has(area):
		_detected_targets.append(area)
	update_chase_target()


func _on_detect_area_exited(area: Area2D) -> void:
	_detected_targets.erase(area)
	if _chase_target == area:
		_chase_target = null
	update_chase_target()
	detect_target_exited.emit(area)


func _on_attack_range_entered(area: Area2D) -> void:
	if not _is_valid_hero_target(area):
		return
	if not _attack_targets.has(area):
		_attack_targets.append(area)


func _on_attack_range_exited(area: Area2D) -> void:
	_attack_targets.erase(area)
	attack_target_exited.emit(area)
