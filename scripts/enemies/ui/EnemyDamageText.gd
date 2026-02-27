@tool
extends Node2D
@export_group("데미지 텍스트 표시")
## 데미지 숫자 시작 Y 오프셋(px)입니다.
@export_range(0.0, 60.0, 1.0) var spawn_offset_y: float = -38.0
## 데미지 숫자가 위로 이동하는 거리(px)입니다.
@export_range(0.0, 120.0, 1.0) var rise_distance: float = 24.0
## 데미지 숫자 X축 랜덤 오프셋 최대값(px)입니다.
@export_range(0.0, 60.0, 1.0) var random_x_jitter: float = 10.0
## 데미지 숫자가 떠오르고 사라지는 시간(초)입니다.
@export_range(0.05, 3.0, 0.05) var float_duration: float = 0.6
## 데미지 숫자 폰트 크기입니다.
@export_range(8, 72, 1) var damage_font_size: int = 20
## 텍스트 외곽선 두께입니다.
@export_range(0, 16, 1) var outline_size: int = 3
## 데미지 숫자 표시에 사용할 폰트 리소스입니다.
@export var damage_font: Font
## 텍스트 본문 색상입니다.
@export var text_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## 텍스트 외곽선 색상입니다.
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 1.0)
@export_group("디버그 미리보기 (에디터 전용)")
## 에디터에서 데미지 텍스트 미리보기를 표시합니다.
@export var show_debug_preview_in_editor: bool = false:
	set(value):
		show_debug_preview_in_editor = value
		if Engine.is_editor_hint():
			_refresh_debug_preview()
## 에디터 미리보기로 표시할 데미지 값입니다.
@export_range(1.0, 99999.0, 1.0) var debug_preview_amount: float = 123.0:
	set(value):
		debug_preview_amount = value
		if Engine.is_editor_hint():
			_refresh_debug_preview()

var _enemy: Node = null


func _ready() -> void:
	if Engine.is_editor_hint():
		_refresh_debug_preview()
		return

	_enemy = get_parent()
	if _enemy == null:
		return
	if _enemy.has_signal("damage_taken"):
		_enemy.connect("damage_taken", _on_enemy_damage_taken)


func _on_enemy_damage_taken(amount: float) -> void:
	if amount <= 0.0:
		return
	_spawn_runtime_damage_popup(amount)


func _spawn_runtime_damage_popup(amount: float) -> void:
	var damage_label := Label.new()
	damage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_label.text = _format_damage_text(amount)
	damage_label.label_settings = _build_label_settings()
	damage_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

	var start_position := Vector2(randf_range(-random_x_jitter, random_x_jitter), spawn_offset_y)
	damage_label.position = start_position
	add_child(damage_label)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", start_position.y - rise_distance, float_duration)
	tween.tween_property(damage_label, "modulate:a", 0.0, float_duration)
	tween.set_parallel(false)
	tween.tween_callback(damage_label.queue_free)


func _refresh_debug_preview() -> void:
	_clear_debug_preview_labels()
	if not show_debug_preview_in_editor:
		return
	var preview_label := Label.new()
	preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_label.text = _format_damage_text(debug_preview_amount)
	preview_label.label_settings = _build_label_settings()
	preview_label.position = Vector2(0.0, spawn_offset_y)
	preview_label.set_meta("debug_preview", true)
	add_child(preview_label)


func _clear_debug_preview_labels() -> void:
	for child: Node in get_children():
		if child is Label and child.has_meta("debug_preview"):
			child.queue_free()


func _build_label_settings() -> LabelSettings:
	var settings := LabelSettings.new()
	if damage_font != null:
		settings.font = damage_font
	settings.font_size = damage_font_size
	settings.font_color = text_color
	settings.outline_size = outline_size
	settings.outline_color = outline_color
	return settings


func _format_damage_text(amount: float) -> String:
	var rounded: float = roundf(amount)
	if is_equal_approx(amount, rounded):
		return str(int(rounded))
	return "%.1f" % amount
