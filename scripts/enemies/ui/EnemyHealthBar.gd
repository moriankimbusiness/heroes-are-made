extends ProgressBar

@export var hp_color_high: Color = Color(0.25, 0.85, 0.35, 1.0)
@export var hp_color_mid: Color = Color(0.95, 0.82, 0.20, 1.0)
@export var hp_color_low: Color = Color(0.90, 0.20, 0.20, 1.0)

var _enemy: Node = null


func _ready() -> void:
	show_percentage = false
	_enemy = get_parent()
	if _enemy == null:
		return

	if _enemy.has_signal("health_changed"):
		_enemy.connect("health_changed", _on_enemy_health_changed)

	_sync_from_enemy()


func _sync_from_enemy() -> void:
	if _enemy == null:
		return
	if not _enemy.has_method("get_current_health"):
		return
	if not _enemy.has_method("get_max_health"):
		return
	if not _enemy.has_method("get_health_ratio"):
		return

	var current: float = float(_enemy.call("get_current_health"))
	var max_value: float = float(_enemy.call("get_max_health"))
	var ratio: float = float(_enemy.call("get_health_ratio"))
	_apply_health(current, max_value, ratio)


func _on_enemy_health_changed(current: float, max_health: float, ratio: float) -> void:
	_apply_health(current, max_health, ratio)


func _apply_health(current: float, max_health: float, ratio: float) -> void:
	var clamped_max_health: float = maxf(1.0, max_health)
	self.max_value = clamped_max_health
	value = clampf(current, 0.0, clamped_max_health)

	if ratio > 0.5:
		modulate = hp_color_high
	elif ratio > 0.2:
		modulate = hp_color_mid
	else:
		modulate = hp_color_low
