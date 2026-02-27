extends Node

signal round_started(round: int)
signal round_cleared(round: int)
signal game_failed(alive_enemy_count: int, threshold: int)
signal all_rounds_cleared()
signal round_timer_updated(remaining_seconds: float)
signal next_round_available_changed(is_available: bool)

enum State {
	PREPARE,
	WAVE_ACTIVE,
	INTERMISSION,
	FAILED,
	CLEARED
}
@export_group("라운드 기본 규칙")
## 적 카운트에 사용할 그룹 이름입니다.
@export var enemy_group_name: StringName = &"enemy"
## 생존 적 수가 이 값을 넘으면 패배 처리합니다.
@export_range(1, 999, 1) var fail_alive_enemy_threshold: int = 30
## 라운드 제한 시간(초)입니다.
@export_range(1.0, 300.0, 1.0) var round_duration_seconds: float = 60.0
## 준비 완료 시 웨이브 자동 시작 여부입니다.
@export var auto_begin_wave_on_ready: bool = true

var state: State = State.PREPARE
var current_round: int = 1
var alive_enemy_count: int = 0
var remaining_round_seconds: float = 0.0
var is_next_round_available: bool = false

var _enemy_spawn_controller: Node
var _spawn_timer: Timer
var _dependencies_configured: bool = false


func configure_dependencies(enemy_spawn_controller: Node, spawn_timer: Timer) -> void:
	_enemy_spawn_controller = enemy_spawn_controller
	_spawn_timer = spawn_timer
	_dependencies_configured = _enemy_spawn_controller != null and _spawn_timer != null


func _ready() -> void:
	if not _dependencies_configured:
		push_error("RoundManager: dependencies are not configured by RoundSystem.")
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
		return

	if state != State.WAVE_ACTIVE:
		return

	remaining_round_seconds = maxf(0.0, remaining_round_seconds - _delta)
	round_timer_updated.emit(remaining_round_seconds)

	var should_show_next_round: bool = _can_advance_next_round_early()
	if should_show_next_round != is_next_round_available:
		is_next_round_available = should_show_next_round
		next_round_available_changed.emit(is_next_round_available)

	if remaining_round_seconds <= 0.0:
		_advance_to_next_round()


func set_round(round_value: int) -> void:
	current_round = maxi(1, round_value)
	if _enemy_spawn_controller != null and _enemy_spawn_controller.has_method("set_round"):
		_enemy_spawn_controller.call("set_round", current_round)


func begin_wave() -> void:
	if state == State.FAILED or state == State.CLEARED:
		return
	state = State.WAVE_ACTIVE
	set_round(current_round)
	remaining_round_seconds = round_duration_seconds
	round_timer_updated.emit(remaining_round_seconds)
	_set_next_round_available(false)
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
	_set_next_round_available(false)
	round_cleared.emit(current_round)


func request_next_round() -> void:
	if state != State.WAVE_ACTIVE:
		return
	if not is_next_round_available:
		return
	_advance_to_next_round()


func _fail_game() -> void:
	state = State.FAILED
	_stop_wave()
	_set_next_round_available(false)
	game_failed.emit(alive_enemy_count, fail_alive_enemy_threshold)


func _advance_to_next_round() -> void:
	if _is_final_round():
		state = State.CLEARED
		_stop_wave()
		_set_next_round_available(false)
		all_rounds_cleared.emit()
		return

	_stop_wave()
	_set_next_round_available(false)
	current_round += 1
	begin_wave()


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


func _can_advance_next_round_early() -> bool:
	if remaining_round_seconds <= 0.0:
		return false
	if alive_enemy_count > 0:
		return false
	if _enemy_spawn_controller != null and _enemy_spawn_controller.has_method("is_round_spawn_finished"):
		return bool(_enemy_spawn_controller.call("is_round_spawn_finished"))
	if _spawn_timer != null and not _spawn_timer.is_stopped():
		return false
	return true


func _is_final_round() -> bool:
	return current_round >= _get_total_round_count()


func get_total_round_count() -> int:
	return _get_total_round_count()


func _get_total_round_count() -> int:
	if _enemy_spawn_controller != null and _enemy_spawn_controller.has_method("get_configured_round_count"):
		return maxi(1, int(_enemy_spawn_controller.call("get_configured_round_count")))
	return maxi(1, current_round)


func _set_next_round_available(value: bool) -> void:
	if is_next_round_available == value:
		return
	is_next_round_available = value
	next_round_available_changed.emit(is_next_round_available)
