extends Area2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var drag_shape: CollisionShape2D = $DragShape

enum State {
	IDLE,
	WALK,
	ATTACK01,
	ATTACK02,
	HURT,
	DEATH
}

var state: State = State.IDLE
static var _any_dragging: bool = false
var _is_finished: bool = false
var _is_dead: bool = false
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_target: Vector2 = Vector2.ZERO
var _drag_velocity: Vector2 = Vector2.ZERO
var _last_nonzero_move: Vector2 = Vector2.RIGHT
var playground: Node2D = null


func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	set_process(false)
	_play(State.IDLE, true)


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if _is_dead:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_dragging = true
			_any_dragging = true
			_drag_offset = global_position - get_global_mouse_position()
			_drag_target = global_position
			_drag_velocity = Vector2.ZERO
			set_process(true)
			anim.material.set_shader_parameter(&"enabled", false)
			get_tree().call_group(&"hero", "queue_redraw")
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		_drag_target = get_global_mouse_position() + _drag_offset
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_dragging = false
			_any_dragging = false
			_drag_velocity = Vector2.ZERO
			set_process(false)
			anim.material.set_shader_parameter(&"enabled", false)
			get_tree().call_group(&"hero", "queue_redraw")
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _dragging:
		return
	var follow_alpha := clampf(delta * 20.0, 0.0, 1.0)
	var raw_target := _drag_target
	if playground:
		raw_target = playground.clamp_to_diamond(raw_target)
	_drag_velocity = _drag_velocity.lerp(raw_target - global_position, follow_alpha)
	var desired := global_position + _drag_velocity
	if playground:
		desired = playground.clamp_to_diamond(desired)
		desired = playground.resolve_overlaps_smooth(desired, self, _last_nonzero_move)
	var move := desired - global_position
	if move.length_squared() > 0.0001:
		_last_nonzero_move = move
	global_position = desired


func _draw_capsule(color: Color, width: float = 1.0) -> void:
	var cap: CapsuleShape2D = drag_shape.shape
	var off: Vector2 = drag_shape.position
	var r: float = cap.radius
	var h: float = cap.height / 2.0 - r  # half-spine
	# 상단 반원 (왼쪽→위→오른쪽)
	draw_arc(off + Vector2(0, -h), r, PI, TAU, 32, color, width)
	# 하단 반원 (오른쪽→아래→왼쪽)
	draw_arc(off + Vector2(0, h), r, 0, PI, 32, color, width)
	# 좌/우 직선
	draw_line(off + Vector2(-r, -h), off + Vector2(-r, h), color, width)
	draw_line(off + Vector2(r, -h), off + Vector2(r, h), color, width)


func _draw() -> void:
	if not _any_dragging:
		return
	if _dragging:
		_draw_capsule(Color(1.0, 1.0, 1.0, 0.6))
	else:
		_draw_capsule(Color(1.0, 1.0, 1.0, 0.25))


func _on_mouse_entered() -> void:
	if _is_dead or _any_dragging:
		return
	anim.material.set_shader_parameter(&"enabled", true)


func _on_mouse_exited() -> void:
	if _dragging:
		return
	anim.material.set_shader_parameter(&"enabled", false)


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


func is_dead() -> bool:
	return _is_dead


func _play(new_state: State, force: bool = false) -> void:
	if _is_dead and new_state != State.DEATH:
		return
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
		return
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
