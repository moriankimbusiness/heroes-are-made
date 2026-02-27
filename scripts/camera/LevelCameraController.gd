extends Camera2D

@export_range(50.0, 3000.0, 10.0) var move_speed: float = 600.0
@export_range(0.1, 4.0, 0.01) var zoom_min: float = 0.75
@export_range(0.1, 4.0, 0.01) var zoom_max: float = 1.6
@export_range(0.01, 1.0, 0.01) var zoom_step: float = 0.1
@export var use_move_bounds: bool = false
@export var move_bounds_center: Vector2 = Vector2.ZERO
@export var move_bounds_extents: Vector2 = Vector2.ZERO


func _ready() -> void:
	var z: float = clampf(zoom.x, zoom_min, zoom_max)
	zoom = Vector2(z, z)
	apply_move_bounds()


func _process(delta: float) -> void:
	var move_input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		move_input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		move_input.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		move_input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		move_input.x += 1.0

	if move_input.length_squared() <= 0.0:
		return

	global_position += move_input.normalized() * move_speed * delta
	apply_move_bounds()


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed:
		return

	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		apply_zoom(zoom_step)
		get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		apply_zoom(-zoom_step)
		get_viewport().set_input_as_handled()


func apply_zoom(delta_zoom: float) -> void:
	var next_zoom: float = clampf(zoom.x + delta_zoom, zoom_min, zoom_max)
	zoom = Vector2(next_zoom, next_zoom)


func apply_move_bounds() -> void:
	if not use_move_bounds:
		return
	var min_pos: Vector2 = move_bounds_center - move_bounds_extents
	var max_pos: Vector2 = move_bounds_center + move_bounds_extents
	global_position = Vector2(
		clampf(global_position.x, min_pos.x, max_pos.x),
		clampf(global_position.y, min_pos.y, max_pos.y)
	)
