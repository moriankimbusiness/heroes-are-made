extends Control

@export var round_countdown_label_path: NodePath
@export var next_round_button_path: NodePath
@export var debug_show_next_round_button: bool = false

@onready var _round_countdown_label: Label = get_node_or_null(round_countdown_label_path) as Label
@onready var _next_round_button: Button = get_node_or_null(next_round_button_path) as Button

var _round_manager: Node
var _next_round_button_auto_visible: bool = false


func _ready() -> void:
	if _round_countdown_label == null or _next_round_button == null:
		push_error("RoundTopCenterUI: node paths are invalid.")
		set_process(false)
		return
	_next_round_button.pressed.connect(_on_next_round_button_pressed)
	_update_round_countdown_label()
	_apply_visibility()
	set_process(true)


func _process(_delta: float) -> void:
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
	if _round_manager.has_signal("game_failed"):
		_round_manager.connect("game_failed", _on_game_failed)
	if _round_manager.has_signal("all_rounds_cleared"):
		_round_manager.connect("all_rounds_cleared", _on_all_rounds_cleared)

	_update_round_countdown_label(float(_round_manager.get("remaining_round_seconds")))
	_set_next_round_button_visible(bool(_round_manager.get("is_next_round_available")))


func _on_round_timer_updated(remaining_seconds: float) -> void:
	_update_round_countdown_label(remaining_seconds)


func _on_next_round_available_changed(is_available: bool) -> void:
	_set_next_round_button_visible(is_available)


func _on_game_failed(_alive_enemy_count: int, _threshold: int) -> void:
	_set_next_round_button_visible(false)


func _on_all_rounds_cleared() -> void:
	_set_next_round_button_visible(false)


func _on_next_round_button_pressed() -> void:
	if _round_manager != null and _round_manager.has_method("request_next_round"):
		_round_manager.call("request_next_round")


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
