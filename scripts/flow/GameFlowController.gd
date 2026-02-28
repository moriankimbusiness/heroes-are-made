extends Node

signal run_started(run_id: String, chapter_id: int)
signal world_node_selected(node_id: int, node_type: String)
signal battle_started(node_id: int, encounter_id: String)
signal battle_finished(node_id: int, victory: bool, summary: Dictionary)
signal world_node_resolved(node_id: int, result: Dictionary)
signal chapter_cleared(chapter_id: int)
signal run_failed(reason: String, chapter_id: int, node_id: int)
signal run_cleared(run_id: String)

const WorldMapGeneratorRef := preload("res://scripts/flow/WorldMapGenerator.gd")

const NODE_TYPE_NORMAL_BATTLE := "normal_battle"
const NODE_TYPE_MID_BOSS := "mid_boss"
const NODE_TYPE_FINAL_BOSS := "final_boss"

@onready var _battle_screen_host: Node = $BattleScreenHost
@onready var _main_menu_screen: Control = $UI/MainMenuScreen
@onready var _chapter_prep_screen: Control = $UI/ChapterPrepScreen
@onready var _world_map_screen: Control = $UI/WorldMapScreen
@onready var _node_resolve_screen: Control = $UI/NodeResolveScreen
@onready var _battle_reward_screen: Control = $UI/BattleRewardScreen
@onready var _node_result_screen: Control = $UI/NodeResultScreen
@onready var _run_result_screen: Control = $UI/RunResultScreen
@onready var _settings_screen: Control = $UI/SettingsScreen

var _screens: Array[Node] = []
var _world_generator = WorldMapGeneratorRef.new()
var _rng := RandomNumberGenerator.new()
var _rsm := RunStateManager.new()


func _ready() -> void:
	_rng.randomize()
	_screens = [
		_main_menu_screen,
		_settings_screen,
		_chapter_prep_screen,
		_world_map_screen,
		_node_resolve_screen,
		_battle_reward_screen,
		_node_result_screen,
		_run_result_screen
	]
	_connect_screen_signals()
	_show_main_menu()


func _connect_screen_signals() -> void:
	if _main_menu_screen.has_signal("start_new_run_requested"):
		_main_menu_screen.connect("start_new_run_requested", _on_start_new_run_requested)
	if _main_menu_screen.has_signal("continue_requested"):
		_main_menu_screen.connect("continue_requested", _on_continue_requested)
	if _main_menu_screen.has_signal("settings_requested"):
		_main_menu_screen.connect("settings_requested", _on_settings_requested)
	if _main_menu_screen.has_signal("quit_requested"):
		_main_menu_screen.connect("quit_requested", _on_quit_requested)

	if _settings_screen.has_signal("back_requested"):
		_settings_screen.connect("back_requested", _on_settings_back_requested)

	if _chapter_prep_screen.has_signal("start_expedition_requested"):
		_chapter_prep_screen.connect("start_expedition_requested", _on_start_expedition_requested)
	if _chapter_prep_screen.has_signal("back_to_menu_requested"):
		_chapter_prep_screen.connect("back_to_menu_requested", _on_back_to_menu_requested)

	if _world_map_screen.has_signal("node_selected"):
		_world_map_screen.connect("node_selected", _on_world_node_selected)
	if _world_map_screen.has_signal("abandon_run_requested"):
		_world_map_screen.connect("abandon_run_requested", _on_abandon_run_requested)

	if _node_resolve_screen.has_signal("node_resolved"):
		_node_resolve_screen.connect("node_resolved", _on_node_resolved)

	if _battle_reward_screen.has_signal("reward_selected"):
		_battle_reward_screen.connect("reward_selected", _on_battle_reward_selected)

	if _node_result_screen.has_signal("continue_requested"):
		_node_result_screen.connect("continue_requested", _on_node_result_continue_requested)

	if _run_result_screen.has_signal("restart_requested"):
		_run_result_screen.connect("restart_requested", _on_restart_requested)
	if _run_result_screen.has_signal("back_to_menu_requested"):
		_run_result_screen.connect("back_to_menu_requested", _on_back_to_menu_requested)

	if _battle_screen_host.has_signal("battle_finished"):
		_battle_screen_host.connect("battle_finished", _on_battle_host_finished)


