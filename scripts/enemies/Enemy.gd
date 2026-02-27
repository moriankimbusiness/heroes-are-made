extends Area2D

signal died(enemy: Area2D)
signal enemy_clicked(enemy: Area2D)
signal enemy_moved(enemy: Area2D, world_position: Vector2)
signal health_changed(current: float, max_value: float, ratio: float)
signal damage_taken(amount: float)

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var status_anchor: Marker2D = $StatusAnchor
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var hero_detect_area: Area2D = $HeroDetectArea
@onready var attack_range: Area2D = $AttackRange
@onready var attack_range_shape: CollisionShape2D = $AttackRange/CollisionShape2D
@onready var attack_timer: Timer = $AttackTimer

enum State {
	WALK,
	ATTACK,
	HURT,
	DEATH
}

@export var auto_free_on_death_end: bool = false
@export_range(0.0, 30.0, 0.1) var death_fade_duration: float = 3.0
@export var horizontal_flip_deadzone: float = 0.1
@export var base_max_health: float = 100.0
@export_range(1.0, 500.0, 1.0) var move_speed: float = 70.0
@export_range(0.1, 50.0, 0.1) var core_reach_distance: float = 8.0
@export_range(0.1, 9999.0, 0.1) var attack_damage: float = 8.0
@export_range(0.1, 20.0, 0.1) var attacks_per_second: float = 1.0

@export var show_attack_range_on_select: bool = false
@export var attack_range_color: Color = Color(1.0, 0.30, 0.30, 0.85)
@export_range(0.5, 6.0, 0.1) var attack_range_line_width: float = 1.6
@export_range(0.0, 1.0, 0.01) var attack_range_fill_alpha: float = 0.08

@export var core_path: NodePath

var state: State = State.WALK
var _is_finished: bool = false
var _prev_global_x: float = 0.0
var _prev_global_position: Vector2 = Vector2.ZERO
var _is_dead: bool = false
var _death_fade_started: bool = false
var max_health: float = 100.0
var current_health: float = 100.0
var _core_target: Node2D = null
var _detected_targets: Array[Area2D] = []
var _attack_targets: Array[Area2D] = []
var _chase_target: Area2D = null
var _current_target: Area2D = null
var _is_attacking_core: bool = false


func _ready() -> void:
	modulate.a = 1.0
	_death_fade_started = false
	set_max_health(base_max_health)
	_prev_global_x = global_position.x
	_prev_global_position = global_position
	anim.animation_finished.connect(_on_animation_finished)
	_apply_range_settings()
	if hero_detect_area != null:
		hero_detect_area.area_entered.connect(_on_hero_detect_area_entered)
		hero_detect_area.area_exited.connect(_on_hero_detect_area_exited)
	if attack_range != null:
		attack_range.area_entered.connect(_on_attack_range_area_entered)
		attack_range.area_exited.connect(_on_attack_range_area_exited)
	if attack_timer != null:
		attack_timer.one_shot = true
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	_resolve_core_target()
	call_deferred("_sync_targets_from_overlaps")
	_play(State.WALK, true)


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if _is_dead:
		return
	if event is not InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	enemy_clicked.emit(self)
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_update_facing()
	_emit_moved_if_needed()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_is_attacking_core = false
	_cleanup_targets()
	_refresh_chase_target()

	if _chase_target != null:
		if _is_target_attackable(_chase_target):
			_current_target = _chase_target
			_handle_attack_state()
			return
		_current_target = null
		_move_toward_target(_chase_target.global_position, delta)
		return

	if _current_target != null:
		_handle_attack_state()
		return

	if _is_core_attackable():
		_is_attacking_core = true
		_handle_core_attack_state()
		return

	_move_toward_core(delta)


func play_walk() -> void:
	_play(State.WALK, true)


func play_attack() -> void:
	_play(State.ATTACK, true)


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


func get_status_anchor_canvas_position() -> Vector2:
	if status_anchor != null:
		return status_anchor.get_global_transform_with_canvas().origin
	return get_global_transform_with_canvas().origin


func get_final_detect_range() -> float:
	return _get_area_final_range(hero_detect_area)


func get_final_attack_range() -> float:
	return _get_area_final_range(attack_range)


func set_attack_range_preview_visible(visible: bool) -> void:
	if show_attack_range_on_select == visible:
		return
	show_attack_range_on_select = visible
	queue_redraw()


func set_core_target(target: Node2D) -> void:
	_core_target = target


