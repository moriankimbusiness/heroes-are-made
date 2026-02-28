class_name RunStateManager
extends RefCounted

const SAVE_PATH := "user://run_state_v3.json"
const SAVE_VERSION := 3

const DEFAULT_PARTY_SIZE := 3
const DEFAULT_PARTY_MAX := 4
const DEFAULT_HERO_MAX_HEALTH := 100.0
const DEFAULT_HERO_REQUIRED_EXP := 60
const DEFAULT_CORE_MAX_HEALTH := 300.0
const DEFAULT_HERO_CLASS_ORDER: Array[int] = [0, 1, 2, 3]

var run_state: Dictionary = {}
var chapter_state: Dictionary = {}
var selected_node_id: int = -1
var pending_battle_summary: Dictionary = {}


func start_new_run(rng: RandomNumberGenerator) -> void:
	var unix_time: int = int(Time.get_unix_time_from_system())
	var run_seed: int = rng.randi()
	var initial_party_snapshots: Array[Dictionary] = build_default_party_snapshots(DEFAULT_PARTY_SIZE)
	run_state = {
		"run_id": "run_%d" % unix_time,
		"chapter_index": 1,
		"gold": 100,
		"party_state": {
			"selected_count": initial_party_snapshots.size(),
			"max_count": DEFAULT_PARTY_MAX,
			"heroes": initial_party_snapshots
		},
		"core_state": {
			"max_health": DEFAULT_CORE_MAX_HEALTH,
			"current_health": DEFAULT_CORE_MAX_HEALTH
		},
		"inventory_state": {
			"items": []
		},
		"relics": [],
		"seed": run_seed
	}
	selected_node_id = -1
	pending_battle_summary.clear()


func create_new_chapter_state(chapter_index: int, world_generator) -> void:
	var run_seed: int = int(run_state.get("seed", 1))
	var chapter_seed: int = run_seed + chapter_index * 7919
	chapter_state = world_generator.generate_chapter_state(chapter_index, chapter_seed)
	selected_node_id = -1


