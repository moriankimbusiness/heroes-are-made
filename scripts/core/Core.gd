extends Area2D
class_name Core

signal health_changed(current: float, max_value: float, ratio: float)
signal destroyed(core: Area2D)
@export_group("코어 체력")
## 기본 최대 체력 값입니다.
@export_range(1.0, 999999.0, 1.0) var base_max_health: float = 300.0

var max_health: float = 300.0
var current_health: float = 300.0
var _is_destroyed: bool = false


func _ready() -> void:
	set_max_health(base_max_health)


func set_max_health(value: float, reset_current: bool = true) -> void:
	max_health = maxf(1.0, value)
	if reset_current:
		current_health = max_health
		_is_destroyed = false
	else:
		current_health = clampf(current_health, 0.0, max_health)
		_is_destroyed = current_health <= 0.0
	_emit_health_changed()


func set_current_health(value: float, emit_destroyed_signal: bool = false) -> void:
	current_health = clampf(value, 0.0, max_health)
	var was_destroyed: bool = _is_destroyed
	_is_destroyed = current_health <= 0.0
	_emit_health_changed()
	if emit_destroyed_signal and _is_destroyed and not was_destroyed:
		destroyed.emit(self)


func apply_damage(amount: float) -> void:
	if _is_destroyed:
		return
	if amount <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	_emit_health_changed()
	if current_health <= 0.0:
		_is_destroyed = true
		destroyed.emit(self)


func is_dead() -> bool:
	return _is_destroyed


func get_current_health() -> float:
	return current_health


func get_max_health() -> float:
	return max_health


func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return current_health / max_health


func _emit_health_changed() -> void:
	health_changed.emit(current_health, max_health, get_health_ratio())