func _handle_attack_state() -> void:
	if not _is_target_attackable(_current_target):
		_current_target = null
		_play(State.WALK)
		return

	_face_toward(_current_target.global_position)
	if attack_timer != null and not attack_timer.is_stopped():
		if state != State.ATTACK:
			_play(State.ATTACK)
		return
	_perform_attack()


func _handle_core_attack_state() -> void:
	if not _is_core_attackable():
		_play(State.WALK)
		return

	_face_toward(_get_core_attack_focus_position())
	if attack_timer != null and not attack_timer.is_stopped():
		if state != State.ATTACK:
			_play(State.ATTACK)
		return
	_perform_core_attack()


func _perform_attack() -> void:
	if not _is_target_attackable(_current_target):
		return

	# Explicit attack trigger always restarts the animation.
	play_attack()
	if _current_target.has_method("apply_damage"):
		_current_target.call("apply_damage", attack_damage)
	if attack_timer != null:
		attack_timer.start(_get_attack_cooldown_seconds())


func _perform_core_attack() -> void:
	if not _is_core_attackable():
		return
	if _core_target == null:
		return

	play_attack()
	if _core_target.has_method("apply_damage"):
		_core_target.call("apply_damage", attack_damage)
	if attack_timer != null:
		attack_timer.start(_get_attack_cooldown_seconds())


func _move_toward_core(delta: float) -> void:
	if _core_target == null or not is_instance_valid(_core_target):
		_resolve_core_target()
	if _core_target == null:
		return

	var core_position: Vector2 = _get_core_approach_position(global_position)
	if global_position.distance_to(core_position) <= core_reach_distance:
		if state != State.WALK:
			_play(State.WALK)
		return

	var next_position: Vector2 = core_position
	if navigation_agent != null:
		navigation_agent.target_position = core_position
		var path_next: Vector2 = navigation_agent.get_next_path_position()
		if path_next.is_finite():
			var direct_to_core: float = global_position.distance_to(core_position)
			var next_to_core: float = path_next.distance_to(core_position)
			if next_to_core <= direct_to_core + 16.0:
				next_position = path_next

	var direction: Vector2 = next_position - global_position
	if direction.length_squared() <= 0.0001:
		direction = core_position - global_position
	if direction.length_squared() <= 0.0001:
		return

	global_position += direction.normalized() * move_speed * delta
	if state != State.WALK:
		_play(State.WALK)


func _move_toward_target(target_position: Vector2, delta: float) -> void:
	var next_position: Vector2 = target_position
	if navigation_agent != null:
		navigation_agent.target_position = target_position
		var path_next: Vector2 = navigation_agent.get_next_path_position()
		if path_next.is_finite():
			var direct_to_target: float = global_position.distance_to(target_position)
			var next_to_target: float = path_next.distance_to(target_position)
			if next_to_target <= direct_to_target + 16.0:
				next_position = path_next

	var direction: Vector2 = next_position - global_position
	if direction.length_squared() <= 0.0001:
		direction = target_position - global_position
	if direction.length_squared() <= 0.0001:
		if state != State.WALK:
			_play(State.WALK)
		return

	_face_toward(target_position)
	global_position += direction.normalized() * move_speed * delta
	if state != State.WALK:
		_play(State.WALK)


func _get_core_approach_position(from_position: Vector2) -> Vector2:
	if _core_target == null:
		return from_position
	var core_collision: CollisionShape2D = _core_target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if core_collision == null:
		return _core_target.global_position
	var rect: RectangleShape2D = core_collision.shape as RectangleShape2D
	if rect == null:
		return _core_target.global_position

	var half_extents: Vector2 = rect.size * 0.5
	var core_center: Vector2 = core_collision.global_position
	var local: Vector2 = from_position - core_center
	var boundary: Vector2 = Vector2(
		clampf(local.x, -half_extents.x, half_extents.x),
		clampf(local.y, -half_extents.y, half_extents.y)
	)
	var is_inside: bool = absf(local.x) <= half_extents.x and absf(local.y) <= half_extents.y
	if is_inside:
		var x_gap: float = half_extents.x - absf(local.x)
		var y_gap: float = half_extents.y - absf(local.y)
		if x_gap < y_gap:
			var x_sign: float = signf(local.x)
			if is_zero_approx(x_sign):
				x_sign = 1.0
			boundary.x = half_extents.x * x_sign
		else:
			var y_sign: float = signf(local.y)
			if is_zero_approx(y_sign):
				y_sign = 1.0
			boundary.y = half_extents.y * y_sign
	return core_center + boundary


