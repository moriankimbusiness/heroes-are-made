extends RefCounted

const NODE_TYPE_START := "start"
const NODE_TYPE_NORMAL_BATTLE := "normal_battle"
const NODE_TYPE_MID_BOSS := "mid_boss"
const NODE_TYPE_FINAL_BOSS := "final_boss"
const NODE_TYPE_ITEM := "item"
const NODE_TYPE_TOWN := "town"
const NODE_TYPE_EVENT := "event"

const INTERNAL_DEPTH_START := 1
const INTERNAL_DEPTH_END := 6
const FINAL_DEPTH := 7
const MID_BOSS_DEPTH := 4


func generate_chapter_state(chapter_id: int, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = max(1, seed)

	var world_graph: Dictionary = _generate_world_graph(rng)
	var start_node_id: int = get_start_node_id(world_graph)
	_mark_node_resolved(world_graph, start_node_id, true)

	return {
		"chapter_id": chapter_id,
		"world_graph": world_graph,
		"current_node_id": start_node_id,
		"selected_node_id": -1,
		"visited_nodes": [start_node_id],
		"is_chapter_cleared": false
	}


func get_start_node_id(world_graph: Dictionary) -> int:
	for node_var in world_graph.get("nodes", []):
		var node: Dictionary = node_var as Dictionary
		if int(node.get("depth", -1)) == 0:
			return int(node.get("node_id", -1))
	return -1


func find_node(world_graph: Dictionary, node_id: int) -> Dictionary:
	for node_var in world_graph.get("nodes", []):
		var node: Dictionary = node_var as Dictionary
		if int(node.get("node_id", -1)) == node_id:
			return node
	return {}


func find_node_index(world_graph: Dictionary, node_id: int) -> int:
	var nodes: Array = world_graph.get("nodes", [])
	for i in range(nodes.size()):
		var node: Dictionary = nodes[i] as Dictionary
		if int(node.get("node_id", -1)) == node_id:
			return i
	return -1


func get_node_depth(world_graph: Dictionary, node_id: int) -> int:
	var node: Dictionary = find_node(world_graph, node_id)
	if node.is_empty():
		return -1
	return int(node.get("depth", -1))


func get_outgoing_node_ids(world_graph: Dictionary, from_node_id: int) -> Array[int]:
	var outgoing: Array[int] = []
	for edge_var in world_graph.get("edges", []):
		var edge: Dictionary = edge_var as Dictionary
		if int(edge.get("from_node_id", -1)) != from_node_id:
			continue
		outgoing.append(int(edge.get("to_node_id", -1)))
	return outgoing


func mark_node_resolved(world_graph: Dictionary, node_id: int, resolved: bool) -> Dictionary:
	_mark_node_resolved(world_graph, node_id, resolved)
	return world_graph


func _mark_node_resolved(world_graph: Dictionary, node_id: int, resolved: bool) -> void:
	var nodes: Array = world_graph.get("nodes", [])
	var node_index: int = find_node_index(world_graph, node_id)
	if node_index < 0:
		return
	var node: Dictionary = nodes[node_index] as Dictionary
	var flags: Dictionary = (node.get("flags", {}) as Dictionary).duplicate(true)
	flags["resolved"] = resolved
	node["flags"] = flags
	nodes[node_index] = node
	world_graph["nodes"] = nodes


func _generate_world_graph(rng: RandomNumberGenerator) -> Dictionary:
	var nodes: Array = []
	var edges: Array = []
	var depth_to_node_ids: Array = []
	var next_node_id: int = 1

	for depth in range(FINAL_DEPTH + 1):
		var node_count: int = _get_depth_node_count(depth, rng)
		var depth_nodes: Array = []
		for lane in range(node_count):
			var node_type: String = _pick_default_node_type_for_depth(depth)
			var node: Dictionary = {
				"node_id": next_node_id,
				"depth": depth,
				"lane": lane,
				"node_type": node_type,
				"position_norm": _calc_position_norm(depth, lane, node_count),
				"reward_profile": _default_reward_profile(node_type),
				"flags": {
					"resolved": false
				}
			}
			nodes.append(node)
			depth_nodes.append(next_node_id)
			next_node_id += 1
		depth_to_node_ids.append(depth_nodes)

	_assign_internal_node_types(nodes, depth_to_node_ids, rng)
	_generate_edges(depth_to_node_ids, edges)

	return {
		"nodes": nodes,
		"edges": edges
	}


func _get_depth_node_count(depth: int, rng: RandomNumberGenerator) -> int:
	if depth == 0 or depth == FINAL_DEPTH:
		return 1
	return rng.randi_range(1, 3)


func _pick_default_node_type_for_depth(depth: int) -> String:
	if depth == 0:
		return NODE_TYPE_START
	if depth == FINAL_DEPTH:
		return NODE_TYPE_FINAL_BOSS
	return NODE_TYPE_NORMAL_BATTLE


func _assign_internal_node_types(nodes: Array, depth_to_node_ids: Array, rng: RandomNumberGenerator) -> void:
	# Assign weighted random types to non-reserved internal nodes.
	for depth in range(INTERNAL_DEPTH_START, INTERNAL_DEPTH_END + 1):
		var depth_ids: Array = depth_to_node_ids[depth]
		for node_id_var in depth_ids:
			var node_id: int = int(node_id_var)
			_set_node_type(nodes, node_id, _pick_weighted_internal_type(rng))

	# Force exactly one mid-boss at depth 4.
	var mid_boss_depth_ids: Array = depth_to_node_ids[MID_BOSS_DEPTH]
	var mid_boss_node_id: int = int(mid_boss_depth_ids[rng.randi_range(0, mid_boss_depth_ids.size() - 1)])
	_set_node_type(nodes, mid_boss_node_id, NODE_TYPE_MID_BOSS)

	# Guarantee at least one town between depth 2~5.
	if not _has_town_between_depths(nodes, 2, 5):
		var candidate_ids: Array = []
		for depth in range(2, 6):
			for node_id_var in depth_to_node_ids[depth]:
				var node_id: int = int(node_id_var)
				var current_type: String = _get_node_type(nodes, node_id)
				if current_type == NODE_TYPE_MID_BOSS or current_type == NODE_TYPE_FINAL_BOSS:
					continue
				candidate_ids.append(node_id)
		if not candidate_ids.is_empty():
			var town_node_id: int = int(candidate_ids[rng.randi_range(0, candidate_ids.size() - 1)])
			_set_node_type(nodes, town_node_id, NODE_TYPE_TOWN)

	# Prevent triple duplicate type at a depth of size 3.
	for depth in range(INTERNAL_DEPTH_START, INTERNAL_DEPTH_END + 1):
		var depth_ids: Array = depth_to_node_ids[depth]
		if depth_ids.size() != 3:
			continue
		var t0: String = _get_node_type(nodes, int(depth_ids[0]))
		var t1: String = _get_node_type(nodes, int(depth_ids[1]))
		var t2: String = _get_node_type(nodes, int(depth_ids[2]))
		if t0 != t1 or t1 != t2:
			continue
		var replace_index: int = rng.randi_range(0, 2)
		var replace_node_id: int = int(depth_ids[replace_index])
		if _get_node_type(nodes, replace_node_id) == NODE_TYPE_MID_BOSS:
			continue
		_set_node_type(nodes, replace_node_id, _pick_different_internal_type(rng, t0))


func _pick_weighted_internal_type(rng: RandomNumberGenerator) -> String:
	var weighted_types := [
		{"type": NODE_TYPE_NORMAL_BATTLE, "weight": 52.0},
		{"type": NODE_TYPE_ITEM, "weight": 20.0},
		{"type": NODE_TYPE_EVENT, "weight": 18.0},
		{"type": NODE_TYPE_TOWN, "weight": 10.0}
	]
	return _weighted_pick(rng, weighted_types, NODE_TYPE_NORMAL_BATTLE)


func _pick_different_internal_type(rng: RandomNumberGenerator, existing_type: String) -> String:
	var safety: int = 0
	while safety < 16:
		var candidate: String = _pick_weighted_internal_type(rng)
		if candidate != existing_type:
			return candidate
		safety += 1
	return NODE_TYPE_EVENT if existing_type != NODE_TYPE_EVENT else NODE_TYPE_ITEM


func _weighted_pick(rng: RandomNumberGenerator, weighted_types: Array, fallback_type: String) -> String:
	var total_weight: float = 0.0
	for row_var in weighted_types:
		var row: Dictionary = row_var as Dictionary
		total_weight += maxf(0.0, float(row.get("weight", 0.0)))
	if total_weight <= 0.0:
		return fallback_type

	var roll: float = rng.randf() * total_weight
	var cumulative: float = 0.0
	for row_var in weighted_types:
		var row: Dictionary = row_var as Dictionary
		cumulative += maxf(0.0, float(row.get("weight", 0.0)))
		if roll <= cumulative:
			return String(row.get("type", fallback_type))
	return fallback_type


func _generate_edges(depth_to_node_ids: Array, edges: Array) -> void:
	var edge_keys: Dictionary = {}
	for depth in range(FINAL_DEPTH):
		var from_ids: Array = depth_to_node_ids[depth]
		var to_ids: Array = depth_to_node_ids[depth + 1]
		for from_index in range(from_ids.size()):
			var from_id: int = int(from_ids[from_index])
			var center_index: int = _map_index_between_layers(from_index, from_ids.size(), to_ids.size())
			var candidate_indices: Array = []
			for offset in [-1, 0, 1]:
				var to_index: int = clampi(center_index + offset, 0, to_ids.size() - 1)
				if not candidate_indices.has(to_index):
					candidate_indices.append(to_index)
			if candidate_indices.is_empty():
				candidate_indices.append(clampi(center_index, 0, to_ids.size() - 1))
			for to_index_var in candidate_indices:
				var to_id: int = int(to_ids[int(to_index_var)])
				_add_edge(edges, edge_keys, from_id, to_id)

		# Ensure each node in next layer has at least one incoming edge.
		for to_index in range(to_ids.size()):
			var to_id: int = int(to_ids[to_index])
			if _has_incoming_edge(edges, to_id):
				continue
			var mapped_from_index: int = _map_index_between_layers(to_index, to_ids.size(), from_ids.size())
			var from_id: int = int(from_ids[mapped_from_index])
			_add_edge(edges, edge_keys, from_id, to_id)


func _add_edge(edges: Array, edge_keys: Dictionary, from_id: int, to_id: int) -> void:
	var key: String = "%d:%d" % [from_id, to_id]
	if edge_keys.has(key):
		return
	edge_keys[key] = true
	edges.append({
		"from_node_id": from_id,
		"to_node_id": to_id
	})


func _has_incoming_edge(edges: Array, to_node_id: int) -> bool:
	for edge_var in edges:
		var edge: Dictionary = edge_var as Dictionary
		if int(edge.get("to_node_id", -1)) == to_node_id:
			return true
	return false


func _map_index_between_layers(source_index: int, source_size: int, target_size: int) -> int:
	if source_size <= 1:
		return clampi(target_size / 2, 0, target_size - 1)
	var ratio: float = (float(source_index) + 0.5) / float(source_size)
	var mapped: int = int(round(ratio * float(target_size) - 0.5))
	return clampi(mapped, 0, target_size - 1)


func _calc_position_norm(depth: int, lane: int, lane_count: int) -> Dictionary:
	var x: float = float(depth) / float(FINAL_DEPTH)
	var y: float = 0.5
	if lane_count > 1:
		y = float(lane + 1) / float(lane_count + 1)
	return {
		"x": x,
		"y": y
	}


func _has_town_between_depths(nodes: Array, depth_min: int, depth_max: int) -> bool:
	for node_var in nodes:
		var node: Dictionary = node_var as Dictionary
		var depth: int = int(node.get("depth", -1))
		if depth < depth_min or depth > depth_max:
			continue
		if String(node.get("node_type", "")) == NODE_TYPE_TOWN:
			return true
	return false


func _get_node_type(nodes: Array, node_id: int) -> String:
	for node_var in nodes:
		var node: Dictionary = node_var as Dictionary
		if int(node.get("node_id", -1)) == node_id:
			return String(node.get("node_type", NODE_TYPE_NORMAL_BATTLE))
	return NODE_TYPE_NORMAL_BATTLE


func _set_node_type(nodes: Array, node_id: int, node_type: String) -> void:
	for i in range(nodes.size()):
		var node: Dictionary = nodes[i] as Dictionary
		if int(node.get("node_id", -1)) != node_id:
			continue
		node["node_type"] = node_type
		node["reward_profile"] = _default_reward_profile(node_type)
		nodes[i] = node
		return


func _default_reward_profile(node_type: String) -> String:
	match node_type:
		NODE_TYPE_NORMAL_BATTLE:
			return "battle_normal"
		NODE_TYPE_MID_BOSS:
			return "battle_mid_boss"
		NODE_TYPE_FINAL_BOSS:
			return "battle_final_boss"
		NODE_TYPE_ITEM:
			return "item_choice"
		NODE_TYPE_TOWN:
			return "town_service"
		NODE_TYPE_EVENT:
			return "event_choice"
		_:
			return "none"
