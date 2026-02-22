extends HBoxContainer

@export var fail_actions_path: NodePath
@export var retry_button_path: NodePath
@export var quit_button_path: NodePath
@export var debug_show_fail_actions: bool = false

@onready var _fail_actions: Control = get_node_or_null(fail_actions_path) as Control
@onready var _retry_button: Button = get_node_or_null(retry_button_path) as Button
@onready var _quit_button: Button = get_node_or_null(quit_button_path) as Button

var _round_manager: Node
var _auto_visible: bool = false


func _ready() -> void:
	if _fail_actions == null or _retry_button == null or _quit_button == null:
		push_error("RoundFailActionsUI: node paths are invalid.")
		set_process(false)
		return
	_retry_button.pressed.connect(_on_retry_button_pressed)
	_quit_button.pressed.connect(_on_quit_button_pressed)
	_apply_visibility()
	set_process(true)


func _process(_delta: float) -> void:
	_apply_visibility()


func set_round_manager(manager: Node) -> void:
	_round_manager = manager
	if _round_manager == null:
		_set_auto_visible(false)
		return

	if _round_manager.has_signal("game_failed"):
		_round_manager.connect("game_failed", _on_game_failed)
	if _round_manager.has_signal("all_rounds_cleared"):
		_round_manager.connect("all_rounds_cleared", _on_all_rounds_cleared)
	if _round_manager.has_signal("round_started"):
		_round_manager.connect("round_started", _on_round_started)

	_set_auto_visible(false)


func _on_game_failed(_alive_enemy_count: int, _threshold: int) -> void:
	_set_auto_visible(true)


func _on_all_rounds_cleared() -> void:
	_set_auto_visible(false)


func _on_round_started(_round: int) -> void:
	_set_auto_visible(false)


func _on_retry_button_pressed() -> void:
	get_tree().reload_current_scene()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _set_auto_visible(value: bool) -> void:
	_auto_visible = value
	_apply_visibility()


func _apply_visibility() -> void:
	if _fail_actions == null:
		return
	if debug_show_fail_actions:
		_fail_actions.visible = debug_show_fail_actions
		return
	_fail_actions.visible = _auto_visible
