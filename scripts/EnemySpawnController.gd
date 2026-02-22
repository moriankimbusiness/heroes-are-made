extends Node

@export var enemy_scene: PackedScene
@export var path2d_path: NodePath
@export var portal_path: NodePath
@export var spawn_timer_path: NodePath
@export var entry_speed: float = 90.0
@export var max_spawn_count: int = 10
@export var entry_arrival_distance: float = 2.0

var _spawned_count: int = 0
var _entry_enemies: Array[Node2D] = []
var _path_start_global: Vector2 = Vector2.ZERO

@onready var _path2d: Path2D = get_node_or_null(path2d_path) as Path2D
@onready var _portal: Node2D = get_node_or_null(portal_path) as Node2D
@onready var _spawn_timer: Timer = get_node_or_null(spawn_timer_path) as Timer


func _ready() -> void:
	if enemy_scene == null:
		push_error("EnemySpawnController: enemy_scene is not assigned.")
		set_process(false)
		return
	if _path2d == null:
		push_error("EnemySpawnController: path2d_path is invalid.")
		set_process(false)
		return
	if _portal == null:
		push_error("EnemySpawnController: portal_path is invalid.")
		set_process(false)
		return
	if _spawn_timer == null:
		push_error("EnemySpawnController: spawn_timer_path is invalid.")
		set_process(false)
		return
	if _path2d.curve == null:
		push_error("EnemySpawnController: Path2D curve is missing.")
		set_process(false)
		return

	_path_start_global = _path2d.to_global(_path2d.curve.sample_baked(0.0))
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	set_process(true)


func _process(delta: float) -> void:
	for i: int in range(_entry_enemies.size() - 1, -1, -1):
		var enemy: Node2D = _entry_enemies[i]
		if not is_instance_valid(enemy):
			_entry_enemies.remove_at(i)
			continue

		enemy.global_position = enemy.global_position.move_toward(_path_start_global, entry_speed * delta)
		if enemy.global_position.distance_to(_path_start_global) <= entry_arrival_distance:
			_attach_enemy_to_path(enemy)
			_entry_enemies.remove_at(i)


func _on_spawn_timer_timeout() -> void:
	if _spawned_count >= max_spawn_count:
		_spawn_timer.stop()
		return

	var enemy: Node2D = enemy_scene.instantiate() as Node2D
	if enemy == null:
		push_error("EnemySpawnController: enemy_scene root must inherit Node2D.")
		return

	get_tree().current_scene.add_child(enemy)
	enemy.global_position = _portal.global_position
	_entry_enemies.append(enemy)
	_spawned_count += 1


func _attach_enemy_to_path(enemy: Node2D) -> void:
	var template: PathFollow2D = _path2d.get_node_or_null("EnemyPathAgentTemplate") as PathFollow2D
	if template == null:
		push_error("EnemySpawnController: EnemyPathAgentTemplate is missing under Path2D.")
		return

	var agent: PathFollow2D = template.duplicate() as PathFollow2D
	if agent == null:
		push_error("EnemySpawnController: failed to duplicate EnemyPathAgentTemplate.")
		return

	agent.name = "EnemyPathAgent"
	agent.progress = 0.0
	_path2d.add_child(agent)
	enemy.reparent(agent)
	enemy.position = Vector2.ZERO
