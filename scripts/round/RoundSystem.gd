extends Node
@export_group("RoundSystem 의존성 경로")
## RoundManager 노드 경로입니다.
@export var round_manager_path: NodePath = NodePath("RoundManager")
## EnemySpawnController 노드 경로입니다.
@export var enemy_spawn_controller_path: NodePath
## 적 스폰 타이머 노드 경로입니다.
@export var spawn_timer_path: NodePath


func _enter_tree() -> void:
	var round_manager: Node = get_node_or_null(round_manager_path)
	if round_manager == null:
		push_error("RoundSystem: round_manager_path is invalid.")
		return

	var enemy_spawn_controller: Node = get_node_or_null(enemy_spawn_controller_path)
	if enemy_spawn_controller == null:
		push_error("RoundSystem: enemy_spawn_controller_path is invalid.")
		return

	var spawn_timer: Timer = get_node_or_null(spawn_timer_path) as Timer
	if spawn_timer == null:
		push_error("RoundSystem: spawn_timer_path is invalid.")
		return

	if not round_manager.has_method("configure_dependencies"):
		push_error("RoundSystem: RoundManager missing configure_dependencies().")
		return

	round_manager.call("configure_dependencies", enemy_spawn_controller, spawn_timer)
