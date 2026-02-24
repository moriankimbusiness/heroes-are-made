extends Area2D

signal died(enemy: Area2D)
signal health_changed(current: float, max_value: float, ratio: float)
signal damage_taken(amount: float)

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

enum State {
	WALK,
	HURT,
	DEATH
}

@export var auto_free_on_death_end: bool = false
@export_range(0.0, 30.0, 0.1) var death_fade_duration: float = 3.0
@export var horizontal_flip_deadzone: float = 0.1
@export var base_max_health: float = 100.0

var state: State = State.WALK
var _is_finished: bool = false
var _prev_global_x: float = 0.0
var _is_dead: bool = false
var _death_fade_started: bool = false
var max_health: float = 100.0
var current_health: float = 100.0


func _ready() -> void:
	modulate.a = 1.0
	_death_fade_started = false
	set_max_health(base_max_health)
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


func play_walk() -> void:
	_play(State.WALK, true)


func play_hurt() -> void:
	_play(State.HURT, true)


func play_death() -> void:
	_play(State.DEATH, true)


func is_state_finished() -> bool:
	return _is_finished


func is_dead() -> bool:
	return _is_dead


func set_max_health(value: float, reset_current: bool = true) -> void:
	max_health = maxf(1.0, value)
	if reset_current:
		current_health = max_health
	else:
		current_health = clampf(current_health, 0.0, max_health)
	_emit_health_changed()


func apply_damage(amount: float) -> void:
	if _is_dead:
		return
	if amount <= 0.0:
		return

	var applied_damage: float = minf(current_health, amount)
	current_health = maxf(0.0, current_health - amount)
	damage_taken.emit(applied_damage)
	_emit_health_changed()
	if current_health <= 0.0:
		_die()
		return
	play_hurt()


func get_current_health() -> float:
	return current_health


func get_max_health() -> float:
	return max_health


func get_base_max_health() -> float:
	return base_max_health


func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return current_health / max_health


func _play(new_state: State, force: bool = false) -> void:
	if _is_dead and new_state != State.DEATH:
		return
	var same_state: bool = new_state == state
	if not force and same_state:
		return
	state = new_state
	_is_finished = false

	var anim_name: StringName = _anim_name_from_state(state)
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(anim_name):
		push_warning("Missing animation for state: %s" % [anim_name])
		return
	if force and same_state:
		anim.stop()
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
			_start_death_fade_and_free()
		return

	if state == State.HURT:
		_play(State.WALK, true)
		return


func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	_detach_from_path_agent()
	current_health = 0.0
	_emit_health_changed()
	play_death()
	if auto_free_on_death_end:
		_start_death_fade_and_free()
	died.emit(self)


func _detach_from_path_agent() -> void:
	var path_agent: Node = get_parent()
	if not (path_agent is PathFollow2D):
		return

	var world_parent: Node = get_tree().current_scene
	if world_parent == null:
		return

	reparent(world_parent, true)
	_prev_global_x = global_position.x
	if is_instance_valid(path_agent):
		path_agent.queue_free()


func _start_death_fade_and_free() -> void:
	if _death_fade_started:
		return
	_death_fade_started = true

	if death_fade_duration <= 0.0:
		queue_free()
		return

	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, death_fade_duration)
	tween.finished.connect(queue_free)


func _emit_health_changed() -> void:
	health_changed.emit(current_health, max_health, get_health_ratio())

func _anim_name_from_state(target_state: State) -> StringName:
	match target_state:
		State.WALK:
			return &"walk"
		State.HURT:
			return &"hurt"
		State.DEATH:
			return &"death"
	return &"walk"
