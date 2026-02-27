extends Node2D

@export_group("Shape")
## `ring_radius` 설정값.
@export var ring_radius: Vector2 = Vector2(22.0, 8.0)
## `ring_line_width` 설정값.
@export_range(0.5, 8.0, 0.1) var ring_line_width: float = 2.0
## `ring_color` 설정값.
@export var ring_color: Color = Color(0.25, 0.95, 0.45, 1.0)
## `fill_color` 설정값.
@export var fill_color: Color = Color(0.25, 0.95, 0.45, 0.2)
## `arrow_color` 설정값.
@export var arrow_color: Color = Color(0.25, 0.95, 0.45, 0.95)
## `arrow_size` 설정값.
@export var arrow_size: Vector2 = Vector2(10.0, 9.0)
## `arrow_gap` 설정값.
@export_range(0.0, 24.0, 0.1) var arrow_gap: float = 4.0

@export_group("Animation")
## `bounce_height` 설정값.
@export_range(0.0, 40.0, 0.1) var bounce_height: float = 8.0
## `bounce_duration` 설정값.
@export_range(0.05, 2.0, 0.01) var bounce_duration: float = 0.35
## `visible_duration` 설정값.
@export_range(0.05, 3.0, 0.01) var visible_duration: float = 0.75
## `fade_duration` 설정값.
@export_range(0.05, 3.0, 0.01) var fade_duration: float = 0.25

const MIN_RING_SEGMENTS: int = 24

var _draw_alpha: float = 1.0
var _bounce_offset_y: float = 0.0
var _bounce_tween: Tween = null
var _life_tween: Tween = null
var _fill_polygon: PackedVector2Array = PackedVector2Array()
var _ring_polyline: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	_rebuild_ring_geometry()
	visible = false


func show_marker(world_pos: Vector2) -> void:
	_rebuild_ring_geometry()
	global_position = world_pos
	_draw_alpha = 1.0
	_bounce_offset_y = 0.0
	visible = true
	_restart_bounce()
	_restart_life()
	queue_redraw()


func hide_marker(immediate: bool = false) -> void:
	_kill_tweens()
	_bounce_offset_y = 0.0
	if immediate:
		_draw_alpha = 0.0
	visible = false
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var alpha: float = clampf(_draw_alpha, 0.0, 1.0)
	if alpha <= 0.0:
		return

	var center: Vector2 = Vector2(0.0, _bounce_offset_y)
	var fill: Color = fill_color
	fill.a *= alpha
	var ring: Color = ring_color
	ring.a *= alpha
	var arrow: Color = arrow_color
	arrow.a *= alpha

	draw_set_transform(center, 0.0, Vector2.ONE)
	draw_colored_polygon(_fill_polygon, fill)
	draw_polyline(_ring_polyline, ring, ring_line_width, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var tip: Vector2 = center + Vector2(0.0, -ring_radius.y - arrow_gap)
	var left: Vector2 = tip + Vector2(-arrow_size.x * 0.5, -arrow_size.y)
	var right: Vector2 = tip + Vector2(arrow_size.x * 0.5, -arrow_size.y)
	draw_colored_polygon(PackedVector2Array([tip, left, right]), arrow)


func _restart_bounce() -> void:
	if bounce_height <= 0.0:
		return
	if bounce_duration <= 0.0:
		return
	if _bounce_tween != null and is_instance_valid(_bounce_tween):
		_bounce_tween.kill()
	_bounce_tween = create_tween()
	_bounce_tween.set_loops()
	_bounce_tween.tween_method(Callable(self, "_set_bounce_offset"), 0.0, -bounce_height, bounce_duration * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bounce_tween.tween_method(Callable(self, "_set_bounce_offset"), -bounce_height, 0.0, bounce_duration * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _restart_life() -> void:
	if _life_tween != null and is_instance_valid(_life_tween):
		_life_tween.kill()
	_life_tween = create_tween()
	_life_tween.tween_interval(maxf(0.01, visible_duration))
	_life_tween.tween_method(Callable(self, "_set_draw_alpha"), 1.0, 0.0, maxf(0.01, fade_duration))
	_life_tween.finished.connect(_on_life_tween_finished)


func _set_bounce_offset(value: float) -> void:
	_bounce_offset_y = value
	queue_redraw()


func _set_draw_alpha(value: float) -> void:
	_draw_alpha = clampf(value, 0.0, 1.0)
	queue_redraw()


func _on_life_tween_finished() -> void:
	hide_marker(true)


func _kill_tweens() -> void:
	if _bounce_tween != null and is_instance_valid(_bounce_tween):
		_bounce_tween.kill()
	if _life_tween != null and is_instance_valid(_life_tween):
		_life_tween.kill()
	_bounce_tween = null
	_life_tween = null


func _rebuild_ring_geometry() -> void:
	var max_radius: float = maxf(ring_radius.x, ring_radius.y)
	var segments: int = maxi(MIN_RING_SEGMENTS, int(ceili(max_radius * 1.5)))
	var points := PackedVector2Array()
	points.resize(segments)
	for i: int in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points[i] = Vector2(cos(angle) * ring_radius.x, sin(angle) * ring_radius.y)
	_fill_polygon = points
	_ring_polyline = points.duplicate()
	if _ring_polyline.size() > 0:
		_ring_polyline.append(_ring_polyline[0])
