extends Control
@export_group("노드 경로")
## RoundManager 노드 경로입니다.
@export var round_manager_path: NodePath
## 강제 라운드 진행 버튼 노드 경로입니다.
@export var force_next_round_button_path: NodePath
@export_group("디버그 표시")
## 디버그용 강제 라운드 버튼을 강제로 표시합니다.
@export var debug_show_force_next_round_button: bool = false

@onready var _round_manager: Node = get_node_or_null(round_manager_path)
@onready var _force_next_round_button: Button = get_node_or_null(force_next_round_button_path) as Button


func _ready() -> void:
	if _round_manager == null:
		push_error("DebugRoundControls: round_manager_path is invalid.")
		set_process(false)
		return
	if _force_next_round_button == null:
		push_error("DebugRoundControls: force_next_round_button_path is invalid.")
		set_process(false)
		return

	_force_next_round_button.pressed.connect(_on_force_next_round_button_pressed)
	_apply_visibility()
	set_process(true)


func _process(_delta: float) -> void:
	_apply_visibility()


func _on_force_next_round_button_pressed() -> void:
	if int(_round_manager.get("state")) != 1:
		return

	var current_round: int = int(_round_manager.get("current_round"))
	var total_round_count: int = _get_total_round_count()
	if current_round >= total_round_count:
		return

	if _round_manager.has_method("stop_wave"):
		_round_manager.call("stop_wave")
	if _round_manager.has_method("set_round"):
		_round_manager.call("set_round", current_round + 1)
	if _round_manager.has_method("begin_wave"):
		_round_manager.call("begin_wave")


func _get_total_round_count() -> int:
	if _round_manager.has_method("get_total_round_count"):
		return maxi(1, int(_round_manager.call("get_total_round_count")))
	return maxi(1, int(_round_manager.get("current_round")))


func _apply_visibility() -> void:
	if _force_next_round_button == null:
		return
	_force_next_round_button.visible = debug_show_force_next_round_button
