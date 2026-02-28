extends Node
class_name HeroAttackController

## 히어로의 자동 공격과 타겟 선택을 관리하는 컴포넌트입니다.

signal attack_requested(target: Area2D)

const SCAN_INTERVAL_SECONDS: float = 0.2

var _hero: Hero
var _timer: Timer
var _animator_node: Node
var _current_target: Area2D = null
var _pending_attack_target: Area2D = null
var _pending_attack_damage: float = 0.0
var _pending_hit_frame_fired: bool = false
var _warned_invalid_target_ids: Dictionary = {}


func configure(hero: Hero, timer: Timer, animator_node: Node) -> void:
	_hero = hero
	_timer = timer
	_animator_node = animator_node
	if _timer != null:
		_timer.one_shot = true
		_timer.timeout.connect(_on_timer_timeout)
	if _animator_node != null and _animator_node.has_signal("frame_changed"):
		_animator_node.connect("frame_changed", _on_frame_changed)


func get_current_target() -> Area2D:
	return _current_target


func attempt_auto_attack() -> void:
	if _hero == null:
		return
	if not _hero.attack_enabled or _hero.is_dead():
		return
	if _hero.is_move_order_active():
		return
	_hero.update_attack_origin_cell()

	var candidates: Array[Area2D] = _collect_attackable_targets()
	if candidates.is_empty():
		_current_target = null
		_schedule_scan()
		return

	_current_target = _pick_target(candidates)
	if _current_target == null:
		return
	if not _current_target.has_method("apply_damage"):
		_warn_once(_current_target, "apply_damage")
		_current_target = null
		if _timer != null and _timer.is_stopped():
			attempt_auto_attack()
		return

	_update_facing(_current_target)
	_queue_pending(_current_target, _hero.attack_damage)
	attack_requested.emit(_current_target)
	_try_fire_on_current_frame()
	_start_cooldown()


func stop() -> void:
	_current_target = null
	clear_pending()
	if _timer != null:
		_timer.stop()


func clear_pending() -> void:
	_pending_attack_target = null
	_pending_attack_damage = 0.0
	_pending_hit_frame_fired = false


func try_fire_on_current_frame() -> void:
	_try_fire_on_current_frame()


# -- Internal ------------------------------------------------------------------

func _on_timer_timeout() -> void:
	attempt_auto_attack()


func _on_frame_changed() -> void:
	_try_fire_on_current_frame()


func _schedule_scan() -> void:
	if _timer == null:
		return
	if _hero == null or _hero.is_dead() or not _hero.attack_enabled:
		return
	if _hero.is_move_order_active():
		return
	if not _timer.is_stopped():
		return
	_timer.start(SCAN_INTERVAL_SECONDS)


func _start_cooldown() -> void:
	if _timer == null or _hero == null:
		return
	var rate: float = maxf(0.1, _hero.attacks_per_second)
	_timer.start(1.0 / rate)


func _collect_attackable_targets() -> Array[Area2D]:
	var candidates: Array[Area2D] = []
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		if not is_instance_valid(node):
			continue
		var target: Area2D = node as Area2D
		if target == null:
			continue
		if not _is_valid_enemy_target(target):
			continue
		if not _is_within_tile_range(target):
			continue
		candidates.append(target)
	return candidates


func _pick_target(candidates: Array[Area2D]) -> Area2D:
	match _hero.target_priority:
		Hero.TargetPriority.LOWEST_HEALTH:
			return _pick_by_lowest_health(candidates)
		Hero.TargetPriority.NEAREST:
			return _pick_by_nearest(candidates)
		_:
			return _pick_by_path_progress(candidates)


func _pick_by_path_progress(candidates: Array[Area2D]) -> Area2D:
	var best: Area2D = null
	var best_progress: float = -INF
	var best_dist_sq: float = INF
	for target: Area2D in candidates:
		var progress: float = _get_path_progress(target)
		var dist_sq: float = _hero.global_position.distance_squared_to(target.global_position)
		if best == null:
			best = target
			best_progress = progress
			best_dist_sq = dist_sq
			continue
		if progress > best_progress:
			best = target
			best_progress = progress
			best_dist_sq = dist_sq
			continue
		if is_equal_approx(progress, best_progress) and dist_sq < best_dist_sq:
			best = target
			best_progress = progress
			best_dist_sq = dist_sq
	return best


