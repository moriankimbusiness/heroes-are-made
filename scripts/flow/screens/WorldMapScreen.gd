extends Control

signal node_selected(node_id: int)
signal abandon_run_requested

@onready var _chapter_label: Label = $WorldTopBar/MarginContainer/HBoxContainer/ChapterLabel
@onready var _gold_label: Label = $WorldTopBar/MarginContainer/HBoxContainer/GoldLabel
@onready var _depth_label: Label = $WorldTopBar/MarginContainer/HBoxContainer/DepthLabel
@onready var _status_label: Label = $WorldTopBar/MarginContainer/HBoxContainer/WorldStatusLabel
@onready var _world_map_view: Control = $WorldMapView
@onready var _world_hint_label: Label = $WorldHintLabel
@onready var _exit_run_button: Button = $ExitRunButton


func _ready() -> void:
	_exit_run_button.pressed.connect(func() -> void: abandon_run_requested.emit())
	if _world_map_view.has_signal("node_pressed"):
		_world_map_view.connect("node_pressed", _on_world_map_node_pressed)
	hide_screen()


func show_screen(payload: Dictionary = {}) -> void:
	var chapter_index: int = int(payload.get("chapter_index", 1))
	var gold: int = int(payload.get("gold", 0))
	var current_depth: int = int(payload.get("current_depth", -1))
	var selectable_count: int = int(payload.get("selectable_count", 0))
	_chapter_label.text = "챕터 %d" % chapter_index
	_gold_label.text = "골드: %d" % gold
	_depth_label.text = "현재 깊이: D%d" % current_depth
	_status_label.text = "다음 후보: %d개" % selectable_count
	_world_hint_label.text = String(payload.get("hint_text", "연결된 다음 노드를 1개 선택하세요."))

	if _world_map_view.has_method("set_graph_state"):
		_world_map_view.call(
			"set_graph_state",
			payload.get("graph", {}),
			int(payload.get("current_node_id", -1)),
			payload.get("selectable_node_ids", []),
			payload.get("visited_node_ids", [])
		)
	visible = true


func hide_screen() -> void:
	visible = false


func _on_world_map_node_pressed(node_id: int) -> void:
	node_selected.emit(node_id)