func save(reason: String) -> void:
	if run_state.is_empty() or chapter_state.is_empty():
		return
	var payload: Dictionary = {
		"save_version": SAVE_VERSION,
		"run_state": run_state,
		"chapter_state": chapter_state,
		"ui_state": {
			"selected_node_id": selected_node_id
		},
		"timestamp_unix": int(Time.get_unix_time_from_system()),
		"reason": reason
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("RunStateManager: failed to open save file.")
		return
	file.store_string(JSON.stringify(payload, "\t"))


func load() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return false

	var payload: Dictionary = parsed as Dictionary
	if int(payload.get("save_version", 0)) != SAVE_VERSION:
		return false

	var loaded_run_state: Dictionary = payload.get("run_state", {}) as Dictionary
	var loaded_chapter_state: Dictionary = payload.get("chapter_state", {}) as Dictionary
	if loaded_run_state.is_empty() or loaded_chapter_state.is_empty():
		return false

	run_state = loaded_run_state
	chapter_state = loaded_chapter_state
	ensure_defaults()

	var ui_state: Dictionary = payload.get("ui_state", {}) as Dictionary
	selected_node_id = int(ui_state.get("selected_node_id", int(chapter_state.get("selected_node_id", -1))))
	return true


func clear_save_file() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var absolute_path: String = ProjectSettings.globalize_path(SAVE_PATH)
	DirAccess.remove_absolute(absolute_path)


func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func build_default_party_snapshots(count: int) -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	var resolved_count: int = maxi(1, count)
	for i in range(resolved_count):
		var class_id: int = DEFAULT_HERO_CLASS_ORDER[i % DEFAULT_HERO_CLASS_ORDER.size()]
		snapshots.append({
			"hero_display_name": "용사 %d" % (i + 1),
			"class_id": class_id,
			"level": 1,
			"current_exp": 0,
			"required_exp": DEFAULT_HERO_REQUIRED_EXP,
			"max_health": DEFAULT_HERO_MAX_HEALTH,
			"current_health": DEFAULT_HERO_MAX_HEALTH,
			"is_dead": false
		})
	return snapshots


func snapshot_array(snapshot_var: Variant) -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	if not (snapshot_var is Array):
		return snapshots
	for row in snapshot_var:
		if row is Dictionary:
			snapshots.append((row as Dictionary).duplicate(true))
	return snapshots


func get_party_snapshots_for_battle() -> Array[Dictionary]:
	var party_state: Dictionary = run_state.get("party_state", {}) as Dictionary
	var hero_snapshots: Array[Dictionary] = snapshot_array(party_state.get("heroes", []))
	if hero_snapshots.is_empty():
		var selected_count: int = int(party_state.get("selected_count", DEFAULT_PARTY_SIZE))
		hero_snapshots = build_default_party_snapshots(selected_count)
		set_party_snapshots(hero_snapshots)
	return hero_snapshots


func set_party_snapshots(snapshots: Array[Dictionary]) -> void:
	var party_state: Dictionary = run_state.get("party_state", {}) as Dictionary
	party_state["heroes"] = snapshots.duplicate(true)
	party_state["selected_count"] = snapshots.size()
	party_state["max_count"] = int(party_state.get("max_count", DEFAULT_PARTY_MAX))
	run_state["party_state"] = party_state


func sanitize_core_state(core_state: Dictionary) -> Dictionary:
	var max_health: float = maxf(1.0, float(core_state.get("max_health", DEFAULT_CORE_MAX_HEALTH)))
	var current_health: float = clampf(float(core_state.get("current_health", max_health)), 0.0, max_health)
	return {
		"max_health": max_health,
		"current_health": current_health
	}


func apply_battle_summary(summary: Dictionary) -> void:
	if summary.has("gold_end"):
		var gold_end: int = int(summary.get("gold_end", -1))
		if gold_end >= 0:
			run_state["gold"] = maxi(0, gold_end)

	var party_snapshots: Array[Dictionary] = snapshot_array(summary.get("party_snapshots", []))
	if not party_snapshots.is_empty():
		set_party_snapshots(party_snapshots)

	var summary_core: Dictionary = summary.get("core_state", {}) as Dictionary
	if not summary_core.is_empty():
		run_state["core_state"] = sanitize_core_state(summary_core)


func has_no_living_heroes() -> bool:
	var party_state: Dictionary = run_state.get("party_state", {}) as Dictionary
	var snapshots: Array[Dictionary] = snapshot_array(party_state.get("heroes", []))
	if snapshots.is_empty():
		return true
	for snapshot in snapshots:
		var is_dead: bool = bool(snapshot.get("is_dead", false))
		var current_health: float = float(snapshot.get("current_health", 0.0))
		if not is_dead and current_health > 0.0:
			return false
	return true


func add_reward_entries(rewards: Array[String]) -> void:
	if rewards.is_empty():
		return
	var relics: Array = run_state.get("relics", [])
	for reward in rewards:
		relics.append(reward)
	run_state["relics"] = relics

	var inventory_state: Dictionary = run_state.get("inventory_state", {}) as Dictionary
	var items: Array = inventory_state.get("items", [])
	for reward in rewards:
		items.append(reward)
	inventory_state["items"] = items
	run_state["inventory_state"] = inventory_state


func apply_gold_delta(gold_delta: int) -> void:
	if gold_delta == 0:
		return
	var current_gold: int = int(run_state.get("gold", 0))
	run_state["gold"] = maxi(0, current_gold + gold_delta)


func get_gold() -> int:
	return int(run_state.get("gold", 0))


func get_chapter_index() -> int:
	return int(run_state.get("chapter_index", 1))


func get_run_id() -> String:
	return String(run_state.get("run_id", ""))


func get_seed() -> int:
	return int(run_state.get("seed", 1))


func get_core_state() -> Dictionary:
	return sanitize_core_state(run_state.get("core_state", {}) as Dictionary)


func ensure_defaults() -> void:
	if run_state.is_empty():
		return

	var party_state: Dictionary = run_state.get("party_state", {}) as Dictionary
	var selected_count: int = int(party_state.get("selected_count", DEFAULT_PARTY_SIZE))
	selected_count = maxi(1, selected_count)
	var snapshots: Array[Dictionary] = snapshot_array(party_state.get("heroes", []))
	if snapshots.is_empty():
		snapshots = build_default_party_snapshots(selected_count)
	party_state["heroes"] = snapshots
	party_state["selected_count"] = snapshots.size()
	party_state["max_count"] = int(party_state.get("max_count", DEFAULT_PARTY_MAX))
	run_state["party_state"] = party_state

	run_state["core_state"] = sanitize_core_state(run_state.get("core_state", {}) as Dictionary)
