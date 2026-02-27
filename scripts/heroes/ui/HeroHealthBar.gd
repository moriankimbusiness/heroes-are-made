extends ProgressBar
@export_group("체력 색상 구간")
## 체력 비율이 높을 때 적용할 색상입니다.
@export var hp_color_high: Color = Color(0.25, 0.85, 0.35, 1.0)
## 체력 비율이 중간일 때 적용할 색상입니다.
@export var hp_color_mid: Color = Color(0.95, 0.82, 0.20, 1.0)
## 체력 비율이 낮을 때 적용할 색상입니다.
@export var hp_color_low: Color = Color(0.90, 0.20, 0.20, 1.0)

var _hero: Node = null


func _ready() -> void:
	show_percentage = false
	_hero = get_parent()
	if _hero == null:
		return

	if _hero.has_signal("health_changed"):
		_hero.connect("health_changed", _on_hero_health_changed)

	_sync_from_hero()


func _sync_from_hero() -> void:
	if _hero == null:
		return
	if not _hero.has_method("get_current_health"):
		return
	if not _hero.has_method("get_max_health"):
		return
	if not _hero.has_method("get_health_ratio"):
		return

	var current: float = float(_hero.call("get_current_health"))
	var max_value: float = float(_hero.call("get_max_health"))
	var ratio: float = float(_hero.call("get_health_ratio"))
	_apply_health(current, max_value, ratio)


func _on_hero_health_changed(_hero_ref: Node, current: float, max_health: float, ratio: float) -> void:
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
