extends Control

## 적 선택 시 화면 좌상단에 표시되는 적 상태 패널입니다.

@onready var enemy_name_label: Label = $EnemyStatusPanel/MarginContainer/VBoxContainer/EnemyNameLabel
@onready var enemy_health_bar: ProgressBar = $EnemyStatusPanel/MarginContainer/VBoxContainer/EnemyHealthBar
@onready var enemy_health_label: Label = $EnemyStatusPanel/MarginContainer/VBoxContainer/EnemyHealthLabel

var _bound_enemy: Area2D = null


func _ready() -> void:
	visible = false
	_clear_display()


func bind_enemy(enemy: Area2D) -> void:
	if enemy == _bound_enemy:
		return
	unbind_enemy()
	if enemy == null:
		return
	if not is_instance_valid(enemy):
		return
	_bound_enemy = enemy
	if _bound_enemy.has_signal("health_changed"):
		_bound_enemy.connect("health_changed", Callable(self, "_on_enemy_health_changed"))
	visible = true
	_refresh_enemy_name()
	_refresh_enemy_health_label()


func unbind_enemy() -> void:
	if _bound_enemy != null and is_instance_valid(_bound_enemy):
		if _bound_enemy.has_signal("health_changed"):
			if _bound_enemy.is_connected("health_changed", Callable(self, "_on_enemy_health_changed")):
				_bound_enemy.disconnect("health_changed", Callable(self, "_on_enemy_health_changed"))
	_bound_enemy = null
	visible = false
	_clear_display()


func _on_enemy_health_changed(current: float, max_value: float, _ratio: float) -> void:
	_refresh_enemy_health_from_values(current, max_value)


func _clear_display() -> void:
	enemy_name_label.text = "Enemy"
	enemy_health_bar.max_value = 1.0
	enemy_health_bar.value = 0.0
	enemy_health_label.text = "체력: - / -"


func _refresh_enemy_name() -> void:
	if _bound_enemy == null or not is_instance_valid(_bound_enemy):
		enemy_name_label.text = "Enemy"
		return
	if _bound_enemy.has_method("get_display_name"):
		enemy_name_label.text = str(_bound_enemy.call("get_display_name"))
	else:
		enemy_name_label.text = _bound_enemy.name


func _refresh_enemy_health_label() -> void:
	if _bound_enemy == null or not is_instance_valid(_bound_enemy):
		_clear_display()
		return
	if not _bound_enemy.has_method("get_current_health"):
		_clear_display()
		return
	if not _bound_enemy.has_method("get_max_health"):
		_clear_display()
		return
	var current: float = float(_bound_enemy.call("get_current_health"))
	var max_value: float = float(_bound_enemy.call("get_max_health"))
	_refresh_enemy_health_from_values(current, max_value)


func _refresh_enemy_health_from_values(current: float, max_value: float) -> void:
	var clamped_max: float = maxf(1.0, max_value)
	var clamped_current: float = clampf(current, 0.0, clamped_max)
	enemy_health_bar.max_value = clamped_max
	enemy_health_bar.value = clamped_current
	var max_int: int = maxi(1, roundi(max_value))
	var current_int: int = clampi(roundi(current), 0, max_int)
	enemy_health_label.text = "체력: %d / %d" % [current_int, max_int]
	_update_health_bar_color(clamped_current / clamped_max)


func _update_health_bar_color(ratio: float) -> void:
	var style: StyleBoxFlat = enemy_health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if style == null:
		style = StyleBoxFlat.new()
		enemy_health_bar.add_theme_stylebox_override("fill", style)
	if ratio > 0.5:
		style.bg_color = Color(0.25, 0.85, 0.35, 1.0)
	elif ratio > 0.2:
		style.bg_color = Color(0.95, 0.82, 0.20, 1.0)
	else:
		style.bg_color = Color(0.90, 0.20, 0.20, 1.0)
