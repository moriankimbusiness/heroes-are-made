extends Node

signal round_started(round: int)
signal round_cleared(round: int)
signal game_failed(alive_enemy_count: int, threshold: int)
signal all_rounds_cleared()

enum State {
	PREPARE,
	WAVE_ACTIVE,
	INTERMISSION,
	FAILED,
	CLEARED
}

@export var enemy_group_name: StringName = &"enemy"
@export_range(1, 999, 1) var fail_alive_enemy_threshold: int = 30
@export var enemy_spawn_controller_path: NodePath
@export var spawn_timer_path: NodePath
@export var auto_begin_wave_on_ready: bool = true

var state: State = State.PREPARE
var current_round: int = 1
var alive_enemy_count: int = 0

@onready var _enemy_spawn_controller: Node = get_node_or_null(enemy_spawn_controller_path)
@onready var _spawn_timer: Timer = get_node_or_null(spawn_timer_path) as Timer


func _ready() -> void:
	if _enemy_spawn_controller == null:
		push_error("RoundManager: enemy_spawn_controller_path is invalid.")
		set_process(false)
		return
	if _spawn_timer == null:
		push_error("RoundManager: spawn_timer_path is invalid.")
		set_process(false)
		return

	if _spawn_timer.is_stopped():
		state = State.PREPARE
	else:
		state = State.WAVE_ACTIVE

	set_round(current_round)
	if auto_begin_wave_on_ready and state == State.PREPARE:
		call_deferred("begin_wave")

	set_process(true)


func _process(_delta: float) -> void:
	alive_enemy_count = _count_alive_enemies()
	if state == State.FAILED or state == State.CLEARED:
		return
	if alive_enemy_count >= fail_alive_enemy_threshold:
		_fail_game()


func set_round(round_value: int) -> void:
	current_round = maxi(1, round_value)
	if _enemy_spawn_controller != null and _enemy_spawn_controller.has_method("set_round"):
		_enemy_spawn_controller.call("set_round", current_round)


func begin_wave() -> void:
	if state == State.FAILED or state == State.CLEARED:
		return
	state = State.WAVE_ACTIVE
	if _enemy_spawn_controller != null and _enemy_spawn_controller.has_method("begin_round_spawn"):
		_enemy_spawn_controller.call("begin_round_spawn")
	elif _spawn_timer != null and _spawn_timer.is_stopped():
		_spawn_timer.start()
	round_started.emit(current_round)


func stop_wave() -> void:
	if state != State.WAVE_ACTIVE:
		return
	_stop_wave()
	state = State.INTERMISSION
	round_cleared.emit(current_round)


func _fail_game() -> void:
	state = State.FAILED
	_stop_wave()
	game_failed.emit(alive_enemy_count, fail_alive_enemy_threshold)


func _stop_wave() -> void:
	if _enemy_spawn_controller != null and _enemy_spawn_controller.has_method("stop_spawn"):
		_enemy_spawn_controller.call("stop_spawn")
	elif _spawn_timer != null:
		_spawn_timer.stop()


func _count_alive_enemies() -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(enemy_group_name):
		if not is_instance_valid(node):
			continue
		if node.has_method("is_dead") and bool(node.call("is_dead")):
			continue
		count += 1
	return count
