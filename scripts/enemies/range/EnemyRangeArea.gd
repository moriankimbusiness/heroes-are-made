@tool
extends Area2D
class_name EnemyRangeArea

@export_range(1.0, 9999.0, 0.1) var base_range: float = 64.0:
	set(value):
		base_range = value
		_schedule_apply_range()

@export_range(-9999.0, 9999.0, 0.1) var range_add: float = 0.0:
	set(value):
		range_add = value
		_schedule_apply_range()

@export_range(0.1, 10.0, 0.01) var range_scale: float = 1.0:
	set(value):
		range_scale = value
		_schedule_apply_range()

@onready var _range_shape: CollisionShape2D = $CollisionShape2D
var _apply_scheduled: bool = false


func _enter_tree() -> void:
	_schedule_apply_range()


func _ready() -> void:
	_schedule_apply_range()


func get_final_range() -> float:
	return maxf(1.0, (base_range + range_add) * range_scale)


func _schedule_apply_range() -> void:
	if _apply_scheduled:
		return
	_apply_scheduled = true
	call_deferred("_apply_range_deferred")


func _apply_range_deferred() -> void:
	_apply_scheduled = false
	apply_range()


func apply_range() -> void:
	if _range_shape == null:
		return
	var circle_shape: CircleShape2D = _range_shape.shape as CircleShape2D
	if circle_shape == null:
		return
	circle_shape.radius = get_final_range()