func _hide_all_screens() -> void:
	for screen in _screens:
		if screen.has_method("hide_screen"):
			screen.call("hide_screen")


func _show_screen(screen: Node, payload: Dictionary = {}) -> void:
	_hide_all_screens()
	if screen != null and screen.has_method("show_screen"):
		screen.call("show_screen", payload)


func _show_main_menu() -> void:
	_battle_screen_host.call("hide_screen")
	_rsm.pending_battle_summary.clear()
	_show_screen(_main_menu_screen, {"has_save": _rsm.has_save_file()})


func _show_chapter_prep() -> void:
	if _rsm.run_state.is_empty() or _rsm.chapter_state.is_empty():
		return
	var party_state: Dictionary = _rsm.run_state.get("party_state", {}) as Dictionary
	var hero_snapshots: Array[Dictionary] = _rsm.snapshot_array(party_state.get("heroes", []))
	var selected_count: int = int(party_state.get("selected_count", hero_snapshots.size()))
	if selected_count <= 0:
		selected_count = maxi(1, hero_snapshots.size())
	_show_screen(_chapter_prep_screen, {
		"chapter_index": _rsm.get_chapter_index(),
		"selected_count": selected_count,
		"max_count": int(party_state.get("max_count", RunStateManager.DEFAULT_PARTY_MAX))
	})


func _show_world_map() -> void:
	if _rsm.run_state.is_empty() or _rsm.chapter_state.is_empty():
		return
	var graph: Dictionary = _rsm.chapter_state.get("world_graph", {}) as Dictionary
	var current_node_id: int = int(_rsm.chapter_state.get("current_node_id", -1))
	var current_depth: int = _world_generator.get_node_depth(graph, current_node_id)
	var selectable_nodes: Array[int] = _get_selectable_next_node_ids()
	var visited_nodes: Array[int] = _get_visited_nodes()

	_show_screen(_world_map_screen, {
		"chapter_index": _rsm.get_chapter_index(),
		"gold": _rsm.get_gold(),
		"current_depth": current_depth,
		"selectable_count": selectable_nodes.size(),
		"hint_text": "연결된 다음 노드를 1개 선택하세요.",
		"graph": graph,
		"current_node_id": current_node_id,
		"selectable_node_ids": selectable_nodes,
		"visited_node_ids": visited_nodes
	})


func _on_start_new_run_requested() -> void:
	_start_new_run()
	_show_chapter_prep()


func _on_continue_requested() -> void:
	if not _rsm.load():
		_show_main_menu()
		return
	_show_world_map()
	_resume_selected_node_if_needed()


func _on_quit_requested() -> void:
	get_tree().quit()


func _on_settings_requested() -> void:
	_show_screen(_settings_screen, {
		"settings": AppSettings.get_settings()
	})


func _on_settings_back_requested() -> void:
	_show_main_menu()


func _on_start_expedition_requested() -> void:
	_show_world_map()


func _on_back_to_menu_requested() -> void:
	_battle_screen_host.call("hide_screen")
	_rsm.pending_battle_summary.clear()
	_show_main_menu()


func _on_restart_requested() -> void:
	_start_new_run()
	_show_chapter_prep()


func _on_abandon_run_requested() -> void:
	_fail_run("abandoned")


func _start_new_run() -> void:
	_rsm.start_new_run(_rng)
	_create_new_chapter_state(_rsm.get_chapter_index())
	emit_signal("run_started", _rsm.get_run_id(), _rsm.get_chapter_index())
	_rsm.save("run_started")


func _create_new_chapter_state(chapter_index: int) -> void:
	_rsm.create_new_chapter_state(chapter_index, _world_generator)


func _on_world_node_selected(node_id: int) -> void:
	if not _get_selectable_next_node_ids().has(node_id):
		return
	_rsm.selected_node_id = node_id
	_rsm.chapter_state["selected_node_id"] = node_id
	_rsm.save("node_selected")
	_begin_node_resolution(node_id)


func _begin_node_resolution(node_id: int) -> void:
	var graph: Dictionary = _rsm.chapter_state.get("world_graph", {}) as Dictionary
	var node: Dictionary = _world_generator.find_node(graph, node_id)
	if node.is_empty():
		return

	var node_type: String = String(node.get("node_type", ""))
	emit_signal("world_node_selected", node_id, node_type)

	if _is_combat_node(node_type):
		_start_battle_for_node(node)
		return

	_show_screen(_node_resolve_screen, {
		"node_id": node_id,
		"node_type": node_type,
		"current_gold": _rsm.get_gold(),
		"rng_seed": _rng.randi()
	})


