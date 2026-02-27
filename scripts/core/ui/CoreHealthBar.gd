extends ProgressBar
@export_group("노드 연결")
## 체력 수치 라벨(Label) 노드 경로입니다.
@export var health_text_path: NodePath = NodePath("HealthText")
@export_group("체력 색상 구간")
## 체력 비율이 높을 때 적용할 색상입니다.
@export var hp_color_high: Color = Color(0.25, 0.85, 0.35, 1.0)
## 체력 비율이 중간일 때 적용할 색상입니다.
@export var hp_color_mid: Color = Color(0.95, 0.82, 0.20, 1.0)
## 체력 비율이 낮을 때 적용할 색상입니다.
@export var hp_color_low: Color = Color(0.90, 0.20, 0.20, 1.0)

@onready var _health_text: Label = get_node_or_null(health_text_path) as Label

var _core: Node = null


func _ready() -> void:
	_core = get_parent()
	if _core == null:
		return

	if _core.has_signal("health_changed"):
		_core.connect("health_changed", _on_core_health_changed)

	_sync_from_core()


func _sync_from_core() -> void:
	if _core == null:
		return
	if not _core.has_method("get_current_health"):
		return
	if not _core.has_method("get_max_health"):
		return
	if not _core.has_method("get_health_ratio"):
		return

	var current: float = float(_core.call("get_current_health"))
	var max_health: float = float(_core.call("get_max_health"))
	var ratio: float = float(_core.call("get_health_ratio"))
	_apply_health(current, max_health, ratio)


func _on_core_health_changed(current: float, max_health: float, ratio: float) -> void:
	_apply_health(current, max_health, ratio)


func _apply_health(current: float, max_health: float, ratio: float) -> void:
	var clamped_max_health: float = maxf(1.0, max_health)
	self.max_value = clamped_max_health
	value = clampf(current, 0.0, clamped_max_health)

	if _health_text != null:
		_health_text.text = "%d / %d" % [int(roundi(value)), int(roundi(clamped_max_health))]

	if ratio > 0.5:
		modulate = hp_color_high
	elif ratio > 0.2:
		modulate = hp_color_mid
	else:
		modulate = hp_color_low