func _on_hero_detect_area_entered(area: Area2D) -> void:
	if not _is_valid_hero_target(area):
		return
	if not _detected_targets.has(area):
		_detected_targets.append(area)
	_refresh_chase_target()


func _on_hero_detect_area_exited(area: Area2D) -> void:
	_detected_targets.erase(area)
	if _chase_target == area:
		_chase_target = null
	_refresh_chase_target()
	if _current_target == area and not _is_target_attackable(area):
		_current_target = null
		_play(State.WALK)


func _on_attack_range_area_entered(area: Area2D) -> void:
	if not _is_valid_hero_target(area):
		return
	if not _attack_targets.has(area):
		_attack_targets.append(area)


func _on_attack_range_area_exited(area: Area2D) -> void:
	_attack_targets.erase(area)
	if _current_target == area and not _is_target_attackable(area):
		_current_target = null
		_play(State.WALK)


func _on_attack_timer_timeout() -> void:
	_cleanup_targets()
	_refresh_chase_target()
	if _chase_target != null:
		if _is_target_attackable(_chase_target):
			_current_target = _chase_target
			_perform_attack()
		else:
			_current_target = null
			_play(State.WALK)
		return
	_current_target = null
	if _is_core_attackable():
		_perform_core_attack()
		return
	_play(State.WALK)


func _cleanup_targets() -> void:
	for i: int in range(_detected_targets.size() - 1, -1, -1):
		var target: Area2D = _detected_targets[i]
		if not _is_valid_hero_target(target):
			_detected_targets.remove_at(i)
	for i: int in range(_attack_targets.size() - 1, -1, -1):
		var target: Area2D = _attack_targets[i]
		if not _is_valid_hero_target(target):
			_attack_targets.remove_at(i)
	if _chase_target != null and not _is_target_detected(_chase_target):
		_chase_target = null
	if _current_target != null and not _is_target_attackable(_current_target):
		_current_target = null


func _pick_chase_target() -> Area2D:
	var best_target: Area2D = null
	var best_distance_sq: float = INF
	for target: Area2D in _detected_targets:
		if not _is_target_detected(target):
			continue
		var distance_sq: float = global_position.distance_squared_to(target.global_position)
		if best_target == null or distance_sq < best_distance_sq:
			best_target = target
			best_distance_sq = distance_sq
	return best_target


func _refresh_chase_target() -> void:
	_chase_target = _pick_chase_target()


func _sync_targets_from_overlaps() -> void:
	if hero_detect_area != null:
		for area: Area2D in hero_detect_area.get_overlapping_areas():
			if not _is_valid_hero_target(area):
				continue
			if not _detected_targets.has(area):
				_detected_targets.append(area)
	if attack_range != null:
		for area: Area2D in attack_range.get_overlapping_areas():
			if not _is_valid_hero_target(area):
				continue
			if not _attack_targets.has(area):
				_attack_targets.append(area)
	_refresh_chase_target()


func _resolve_core_target() -> void:
	if core_path != NodePath():
		var node_from_path: Node2D = get_node_or_null(core_path) as Node2D
		if node_from_path != null:
			_core_target = node_from_path
			return

	var node: Node = get_tree().get_first_node_in_group(&"core")
	if node is Node2D:
		_core_target = node as Node2D


func _update_facing() -> void:
	if _current_target != null and _is_target_attackable(_current_target):
		_face_toward(_current_target.global_position)
		_prev_global_x = global_position.x
		return
	if _chase_target != null and _is_target_detected(_chase_target):
		_face_toward(_chase_target.global_position)
		_prev_global_x = global_position.x
		return
	if _is_attacking_core and _core_target != null and is_instance_valid(_core_target):
		_face_toward(_get_core_attack_focus_position())
		_prev_global_x = global_position.x
		return

	var dx: float = global_position.x - _prev_global_x
	if dx > horizontal_flip_deadzone:
		anim.flip_h = false
	elif dx < -horizontal_flip_deadzone:
		anim.flip_h = true
	_prev_global_x = global_position.x


func _face_toward(target_position: Vector2) -> void:
	var dx: float = target_position.x - global_position.x
	if dx > horizontal_flip_deadzone:
		anim.flip_h = false
	elif dx < -horizontal_flip_deadzone:
		anim.flip_h = true


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
		if state == State.ATTACK and anim.sprite_frames != null and anim.sprite_frames.has_animation(&"walk"):
			anim_name = &"walk"
		else:
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
		if _current_target != null:
			_play(State.ATTACK)
		else:
			_play(State.WALK, true)
		return