func _is_combat_node(node_type: String) -> bool:
	return node_type == NODE_TYPE_NORMAL_BATTLE or node_type == NODE_TYPE_MID_BOSS or node_type == NODE_TYPE_FINAL_BOSS


func _start_battle_for_node(node: Dictionary) -> void:
	_hide_all_screens()
	if _rsm.has_no_living_heroes():
		_fail_run("all_heroes_dead")
		return
	var node_id: int = int(node.get("node_id", -1))
	var encounter_id: String = "chapter_%d_node_%d" % [_rsm.get_chapter_index(), node_id]
	emit_signal("battle_started", node_id, encounter_id)

	var party_snapshots: Array[Dictionary] = _rsm.get_party_snapshots_for_battle()
	_battle_screen_host.call("show_screen", {
		"party_count": party_snapshots.size(),
		"party_snapshots": party_snapshots,
		"core_state": _rsm.get_core_state(),
		"gold": _rsm.get_gold(),
		"seed": _rsm.get_seed(),
		"node_id": node_id,
		"encounter_id": encounter_id
	})


func _on_battle_host_finished(victory: bool, summary: Dictionary) -> void:
	emit_signal("battle_finished", _rsm.selected_node_id, victory, summary)
	_battle_screen_host.call("hide_screen")

	if not victory:
		_fail_run(String(summary.get("reason", "battle_failed")))
		return

	_rsm.pending_battle_summary = summary.duplicate(true)
	_rsm.apply_battle_summary(_rsm.pending_battle_summary)

	if _rsm.has_no_living_heroes():
		_fail_run("all_heroes_dead")
		return

	_show_battle_reward()


func _show_battle_reward() -> void:
	var graph: Dictionary = _rsm.chapter_state.get("world_graph", {}) as Dictionary
	var node: Dictionary = _world_generator.find_node(graph, _rsm.selected_node_id)
	var node_type: String = String(node.get("node_type", NODE_TYPE_NORMAL_BATTLE))
	_show_screen(_battle_reward_screen, {
		"node_id": _rsm.selected_node_id,
		"node_type": node_type,
		"current_gold": _rsm.get_gold(),
		"rng_seed": _rng.randi(),
		"battle_summary": _rsm.pending_battle_summary
	})


func _on_battle_reward_selected(result: Dictionary) -> void:
	_resolve_battle_reward(result)


func _resolve_battle_reward(reward_result: Dictionary = {}) -> void:
	var graph: Dictionary = _rsm.chapter_state.get("world_graph", {}) as Dictionary
	var node: Dictionary = _world_generator.find_node(graph, _rsm.selected_node_id)
	var node_type: String = String(node.get("node_type", NODE_TYPE_NORMAL_BATTLE))

	var gold_gain: int = 30
	if node_type == NODE_TYPE_MID_BOSS:
		gold_gain = 60
	elif node_type == NODE_TYPE_FINAL_BOSS:
		gold_gain = 100

	var granted_rewards: Array[String] = []
	for reward_var in reward_result.get("granted_rewards", []):
		granted_rewards.append(String(reward_var))

	if node_type == NODE_TYPE_MID_BOSS:
		granted_rewards.append("중간보스 전리품")
	elif node_type == NODE_TYPE_FINAL_BOSS:
		granted_rewards.append("최종보스 전리품")

	var reward_note: String = String(reward_result.get("note", "전투 보상 선택 완료"))
	var reward_gold_delta: int = int(reward_result.get("gold_delta", 0))
	var total_gold_delta: int = gold_gain + reward_gold_delta

	_complete_node_resolution({
		"node_id": _rsm.selected_node_id,
		"result_type": "success",
		"gold_delta": total_gold_delta,
		"hp_delta": 0,
		"granted_rewards": granted_rewards,
		"consumed_resources": [],
		"next_state": "world",
		"note": "%s / 전투 승리 보상 획득" % reward_note,
		"battle_summary": _rsm.pending_battle_summary
	})
	_rsm.pending_battle_summary.clear()


func _on_node_resolved(result: Dictionary) -> void:
	_complete_node_resolution(result)


