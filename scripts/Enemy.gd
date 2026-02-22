extends Area2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

enum State {
	IDLE,
	WALK,
	ATTACK01,
	ATTACK02,
	HURT,
	DEATH
}

@export var auto_return_to_idle: bool = true
@export var auto_free_on_death_end: bool = false
@export var horizontal_flip_deadzone: float = 0.1

var state: State = State.WALK
var _is_finished: bool = false
var _prev_global_x: float = 0.0


func _ready() -> void:
	_prev_global_x = global_position.x
	anim.animation_finished.connect(_on_animation_finished)
	_play(State.WALK, true)


func _process(delta: float) -> void:
	_update_facing_by_horizontal_motion()


func _update_facing_by_horizontal_motion() -> void:
	var dx: float = global_position.x - _prev_global_x

	# Rightward movement: face right (default), leftward movement: face left (flipped).
	if dx > horizontal_flip_deadzone:
		anim.flip_h = false
	elif dx < -horizontal_flip_deadzone:
		anim.flip_h = true

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
	_is_finished = false

	var anim_name: StringName = _anim_name_from_state(state)
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(anim_name):
		push_warning("Missing animation for state: %s" % [anim_name])
		return
	anim.play(anim_name)


func _on_animation_finished() -> void:
	if anim.sprite_frames == null:
		return

	var anim_name: StringName = _anim_name_from_state(state)
	if not anim.sprite_frames.has_animation(anim_name):
		return
	if anim.sprite_frames.get_animation_loop(anim_name):
		return
	if _is_finished:
		return
	_is_finished = true
	_on_non_loop_finished()


func _on_non_loop_finished() -> void:
	if state == State.DEATH:
		if auto_free_on_death_end:
			queue_free()
		return

	if auto_return_to_idle:
		_play(State.IDLE, true)

func _anim_name_from_state(target_state: State) -> StringName:
	match target_state:
		State.IDLE:
			return &"idle"
		State.WALK:
			return &"walk"
		State.ATTACK01:
			return &"attack01"
		State.ATTACK02:
			return &"attack02"
		State.HURT:
			return &"hurt"
		State.DEATH:
			return &"death"
	return &"idle"
