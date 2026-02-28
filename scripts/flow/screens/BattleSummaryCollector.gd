class_name BattleSummaryCollector
extends RefCounted

const PLAYGROUND_NODE_CANDIDATE_PATHS: Array[NodePath] = [NodePath("Playground"), NodePath("PlayGround")]

var _scene_tree: SceneTree
var _battle_instance: Node
var _battle_payload: Dictionary
var _battle_started_msec: int


func setup(scene_tree: SceneTree, battle_instance: Node, payload: Dictionary, started_msec: int) -> void:
	_scene_tree = scene_tree
	_battle_instance = battle_instance
	_battle_payload = payload.duplicate(true)
	_battle_started_msec = started_msec


func clear() -> void:
	_scene_tree = null
	_battle_instance = null
	_battle_payload.clear()
	_battle_started_msec = 0


func connect_hero_death_signals(on_hero_died: Callable) -> void:
	if _battle_instance == null or not is_instance_valid(_battle_instance):
		return
	for node: Node in _scene_tree.get_nodes_in_group(&"hero"):
		if not _battle_instance.is_ancestor_of(node):
			continue
		if not node.has_signal("died"):
			continue
		if node.is_connected("died", on_hero_died):
			continue
		node.connect("died", on_hero_died)


func are_all_heroes_dead() -> bool:
	if _battle_instance == null or not is_instance_valid(_battle_instance):
		return false
	var has_hero: bool = false
	for node: Node in _scene_tree.get_nodes_in_group(&"hero"):
		if not _battle_instance.is_ancestor_of(node):
			continue
		if not is_instance_valid(node):
			continue
		has_hero = true
		if not node.has_method("is_dead"):
			return false
		if not bool(node.call("is_dead")):
			return false
	return has_hero


func build_summary(victory: bool, base_summary: Dictionary) -> Dictionary:
	var summary: Dictionary = base_summary.duplicate(true)
	summary["victory"] = victory
	summary["encounter_id"] = String(_battle_payload.get("encounter_id", ""))
	summary["gold_end"] = int(_battle_payload.get("gold", -1))
	var elapsed_seconds: float = 0.0
	if _battle_started_msec > 0:
		elapsed_seconds = maxf(0.0, float(Time.get_ticks_msec() - _battle_started_msec) / 1000.0)
	summary["elapsed_seconds"] = elapsed_seconds

	if _battle_instance == null or not is_instance_valid(_battle_instance):
		return summary

	var round_manager: Node = _battle_instance.get_node_or_null("RoundSystem/RoundManager")
	if round_manager != null:
		summary["round_index"] = int(round_manager.get("current_round"))
		if round_manager.has_method("get_total_round_count"):
			summary["round_total"] = int(round_manager.call("get_total_round_count"))

	summary["party_snapshots"] = collect_party_snapshots()
	summary["all_heroes_dead"] = are_all_heroes_dead()

	var collected_gold_end: int = collect_gold_end()
	if collected_gold_end >= 0:
		summary["gold_end"] = collected_gold_end

	var collected_core_state: Dictionary = collect_core_state()
	if not collected_core_state.is_empty():
		summary["core_state"] = collected_core_state

	return summary


func collect_party_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	if _battle_instance == null or not is_instance_valid(_battle_instance):
		return snapshots
	for node: Node in _scene_tree.get_nodes_in_group(&"hero"):
		if not _battle_instance.is_ancestor_of(node):
			continue
		if not is_instance_valid(node):
			continue
		if not node.has_method("to_run_state"):
			continue
		var snapshot: Dictionary = node.call("to_run_state") as Dictionary
		snapshots.append(snapshot)
	return snapshots


func collect_gold_end() -> int:
	if _battle_instance == null or not is_instance_valid(_battle_instance):
		return -1
	var playground: Node = _find_playground_node()
	if playground == null:
		return -1
	if not playground.has_method("get_current_gold"):
		return -1
	return int(playground.call("get_current_gold"))


func collect_core_state() -> Dictionary:
	if _battle_instance == null or not is_instance_valid(_battle_instance):
		return {}
	var core_node: Node = _battle_instance.get_node_or_null("CoreRoot")
	if core_node == null:
		return {}
	var max_health: float = 0.0
	var current_health: float = 0.0
	if core_node.has_method("get_max_health"):
		max_health = float(core_node.call("get_max_health"))
	if core_node.has_method("get_current_health"):
		current_health = float(core_node.call("get_current_health"))
	return {
		"max_health": max_health,
		"current_health": current_health
	}


func _find_playground_node() -> Node:
	if _battle_instance == null or not is_instance_valid(_battle_instance):
		return null
	for path: NodePath in PLAYGROUND_NODE_CANDIDATE_PATHS:
		var node: Node = _battle_instance.get_node_or_null(path)
		if node != null:
			return node
	return null