func _complete_node_resolution(result: Dictionary) -> void:
	var node_id: int = int(result.get("node_id", _rsm.selected_node_id))
	var graph: Dictionary = _rsm.chapter_state.get("world_graph", {}) as Dictionary
	var node: Dictionary = _world_generator.find_node(graph, node_id)
	var node_type: String = String(node.get("node_type", ""))

	var battle_summary: Dictionary = result.get("battle_summary", {}) as Dictionary
	if not battle_summary.is_empty():
		_rsm.apply_battle_summary(battle_summary)

	_rsm.apply_gold_delta(int(result.get("gold_delta", 0)))

	var granted_rewards_var: Array = result.get("granted_rewards", [])
	var granted_rewards: Array[String] = []
	for reward in granted_rewards_var:
		granted_rewards.append(String(reward))
	if not granted_rewards.is_empty():
		_rsm.add_reward_entries(granted_rewards)

	_world_generator.mark_node_resolved(graph, node_id, true)
	_rsm.chapter_state["world_graph"] = graph
	_rsm.chapter_state["current_node_id"] = node_id
	_rsm.chapter_state["selected_node_id"] = -1
	_rsm.selected_node_id = -1

	var visited_nodes: Array[int] = _get_visited_nodes()
	if not visited_nodes.has(node_id):
		visited_nodes.append(node_id)
	_rsm.chapter_state["visited_nodes"] = visited_nodes

	var merged_result: Dictionary = result.duplicate(true)
	merged_result["node_id"] = node_id
	merged_result["granted_rewards"] = granted_rewards
	emit_signal("world_node_resolved", node_id, merged_result)

	if node_type == NODE_TYPE_FINAL_BOSS:
		_on_chapter_cleared()
		return

	_rsm.save("node_resolved")
	_show_screen(_node_result_screen, merged_result)


func _on_node_result_continue_requested() -> void:
	_show_world_map()


func _on_chapter_cleared() -> void:
	var chapter_id: int = int(_rsm.chapter_state.get("chapter_id", 1))
	_rsm.chapter_state["is_chapter_cleared"] = true
	emit_signal("chapter_cleared", chapter_id)
	emit_signal("run_cleared", _rsm.get_run_id())
	_rsm.clear_save_file()
	_show_screen(_run_result_screen, {
		"result_kind": "cleared",
		"chapter_id": chapter_id
	})


func _fail_run(reason: String) -> void:
	_battle_screen_host.call("hide_screen")
	_rsm.pending_battle_summary.clear()
	var chapter_id: int = int(_rsm.chapter_state.get("chapter_id", 1))
	var node_id: int = _rsm.selected_node_id
	emit_signal("run_failed", reason, chapter_id, node_id)
	_rsm.clear_save_file()
	_show_screen(_run_result_screen, {
		"result_kind": "failed",
		"reason": reason
	})


func _get_selectable_next_node_ids() -> Array[int]:
	var graph: Dictionary = _rsm.chapter_state.get("world_graph", {}) as Dictionary
	var current_node_id: int = int(_rsm.chapter_state.get("current_node_id", -1))
	var outgoing: Array[int] = _world_generator.get_outgoing_node_ids(graph, current_node_id)
	var selectable: Array[int] = []
	for node_id in outgoing:
		if _is_node_resolved(node_id):
			continue
		selectable.append(node_id)
	return selectable


func _get_visited_nodes() -> Array[int]:
	var visited_var: Array = _rsm.chapter_state.get("visited_nodes", [])
	var visited: Array[int] = []
	for node_id in visited_var:
		visited.append(int(node_id))
	return visited


func _is_node_resolved(node_id: int) -> bool:
	var graph: Dictionary = _rsm.chapter_state.get("world_graph", {}) as Dictionary
	var node: Dictionary = _world_generator.find_node(graph, node_id)
	if node.is_empty():
		return false
	var flags: Dictionary = node.get("flags", {}) as Dictionary
	return bool(flags.get("resolved", false))


func _resume_selected_node_if_needed() -> void:
	if _rsm.selected_node_id < 0:
		return
	if _is_node_resolved(_rsm.selected_node_id):
		_rsm.selected_node_id = -1
		_rsm.chapter_state["selected_node_id"] = -1
		_rsm.save("clear_stale_selected_node")
		return
	_begin_node_resolution(_rsm.selected_node_id)
