extends Area2D

@onready var sprite: Sprite2D = $Sprite2D

@export var hframes_count: int = 8
@export var vframes_count: int = 6

enum State {
	IDLE,
	WALK,
	ATTACK01,
	ATTACK02,
	HURT,
	DEATH
}

@export var idle_fps: float = 8.0
@export var walk_fps: float = 10.0
@export var attack01_fps: float = 12.0
@export var attack02_fps: float = 12.0
@export var hurt_fps: float = 10.0
@export var death_fps: float = 8.0

@export var idle_last_col: int = 5
@export var walk_last_col: int = 7
@export var attack01_last_col: int = 5
@export var attack02_last_col: int = 5
@export var hurt_last_col: int = 3
@export var death_last_col: int = 3

@export var auto_return_to_idle: bool = true
@export var auto_free_on_death_end: bool = false
@export var horizontal_flip_deadzone: float = 0.1

var state: State = State.WALK
var _state_time: float = 0.0
var _frame_col: int = 0
var _is_finished: bool = false
var _anim: Dictionary = {}
var _prev_global_x: float = 0.0


func _ready() -> void:
	sprite.hframes = hframes_count
	sprite.vframes = vframes_count
	_prev_global_x = global_position.x
	_build_anim_table()
	_play(State.WALK, true)


func _process(delta: float) -> void:
	_update_facing_by_horizontal_motion()

	var data: Dictionary = _anim.get(state, {})
	if data.is_empty():
		return

	var fps: float = data.fps
	if fps <= 0.0:
		return

	_state_time += delta
	var step: float = 1.0 / fps

	while _state_time >= step:
		_state_time -= step
		_advance_frame(data)


func _update_facing_by_horizontal_motion() -> void:
	var dx: float = global_position.x - _prev_global_x

	# Rightward movement: face right (default), leftward movement: face left (flipped).
	if dx > horizontal_flip_deadzone:
		sprite.flip_h = false
	elif dx < -horizontal_flip_deadzone:
		sprite.flip_h = true

	_prev_global_x = global_position.x


func play_idle() -> void:
	_play(State.IDLE)


func play_walk() -> void:
	_play(State.WALK)


func play_attack01() -> void:
	_play(State.ATTACK01)


func play_attack02() -> void:
	_play(State.ATTACK02)


func play_hurt() -> void:
	_play(State.HURT)


func play_death() -> void:
	_play(State.DEATH)


func is_state_finished() -> bool:
	return _is_finished


func _play(new_state: State, force: bool = false) -> void:
	if not force and new_state == state:
		return
	state = new_state
	_state_time = 0.0
	_is_finished = false

	var data: Dictionary = _anim[state]
	_frame_col = data.from_col
	_apply_frame(data.row, _frame_col)


func _advance_frame(data: Dictionary) -> void:
	var from_col: int = data.from_col
	var to_col: int = data.to_col
	var loop: bool = data.loop

	_frame_col += 1
	if _frame_col > to_col:
		if loop:
			_frame_col = from_col
		else:
			_frame_col = to_col
			if not _is_finished:
				_is_finished = true
				_on_non_loop_finished()

	_apply_frame(data.row, _frame_col)


func _apply_frame(row: int, col: int) -> void:
	sprite.frame = row * sprite.hframes + col


func _on_non_loop_finished() -> void:
	if state == State.DEATH:
		if auto_free_on_death_end:
			queue_free()
		return

	if auto_return_to_idle:
		_play(State.IDLE, true)


func _build_anim_table() -> void:
	_anim = {
		State.IDLE: {"row": 0, "from_col": 0, "to_col": idle_last_col, "fps": idle_fps, "loop": true},
		State.WALK: {"row": 1, "from_col": 0, "to_col": walk_last_col, "fps": walk_fps, "loop": true},
		State.ATTACK01: {"row": 2, "from_col": 0, "to_col": attack01_last_col, "fps": attack01_fps, "loop": false},
		State.ATTACK02: {"row": 3, "from_col": 0, "to_col": attack02_last_col, "fps": attack02_fps, "loop": false},
		State.HURT: {"row": 4, "from_col": 0, "to_col": hurt_last_col, "fps": hurt_fps, "loop": false},
		State.DEATH: {"row": 5, "from_col": 0, "to_col": death_last_col, "fps": death_fps, "loop": false},
	}
