extends Control
@export_group("RoundTopCenterUI 노드 경로")
## 라운드 카운트다운 라벨 노드 경로입니다.
@export var round_countdown_label_path: NodePath
## 다음 라운드 버튼 노드 경로입니다.
@export var next_round_button_path: NodePath
## 일시정지 버튼 노드 경로입니다.
@export var pause_button_path: NodePath
## 1배속 버튼 노드 경로입니다.
@export var speed_1x_button_path: NodePath
## 2배속 버튼 노드 경로입니다.
@export var speed_2x_button_path: NodePath
var _debug_show_next_round_button: bool = false
@export_group("디버그 표시")
## 다음 라운드 버튼을 디버그 용도로 강제 표시합니다.
@export var debug_show_next_round_button: bool:
	set(value):
		if _debug_show_next_round_button == value:
			return
		_debug_show_next_round_button = value
		_apply_visibility()
	get:
		return _debug_show_next_round_button

@onready var _round_countdown_label: Label = get_node_or_null(round_countdown_label_path) as Label
@onready var _next_round_button: Button = get_node_or_null(next_round_button_path) as Button
@onready var _pause_button: Button = get_node_or_null(pause_button_path) as Button
@onready var _speed_1x_button: Button = get_node_or_null(speed_1x_button_path) as Button
@onready var _speed_2x_button: Button = get_node_or_null(speed_2x_button_path) as Button

var _round_manager: Node
var _next_round_button_auto_visible: bool = false
var _current_speed_scale: float = 1.0

const SPEED_PAUSED: float = 0.0
const SPEED_NORMAL: float = 1.0
const SPEED_FAST: float = 2.0


func _ready() -> void:
	if _round_countdown_label == null or _next_round_button == null:
		push_error("RoundTopCenterUI: round node paths are invalid.")
		return
	if _pause_button == null or _speed_1x_button == null or _speed_2x_button == null:
		push_error("RoundTopCenterUI: node paths are invalid.")
		return
	_next_round_button.pressed.connect(_on_next_round_button_pressed)
	_pause_button.pressed.connect(_on_pause_button_pressed)
	_speed_1x_button.pressed.connect(_on_speed_1x_button_pressed)
	_speed_2x_button.pressed.connect(_on_speed_2x_button_pressed)
	_update_round_countdown_label()
	_set_game_speed(SPEED_NORMAL)
	_apply_visibility()


func set_round_manager(manager: Node) -> void:
	_round_manager = manager
	if _round_manager == null:
		_set_next_round_button_visible(false)
		return

	if _round_manager.has_signal("round_timer_updated"):
		_round_manager.connect("round_timer_updated", _on_round_timer_updated)
	if _round_manager.has_signal("next_round_available_changed"):
		_round_manager.connect("next_round_available_changed", _on_next_round_available_changed)
	if _round_manager.has_signal("all_rounds_cleared"):
		_round_manager.connect("all_rounds_cleared", _on_all_rounds_cleared)

	_update_round_countdown_label(float(_round_manager.get("remaining_round_seconds")))
	_set_next_round_button_visible(bool(_round_manager.get("is_next_round_available")))


func _on_round_timer_updated(remaining_seconds: float) -> void:
	_update_round_countdown_label(remaining_seconds)


func _on_next_round_available_changed(is_available: bool) -> void:
	_set_next_round_button_visible(is_available)


func _on_all_rounds_cleared() -> void:
	_set_next_round_button_visible(false)


func _on_next_round_button_pressed() -> void:
	if _round_manager != null and _round_manager.has_method("request_next_round"):
		_round_manager.call("request_next_round")


func _on_pause_button_pressed() -> void:
	_set_game_speed(SPEED_PAUSED)


func _on_speed_1x_button_pressed() -> void:
	_set_game_speed(SPEED_NORMAL)


func _on_speed_2x_button_pressed() -> void:
	_set_game_speed(SPEED_FAST)


func _update_round_countdown_label(remaining_seconds: float = -1.0) -> void:
	var value: float = remaining_seconds
	if value < 0.0 and _round_manager != null:
		value = float(_round_manager.get("remaining_round_seconds"))
	var seconds: int = maxi(0, int(ceil(value)))
	_round_countdown_label.text = "Next Round In: %ds" % seconds


func _set_next_round_button_visible(value: bool) -> void:
	_next_round_button_auto_visible = value
	_apply_visibility()


func _apply_visibility() -> void:
	if _next_round_button == null:
		return
	if debug_show_next_round_button:
		_next_round_button.visible = debug_show_next_round_button
		return
	_next_round_button.visible = _next_round_button_auto_visible


func _set_game_speed(speed_scale: float) -> void:
	_current_speed_scale = maxf(0.0, speed_scale)
	Engine.time_scale = _current_speed_scale
	_apply_speed_button_state()


func _apply_speed_button_state() -> void:
	if _pause_button == null or _speed_1x_button == null or _speed_2x_button == null:
		return
	_pause_button.disabled = is_equal_approx(_current_speed_scale, SPEED_PAUSED)
	_speed_1x_button.disabled = is_equal_approx(_current_speed_scale, SPEED_NORMAL)
	_speed_2x_button.disabled = is_equal_approx(_current_speed_scale, SPEED_FAST)


func _exit_tree() -> void:
	Engine.time_scale = SPEED_NORMAL
