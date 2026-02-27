extends Camera2D

@export_group("카메라 이동/줌 설정")
## 이동 속도(px/s)입니다.
@export_range(50.0, 3000.0, 10.0) var move_speed: float = 600.0
## 허용되는 최소 줌 배율입니다.
@export_range(0.1, 4.0, 0.01) var zoom_min: float = 0.75
## 허용되는 최대 줌 배율입니다.
@export_range(0.1, 4.0, 0.01) var zoom_max: float = 1.6
## 마우스 휠 1틱당 변경되는 줌 값입니다.
@export_range(0.01, 1.0, 0.01) var zoom_step: float = 0.1
@export_group("카메라 이동 경계 (사용 시)")
## 카메라 이동을 경계 박스로 제한할지 여부입니다.
@export var use_move_bounds: bool = false
## 이동 경계 박스의 중심 좌표입니다.
@export var move_bounds_center: Vector2 = Vector2.ZERO
## 이동 경계 박스의 반너비/반높이입니다.
@export var move_bounds_extents: Vector2 = Vector2.ZERO

var _last_ticks_usec: int = 0


func _ready() -> void:
	var z: float = clampf(zoom.x, zoom_min, zoom_max)
	zoom = Vector2(z, z)
	apply_move_bounds()
	_last_ticks_usec = Time.get_ticks_usec()


func _process(delta: float) -> void:
	var move_delta: float = _resolve_move_delta(delta)
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

	global_position += move_input.normalized() * move_speed * move_delta
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
	apply_move_bounds()


func apply_move_bounds() -> void:
	if not use_move_bounds:
		return
	var bounds_min: Vector2 = move_bounds_center - move_bounds_extents
	var bounds_max: Vector2 = move_bounds_center + move_bounds_extents
	var viewport_size: Vector2 = get_viewport_rect().size
	var visible_half_size: Vector2 = viewport_size * 0.5 / zoom
	var min_pos: Vector2 = bounds_min + visible_half_size
	var max_pos: Vector2 = bounds_max - visible_half_size
	global_position = Vector2(
		_clamp_axis_with_fallback(global_position.x, min_pos.x, max_pos.x, bounds_min.x, bounds_max.x),
		_clamp_axis_with_fallback(global_position.y, min_pos.y, max_pos.y, bounds_min.y, bounds_max.y)
	)


func _clamp_axis_with_fallback(
	value: float,
	min_value: float,
	max_value: float,
	bounds_min_value: float,
	bounds_max_value: float
) -> float:
	if min_value > max_value:
		# 화면 전체를 경계 안에 둘 수 없는 줌 구간에서는 카메라 중심을 경계 중앙에 고정한다.
		return (bounds_min_value + bounds_max_value) * 0.5
	return clampf(value, min_value, max_value)


func _resolve_move_delta(scaled_delta: float) -> float:
	var now_usec: int = Time.get_ticks_usec()
	if _last_ticks_usec <= 0:
		_last_ticks_usec = now_usec
		return scaled_delta

	var unscaled_delta: float = float(now_usec - _last_ticks_usec) / 1_000_000.0
	_last_ticks_usec = now_usec

	if not is_equal_approx(Engine.time_scale, 0.0):
		return scaled_delta

	# Pause 복귀/포커스 전환 직후 과도한 이동 점프를 막는다.
	return clampf(unscaled_delta, 0.0, 0.05)