func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	_is_attacking_core = false
	_detach_from_path_agent()
	current_health = 0.0
	_emit_health_changed()
	_current_target = null
	_chase_target = null
	_detected_targets.clear()
	_attack_targets.clear()
	if attack_timer != null:
		attack_timer.stop()
	set_attack_range_preview_visible(false)
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
	_prev_global_position = global_position
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


func _emit_moved_if_needed() -> void:
	if global_position.is_equal_approx(_prev_global_position):
		return
	_prev_global_position = global_position
	enemy_moved.emit(self, global_position)


func _get_attack_cooldown_seconds() -> float:
	var rate: float = maxf(0.1, attacks_per_second)
	return 1.0 / rate


func _is_valid_hero_target(target: Area2D) -> bool:
	if not is_instance_valid(target):
		return false
	if not target.is_in_group(&"hero"):
		return false
	if target.has_method("is_dead") and bool(target.call("is_dead")):
		return false
	return true


func _is_target_attackable(target: Area2D) -> bool:
	if not _is_valid_hero_target(target):
		return false
	if not _detected_targets.has(target):
		return false
	if not _attack_targets.has(target):
		return false
	return true


func _is_target_detected(target: Area2D) -> bool:
	if not _is_valid_hero_target(target):
		return false
	if not _detected_targets.has(target):
		return false
	return true


func _is_core_attackable() -> bool:
	if _core_target == null or not is_instance_valid(_core_target):
		return false
	if _core_target.has_method("is_dead") and bool(_core_target.call("is_dead")):
		return false
	if not _core_target.has_method("apply_damage"):
		return false
	return _is_core_inside_attack_range()


func _is_core_inside_attack_range() -> bool:
	if _core_target == null or not is_instance_valid(_core_target):
		return false
	var attack_radius: float = get_final_attack_range()
	if attack_radius <= 0.0:
		return false

	var attack_center: Vector2 = global_position
	if attack_range_shape != null:
		attack_center = attack_range_shape.global_position
	elif attack_range != null:
		attack_center = attack_range.global_position

	var core_collision: CollisionShape2D = _core_target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if core_collision == null:
		return attack_center.distance_to(_core_target.global_position) <= attack_radius

	var rect: RectangleShape2D = core_collision.shape as RectangleShape2D
	if rect == null:
		return attack_center.distance_to(_core_target.global_position) <= attack_radius

	var half_extents: Vector2 = rect.size * 0.5
	var attack_center_local: Vector2 = core_collision.to_local(attack_center)
	var closest_local: Vector2 = Vector2(
		clampf(attack_center_local.x, -half_extents.x, half_extents.x),
		clampf(attack_center_local.y, -half_extents.y, half_extents.y)
	)
	var closest_global: Vector2 = core_collision.to_global(closest_local)
	return attack_center.distance_squared_to(closest_global) <= attack_radius * attack_radius


func _get_core_attack_focus_position() -> Vector2:
	if _core_target == null or not is_instance_valid(_core_target):
		return global_position
	var target_anchor: Node2D = _core_target.get_node_or_null("TargetAnchor") as Node2D
	if target_anchor != null:
		return target_anchor.global_position
	return _core_target.global_position


func _apply_range_settings() -> void:
	if hero_detect_area != null and hero_detect_area.has_method("apply_range"):
		hero_detect_area.call("apply_range")
	if attack_range != null and attack_range.has_method("apply_range"):
		attack_range.call("apply_range")
	if show_attack_range_on_select:
		queue_redraw()


func _get_area_final_range(range_area: Area2D) -> float:
	if range_area == null:
		return 0.0
	if range_area.has_method("get_final_range"):
		return float(range_area.call("get_final_range"))
	return 0.0


func _draw_attack_range_preview() -> void:
	if attack_range_shape == null:
		return
	var circle_shape: CircleShape2D = attack_range_shape.shape as CircleShape2D
	if circle_shape == null:
		return
	var center: Vector2 = attack_range.position + attack_range_shape.position
	var radius: float = circle_shape.radius
	var fill_color := attack_range_color
	fill_color.a = clampf(attack_range_fill_alpha, 0.0, 1.0)
	draw_circle(center, radius, fill_color)
	draw_arc(center, radius, 0.0, TAU, 72, attack_range_color, attack_range_line_width)


func _draw() -> void:
	if not show_attack_range_on_select:
		return
	_draw_attack_range_preview()


func _anim_name_from_state(target_state: State) -> StringName:
	match target_state:
		State.WALK:
			return &"walk"
		State.ATTACK:
			return &"attack"
		State.HURT:
			return &"hurt"
		State.DEATH:
			return &"death"
	return &"walk"
