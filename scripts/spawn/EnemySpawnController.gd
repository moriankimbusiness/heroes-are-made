extends Node

@export_group("라운드 기본 스폰")
@export var enemy_scene: PackedScene
@export var round_enemy_scenes: Array[PackedScene] = []
@export var round_spawn_counts: Array[int] = []
@export var round_enemy_health_multipliers: Array[float] = []
@export_range(0.1, 10.0, 0.1) var level_hp_scale: float = 1.0
@export_group("체력 공식 (테이블 이후)")
@export var use_formula_after_table: bool = true
@export_range(0.0, 1.0, 0.001) var formula_growth_rate: float = 0.08
@export_range(0.0, 1.0, 0.001) var formula_softcap_rate: float = 0.015
@export_range(0.0, 3.0, 0.01) var formula_softcap_power: float = 0.6
@export_group("필수 노드 경로")
@export var portal_path: NodePath
@export var core_path: NodePath
@export var spawn_timer_path: NodePath
@export_group("런타임 제어")
@export var max_spawn_count: int = 10
@export_range(1, 999, 1) var current_round: int = 1

var _spawned_count: int = 0

@onready var _portal: Node2D = get_node_or_null(portal_path) as Node2D
@onready var _core: Node2D = get_node_or_null(core_path) as Node2D
@onready var _spawn_timer: Timer = get_node_or_null(spawn_timer_path) as Timer


func _ready() -> void:
	if enemy_scene == null:
		push_error("EnemySpawnController: enemy_scene is not assigned.")
		return
	if _portal == null:
		push_error("EnemySpawnController: portal_path is invalid.")
		return
	if _spawn_timer == null:
		push_error("EnemySpawnController: spawn_timer_path is invalid.")
		return

	if _core == null:
		var core_node: Node = get_tree().get_first_node_in_group(&"core")
		if core_node is Node2D:
			_core = core_node as Node2D

	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)


func _on_spawn_timer_timeout() -> void:
	if _spawned_count >= max_spawn_count:
		_spawn_timer.stop()
		return

	var selected_enemy_scene: PackedScene = _get_enemy_scene_for_current_round()
	if selected_enemy_scene == null:
		push_error("EnemySpawnController: enemy scene is not assigned.")
		return

	var enemy: Node2D = selected_enemy_scene.instantiate() as Node2D
	if enemy == null:
		push_error("EnemySpawnController: selected enemy scene root must inherit Node2D.")
		return

	get_tree().current_scene.add_child(enemy)
	_apply_round_health_multiplier(enemy)
	enemy.global_position = _portal.global_position
	if _core != null and enemy.has_method("set_core_target"):
		enemy.call("set_core_target", _core)
	_spawned_count += 1


func set_round(round_value: int) -> void:
	current_round = maxi(1, round_value)


func begin_round_spawn() -> void:
	_spawned_count = 0
	max_spawn_count = _get_spawn_count_for_current_round()
	if _spawn_timer != null:
		_spawn_timer.start()


func stop_spawn() -> void:
	if _spawn_timer != null:
		_spawn_timer.stop()


func is_round_spawn_finished() -> bool:
	if _spawned_count < max_spawn_count:
		return false
	if _spawn_timer != null and not _spawn_timer.is_stopped():
		return false
	return true


func get_configured_round_count() -> int:
	var configured_round_count: int = 1
	configured_round_count = maxi(configured_round_count, round_enemy_scenes.size())
	configured_round_count = maxi(configured_round_count, round_spawn_counts.size())
	configured_round_count = maxi(configured_round_count, round_enemy_health_multipliers.size())
	return configured_round_count


func _get_enemy_scene_for_current_round() -> PackedScene:
	var round_index: int = current_round - 1
	if round_index >= 0 and round_index < round_enemy_scenes.size():
		var candidate: PackedScene = round_enemy_scenes[round_index]
		if candidate != null:
			return candidate
	return enemy_scene


func _get_spawn_count_for_current_round() -> int:
	var round_index: int = current_round - 1
	if round_index >= 0 and round_index < round_spawn_counts.size():
		var candidate: int = round_spawn_counts[round_index]
		if candidate > 0:
			return candidate

	if round_spawn_counts.size() > 0:
		var fallback: int = round_spawn_counts[round_spawn_counts.size() - 1]
		if fallback > 0:
			return fallback

	return maxi(1, max_spawn_count)


func _apply_round_health_multiplier(enemy: Node) -> void:
	if not enemy.has_method("set_max_health"):
		return

	var base_max_health: float = 100.0
	if enemy.has_method("get_base_max_health"):
		base_max_health = float(enemy.call("get_base_max_health"))
	elif enemy.has_method("get_max_health"):
		base_max_health = float(enemy.call("get_max_health"))

	var multiplier: float = _get_health_multiplier_for_current_round()
	enemy.call("set_max_health", base_max_health * level_hp_scale * multiplier)


func _get_health_multiplier_for_current_round() -> float:
	var round_index: int = current_round - 1
	if round_index >= 0 and round_index < round_enemy_health_multipliers.size():
		var candidate: float = round_enemy_health_multipliers[round_index]
		if candidate > 0.0:
			return candidate

	if use_formula_after_table:
		return _get_formula_health_multiplier_for_current_round()

	if round_enemy_health_multipliers.size() > 0:
		var fallback: float = round_enemy_health_multipliers[round_enemy_health_multipliers.size() - 1]
		if fallback > 0.0:
			return fallback

	return 1.0


func _get_formula_health_multiplier_for_current_round() -> float:
	var table_size: int = round_enemy_health_multipliers.size()
	var formula_round: int = max(1, current_round - table_size)

	var base_multiplier: float = 1.0
	if table_size > 0:
		var table_last: float = round_enemy_health_multipliers[table_size - 1]
		if table_last > 0.0:
			base_multiplier = table_last

	var growth_factor: float = pow(1.0 + formula_growth_rate, formula_round)
	var softcap_base: float = maxf(1.0, 1.0 + formula_softcap_rate * float(formula_round))
	var softcap_factor: float = pow(softcap_base, formula_softcap_power)
	if softcap_factor <= 0.0:
		softcap_factor = 1.0

	return maxf(1.0, base_multiplier * growth_factor / softcap_factor)
