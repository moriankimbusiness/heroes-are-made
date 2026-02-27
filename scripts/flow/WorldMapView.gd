extends Control

signal node_pressed(node_id: int)

const NODE_SIZE := Vector2(118.0, 42.0)
const NODE_MARGIN := Vector2(42.0, 36.0)

var _graph: Dictionary = {}
var _current_node_id: int = -1
var _selectable_node_ids: Array[int] = []
var _visited_node_ids: Array[int] = []
var _buttons_by_id: Dictionary = {}
var _button_layer: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_button_layer = Control.new()
	_button_layer.name = "ButtonLayer"
	_button_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_button_layer)


func set_graph_state(
	graph: Dictionary,
	current_node_id: int,
	selectable_node_ids: Array[int],
	visited_node_ids: Array[int]
) -> void:
	_graph = graph.duplicate(true)
	_current_node_id = current_node_id
	_selectable_node_ids = selectable_node_ids.duplicate()
	var visited_copy: Array = visited_node_ids.duplicate()
	_visited_node_ids.clear()
	for node_id in visited_copy:
		_visited_node_ids.append(int(node_id))
	_rebuild_buttons()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_reposition_buttons()
		queue_redraw()


func _draw() -> void:
	var nodes: Array = _graph.get("nodes", [])
	var edges: Array = _graph.get("edges", [])
	if nodes.is_empty():
		return

	for edge_var in edges:
		var edge: Dictionary = edge_var as Dictionary
		var from_id: int = int(edge.get("from_node_id", -1))
		var to_id: int = int(edge.get("to_node_id", -1))
		var from_node: Dictionary = _find_node(from_id)
		var to_node: Dictionary = _find_node(to_id)
		if from_node.is_empty() or to_node.is_empty():
			continue

		var from_pos: Vector2 = _node_center_to_canvas(from_node)
		var to_pos: Vector2 = _node_center_to_canvas(to_node)
		var edge_color: Color = Color(0.44, 0.44, 0.48, 0.75)
		if _is_edge_in_visited_path(from_id, to_id):
			edge_color = Color(0.86, 0.74, 0.35, 0.95)
		draw_line(from_pos, to_pos, edge_color, 2.0)

	for node_var in nodes:
		var node: Dictionary = node_var as Dictionary
		var center: Vector2 = _node_center_to_canvas(node)
		draw_circle(center, 4.0, Color(0.18, 0.18, 0.20, 0.95))


func _rebuild_buttons() -> void:
	if _button_layer == null:
		return
	for child in _button_layer.get_children():
		child.queue_free()
	_buttons_by_id.clear()

	for node_var in _graph.get("nodes", []):
		var node: Dictionary = node_var as Dictionary
		var node_id: int = int(node.get("node_id", -1))
		var node_type: String = String(node.get("node_type", "unknown"))
		var is_current: bool = node_id == _current_node_id
		var is_selectable: bool = _selectable_node_ids.has(node_id)
		var is_visited: bool = _visited_node_ids.has(node_id)

		var button := Button.new()
		button.custom_minimum_size = NODE_SIZE
		button.text = _node_button_text(node_type)
		button.disabled = not is_selectable
		button.tooltip_text = "Node %d (%s)" % [node_id, node_type]
		button.modulate = _node_color(node_type, is_current, is_visited, is_selectable)
		button.pressed.connect(_on_node_button_pressed.bind(node_id))
		_button_layer.add_child(button)
		_buttons_by_id[node_id] = button

	_reposition_buttons()


func _reposition_buttons() -> void:
	var nodes: Array = _graph.get("nodes", [])
	for node_var in nodes:
		var node: Dictionary = node_var as Dictionary
		var node_id: int = int(node.get("node_id", -1))
		var button: Button = _buttons_by_id.get(node_id, null) as Button
		if button == null:
			continue
		var center: Vector2 = _node_center_to_canvas(node)
		button.position = center - NODE_SIZE * 0.5


func _on_node_button_pressed(node_id: int) -> void:
	node_pressed.emit(node_id)


func _node_center_to_canvas(node: Dictionary) -> Vector2:
	var norm: Dictionary = node.get("position_norm", {})
	var nx: float = clampf(float(norm.get("x", 0.0)), 0.0, 1.0)
	var ny: float = clampf(float(norm.get("y", 0.5)), 0.0, 1.0)
	var area_size: Vector2 = Vector2(
		maxf(1.0, size.x - NODE_MARGIN.x * 2.0),
		maxf(1.0, size.y - NODE_MARGIN.y * 2.0)
	)
	return Vector2(
		NODE_MARGIN.x + nx * area_size.x,
		NODE_MARGIN.y + ny * area_size.y
	)


func _find_node(node_id: int) -> Dictionary:
	for node_var in _graph.get("nodes", []):
		var node: Dictionary = node_var as Dictionary
		if int(node.get("node_id", -1)) == node_id:
			return node
	return {}


func _is_edge_in_visited_path(from_id: int, to_id: int) -> bool:
	for i in range(_visited_node_ids.size() - 1):
		if _visited_node_ids[i] == from_id and _visited_node_ids[i + 1] == to_id:
			return true
	return false


func _node_button_text(node_type: String) -> String:
	match node_type:
		"start":
			return "시작"
		"normal_battle":
			return "전투"
		"mid_boss":
			return "중간보스"
		"final_boss":
			return "최종보스"
		"item":
			return "아이템"
		"town":
			return "마을"
		"event":
			return "?"
		_:
			return node_type


func _node_color(node_type: String, is_current: bool, is_visited: bool, is_selectable: bool) -> Color:
	var base: Color
	match node_type:
		"start":
			base = Color(0.45, 0.80, 1.00, 1.0)
		"normal_battle":
			base = Color(0.82, 0.42, 0.42, 1.0)
		"mid_boss":
			base = Color(0.92, 0.34, 0.26, 1.0)
		"final_boss":
			base = Color(0.98, 0.12, 0.12, 1.0)
		"item":
			base = Color(0.38, 0.78, 0.46, 1.0)
		"town":
			base = Color(0.92, 0.80, 0.34, 1.0)
		"event":
			base = Color(0.62, 0.62, 0.66, 1.0)
		_:
			base = Color(0.70, 0.70, 0.70, 1.0)

	if is_visited:
		base = base.lightened(0.12)
	if is_current:
		base = base.lightened(0.20)
	if not is_selectable and not is_current:
		base.a = 0.55
	return base
