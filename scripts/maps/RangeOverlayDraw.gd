extends Node2D

## 타일 사거리 셀 오버레이를 텍스처 없이 직접 드로우합니다.

@export_group("오버레이 스타일")
## 사거리 셀 내부 채움 색상(무채색 반투명)입니다.
@export var fill_color: Color = Color(1.0, 1.0, 1.0, 0.22)
## 사거리 셀 격자/윤곽선 색상입니다.
@export var border_color: Color = Color(1.0, 1.0, 1.0, 1.0)

const BORDER_WIDTH_PX: float = 1.0

var _fill_rects: Array[Rect2] = []
var _border_rects: Array[Rect2] = []


func set_overlay_rects(fill_rects: Array[Rect2], border_rects: Array[Rect2]) -> void:
	_fill_rects = fill_rects.duplicate()
	_border_rects = border_rects.duplicate()
	queue_redraw()


func clear_overlay() -> void:
	if _fill_rects.is_empty() and _border_rects.is_empty():
		return
	_fill_rects.clear()
	_border_rects.clear()
	queue_redraw()


func _draw() -> void:
	for rect: Rect2 in _fill_rects:
		draw_rect(rect, fill_color, true)

	if _border_rects.is_empty():
		return

	var segments: Dictionary = {}
	for rect: Rect2 in _border_rects:
		var top_left: Vector2 = rect.position
		var top_right: Vector2 = rect.position + Vector2(rect.size.x, 0.0)
		var bottom_right: Vector2 = rect.position + rect.size
		var bottom_left: Vector2 = rect.position + Vector2(0.0, rect.size.y)
		_register_segment(segments, top_left, top_right)
		_register_segment(segments, top_right, bottom_right)
		_register_segment(segments, bottom_right, bottom_left)
		_register_segment(segments, bottom_left, top_left)

	for segment in segments.values():
		var points: Array = segment
		if points.size() != 2:
			continue
		draw_line(points[0], points[1], border_color, BORDER_WIDTH_PX, false)


func _register_segment(segments: Dictionary, from_point: Vector2, to_point: Vector2) -> void:
	var first: Vector2 = from_point
	var second: Vector2 = to_point
	if from_point.x > to_point.x or (is_equal_approx(from_point.x, to_point.x) and from_point.y > to_point.y):
		first = to_point
		second = from_point
	var key: String = "%.3f,%.3f|%.3f,%.3f" % [first.x, first.y, second.x, second.y]
	if segments.has(key):
		return
	segments[key] = [first, second]