func _pick_by_lowest_health(candidates: Array[Area2D]) -> Area2D:
	var best: Area2D = null
	var best_health: float = INF
	var best_progress: float = -INF
	var best_dist_sq: float = INF
	for target: Area2D in candidates:
		var health: float = _get_current_health(target)
		var progress: float = _get_path_progress(target)
		var dist_sq: float = _hero.global_position.distance_squared_to(target.global_position)
		if best == null:
			best = target
			best_health = health
			best_progress = progress
			best_dist_sq = dist_sq
			continue
		if health < best_health:
			best = target
			best_health = health
			best_progress = progress
			best_dist_sq = dist_sq
			continue
		if is_equal_approx(health, best_health) and progress > best_progress:
			best = target
			best_health = health
			best_progress = progress
			best_dist_sq = dist_sq
			continue
		if is_equal_approx(health, best_health) and is_equal_approx(progress, best_progress) and dist_sq < best_dist_sq:
			best = target
			best_health = health
			best_progress = progress
			best_dist_sq = dist_sq
	return best


func _pick_by_nearest(candidates: Array[Area2D]) -> Area2D:
	var best: Area2D = null
	var best_dist_sq: float = INF
	var best_progress: float = -INF
	for target: Area2D in candidates:
		var dist_sq: float = _hero.global_position.distance_squared_to(target.global_position)
		var progress: float = _get_path_progress(target)
		if best == null:
			best = target
			best_dist_sq = dist_sq
			best_progress = progress
			continue
		if dist_sq < best_dist_sq:
			best = target
			best_dist_sq = dist_sq
			best_progress = progress
			continue
		if is_equal_approx(dist_sq, best_dist_sq) and progress > best_progress:
			best = target
			best_dist_sq = dist_sq
			best_progress = progress
	return best


func _get_current_health(target: Area2D) -> float:
	if not is_instance_valid(target):
		return INF
	if target.has_method("get_current_health"):
		return float(target.call("get_current_health"))
	return INF


func _get_path_progress(target: Area2D) -> float:
	if not is_instance_valid(target):
		return -INF
	var parent: Node = target.get_parent()
	if parent is PathFollow2D:
		return (parent as PathFollow2D).progress
	return -1.0


func _is_within_tile_range(target: Area2D) -> bool:
	if not _is_valid_enemy_target(target):
		return false
	var source_cell: Vector2i = _hero.get_attack_origin_cell()
	var target_cell: Vector2i = _hero.world_to_cell(target.global_position)
	var radius: int = _hero.get_attack_range_tile_radius()
	return absi(target_cell.x - source_cell.x) <= radius and absi(target_cell.y - source_cell.y) <= radius


func _is_valid_enemy_target(target: Area2D) -> bool:
	if not is_instance_valid(target):
		return false
	if not target.is_in_group(&"enemy"):
		return false
	if target.has_method("is_dead") and bool(target.call("is_dead")):
		return false
	return true


func _queue_pending(target: Area2D, damage: float) -> void:
	_pending_attack_target = target
	_pending_attack_damage = damage
	_pending_hit_frame_fired = false


func _try_fire_on_current_frame() -> void:
	if _hero == null or _hero.state != Hero.State.ATTACK01:
		return
	if _pending_hit_frame_fired:
		return
	if _pending_attack_target == null:
		return
	if _animator_node == null:
		return
	var current_frame: int = int(_animator_node.call("get_current_frame"))
	if current_frame != _get_clamped_hit_frame():
		return
	_execute_pending()


func _get_clamped_hit_frame() -> int:
	if _animator_node == null or _hero == null:
		return 0
	var frame_count: int = int(_animator_node.call("get_frame_count", &"attack01"))
	if frame_count <= 0:
		return 0
	return clampi(_hero.attack_hit_frame_index, 0, frame_count - 1)


func _execute_pending() -> void:
	var target: Area2D = _pending_attack_target
	var damage: float = _pending_attack_damage
	_pending_hit_frame_fired = true
	if not _is_valid_enemy_target(target):
		return
	if not _is_within_tile_range(target):
		return
	if not target.has_method("apply_damage"):
		_warn_once(target, "apply_damage")
		return
	target.call("apply_damage", damage)


func _update_facing(target: Area2D) -> void:
	if _animator_node == null or not is_instance_valid(target) or _hero == null:
		return
	var dx: float = target.global_position.x - _hero.global_position.x
	if dx > _hero.attack_flip_deadzone:
		_animator_node.call("set_flip_h", false)
	elif dx < -_hero.attack_flip_deadzone:
		_animator_node.call("set_flip_h", true)


func _warn_once(target: Area2D, method_name: String) -> void:
	if not is_instance_valid(target):
		return
	var target_id: int = target.get_instance_id()
	if _warned_invalid_target_ids.has(target_id):
		return
	_warned_invalid_target_ids[target_id] = true
	push_warning("Hero: target '%s' is missing method '%s'." % [target.name, method_name])
