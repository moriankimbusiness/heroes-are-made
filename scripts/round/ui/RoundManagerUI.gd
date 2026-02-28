extends CanvasLayer
@export_group("RoundManagerUI 노드 경로")
## RoundManager 노드 경로입니다.
@export var round_manager_path: NodePath
## 현재 라운드 라벨 노드 경로입니다.
@export var round_label_path: NodePath
## 현재 생존 적 수 라벨 노드 경로입니다.
@export var alive_enemy_count_label_path: NodePath
## 상태 표시 라벨 노드 경로입니다.
@export var status_label_path: NodePath
## RoundTopCenterUI 노드 경로입니다.
@export var top_center_ui_path: NodePath
## RoundFailActionsUI 노드 경로입니다.
@export var fail_actions_ui_path: NodePath

@onready var _round_manager: Node = get_node_or_null(round_manager_path)
@onready var _round_label: Label = get_node_or_null(round_label_path) as Label
@onready var _alive_enemy_count_label: Label = get_node_or_null(alive_enemy_count_label_path) as Label
@onready var _status_label: Label = get_node_or_null(status_label_path) as Label
@onready var _top_center_ui: Node = get_node_or_null(top_center_ui_path)
@onready var _fail_actions_ui: Node = get_node_or_null(fail_actions_ui_path)


func _ready() -> void:
	if _round_manager == null:
		push_error("RoundManagerUI: round_manager_path is invalid.")
		set_process(false)
		return
	if _round_label == null or _alive_enemy_count_label == null or _status_label == null:
		push_error("RoundManagerUI: label node paths are invalid.")
		set_process(false)
		return
	if _top_center_ui == null or _fail_actions_ui == null:
		push_error("RoundManagerUI: child UI node paths are invalid.")
		set_process(false)
		return

	if _top_center_ui.has_method("set_round_manager"):
		_top_center_ui.call("set_round_manager", _round_manager)
	if _fail_actions_ui.has_method("set_round_manager"):
		_fail_actions_ui.call("set_round_manager", _round_manager)

	if _round_manager.has_signal("round_started"):
		_round_manager.connect("round_started", _on_round_started)
	if _round_manager.has_signal("round_cleared"):
		_round_manager.connect("round_cleared", _on_round_cleared)
	if _round_manager.has_signal("all_rounds_cleared"):
		_round_manager.connect("all_rounds_cleared", _on_all_rounds_cleared)

	_update_round_label()
	_update_alive_enemy_count_label()
	_update_status_label()
	set_process(true)


func _process(_delta: float) -> void:
	_update_alive_enemy_count_label()


func _on_round_started(_round: int) -> void:
	_update_round_label()
	_update_status_label()


func _on_round_cleared(_round: int) -> void:
	_update_round_label()
	_update_status_label()


func _on_all_rounds_cleared() -> void:
	_status_label.text = "Status: ALL CLEARED"


func _update_round_label() -> void:
	var round_value: int = 1
	if _round_manager != null:
		round_value = int(_round_manager.get("current_round"))
	_round_label.text = "Round: %d" % round_value


func _update_alive_enemy_count_label() -> void:
	var alive_count: int = 0
	if _round_manager != null:
		alive_count = int(_round_manager.get("alive_enemy_count"))
	_alive_enemy_count_label.text = "Alive: %d" % alive_count


func _update_status_label() -> void:
	var state_value: int = 0
	if _round_manager != null:
		state_value = int(_round_manager.get("state"))

	match state_value:
		0:
			_status_label.text = "Status: PREPARE"
		1:
			_status_label.text = "Status: WAVE ACTIVE"
		2:
			_status_label.text = "Status: INTERMISSION"
		3:
			_status_label.text = "Status: FAILED"
		4:
			_status_label.text = "Status: CLEARED"
		_:
			_status_label.text = "Status: UNKNOWN"
