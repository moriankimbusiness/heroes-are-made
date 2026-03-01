extends Node

signal enemy_spawned(enemy: Area2D)

@export_group("라운드 JSON 설정")
## 레벨 스폰 테이블 JSON 파일 경로입니다.
@export_file("*.json") var round_table_json_path: String = ""
@export_group("필수 노드 경로")
## 스폰 기준 포탈 노드 경로입니다.
@export var portal_path: NodePath
## 코어 노드 경로입니다.
@export var core_path: NodePath
## 적 스폰 타이머 노드 경로입니다.
@export var spawn_timer_path: NodePath
## 적 스폰 부모 노드 경로입니다.
@export var spawn_parent_path: NodePath = NodePath("..")
@export_group("런타임 제어")
## 현재 라운드 최대 스폰 수입니다.
@export var max_spawn_count: int = 0
## 현재 진행 라운드 번호(1부터 시작)입니다.
@export_range(1, 999, 1) var current_round: int = 1

var _spawned_count: int = 0
var _round_spawn_queue: Array[PackedScene] = []
var _is_round_table_ready: bool = false
var _final_round_limit: int = 0
var _seed_value: int = 0
var _node_id: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _enemy_catalog: Array[Dictionary] = []
var _enemy_by_id: Dictionary = {}
var _spawn_plan_by_round: Dictionary = {}

@onready var _portal: Node2D = get_node_or_null(portal_path) as Node2D
@onready var _core: Node2D = get_node_or_null(core_path) as Node2D
@onready var _spawn_timer: Timer = get_node_or_null(spawn_timer_path) as Timer
@onready var _spawn_parent: Node = get_node_or_null(spawn_parent_path)


func _ready() -> void:
	if _portal == null:
		push_error("EnemySpawnController: portal_path is invalid.")
		return
	if _spawn_timer == null:
		push_error("EnemySpawnController: spawn_timer_path is invalid.")
		return
	if _spawn_parent == null:
		push_error("EnemySpawnController: spawn_parent_path is invalid.")
		return

	if _core == null:
		var core_node: Node = get_tree().get_first_node_in_group(&"core")
		if core_node is Node2D:
			_core = core_node as Node2D

	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	_is_round_table_ready = _load_round_table()


func _on_spawn_timer_timeout() -> void:
	if _spawned_count >= max_spawn_count:
		_spawn_timer.stop()
		return

	if _spawned_count >= _round_spawn_queue.size():
		_spawn_timer.stop()
		return

	var selected_enemy_scene: PackedScene = _round_spawn_queue[_spawned_count]
	if selected_enemy_scene == null:
		push_error("EnemySpawnController: enemy scene is not assigned.")
		_spawn_timer.stop()
		return

	var enemy: Node2D = selected_enemy_scene.instantiate() as Node2D
	if enemy == null:
		push_error("EnemySpawnController: selected enemy scene root must inherit Node2D.")
		_spawn_timer.stop()
		return

	var spawn_parent: Node = _get_spawn_parent()
	if spawn_parent == null:
		push_error("EnemySpawnController: spawn_parent_path is invalid at runtime.")
		_spawn_timer.stop()
		return
	spawn_parent.add_child(enemy)
	enemy.global_position = _portal.global_position
	if _core != null and enemy.has_method("set_core_target"):
		enemy.call("set_core_target", _core)
	_spawned_count += 1
	if enemy is Area2D:
		enemy_spawned.emit(enemy as Area2D)
	if _spawned_count >= max_spawn_count:
		_spawn_timer.stop()


func set_round(round_value: int) -> void:
	current_round = maxi(1, round_value)


func begin_round_spawn() -> void:
	if not _is_round_table_ready:
		push_error("EnemySpawnController: round table is not ready.")
		stop_spawn()
		return
	_spawned_count = 0
	_round_spawn_queue = _build_round_spawn_queue(current_round)
	max_spawn_count = _round_spawn_queue.size()
	if max_spawn_count <= 0:
		push_error("EnemySpawnController: no spawn entries for round %d." % current_round)
		stop_spawn()
		return
	_spawn_timer.start()


func stop_spawn() -> void:
	if _spawn_timer != null:
		_spawn_timer.stop()


func is_round_spawn_finished() -> bool:
	if _spawned_count < max_spawn_count:
		return false
	if _spawn_timer != null and not _spawn_timer.is_stopped():
		return false
	return true


func configure_random_context(seed_value: int, node_id: int) -> void:
	_seed_value = seed_value
	_node_id = node_id


func set_final_round_limit(final_round_value: int) -> void:
	_final_round_limit = maxi(1, final_round_value)


func _load_round_table() -> bool:
	if round_table_json_path.strip_edges().is_empty():
		return _fatal("round_table_json_path is empty.")
	if not FileAccess.file_exists(round_table_json_path):
		return _fatal("Missing round table json: %s" % round_table_json_path)

	var file: FileAccess = FileAccess.open(round_table_json_path, FileAccess.READ)
	if file == null:
		return _fatal("Failed to open round table: %s (error=%d)" % [round_table_json_path, FileAccess.get_open_error()])

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fatal("Invalid JSON root. Dictionary expected.")
	var root: Dictionary = parsed

	_enemy_catalog.clear()
	_enemy_by_id.clear()
	_spawn_plan_by_round.clear()

	if not _parse_enemy_catalog(root):
		return false
	if not _parse_spawn_plan(root):
		return false
	return true


func _parse_enemy_catalog(root: Dictionary) -> bool:
	if not root.has("enemies"):
		return _fatal("Missing required key: enemies")
	if typeof(root["enemies"]) != TYPE_ARRAY:
		return _fatal("enemies must be an array")

	var enemies_raw: Array = root["enemies"]
	if enemies_raw.is_empty():
		return _fatal("enemies must not be empty")

	for i: int in enemies_raw.size():
		var raw_enemy: Variant = enemies_raw[i]
		var context: String = "enemies[%d]" % i
		if typeof(raw_enemy) != TYPE_DICTIONARY:
			return _fatal("%s must be a dictionary" % context)
		var enemy_dict: Dictionary = raw_enemy

		if not enemy_dict.has("id") or typeof(enemy_dict["id"]) != TYPE_STRING:
			return _fatal("%s.id must be a string" % context)
		var enemy_id_text: String = String(enemy_dict["id"]).strip_edges()
		if enemy_id_text.is_empty():
			return _fatal("%s.id must not be empty" % context)
		var enemy_id: StringName = StringName(enemy_id_text)
		if _enemy_by_id.has(enemy_id):
			return _fatal("Duplicate enemy id: %s" % enemy_id_text)

		if not enemy_dict.has("scene_path") or typeof(enemy_dict["scene_path"]) != TYPE_STRING:
			return _fatal("%s.scene_path must be a string" % context)
		var scene_path: String = String(enemy_dict["scene_path"]).strip_edges()
		if scene_path.is_empty():
			return _fatal("%s.scene_path must not be empty" % context)
		var loaded_scene: Resource = load(scene_path)
		if loaded_scene == null or not (loaded_scene is PackedScene):
			return _fatal("%s.scene_path could not load PackedScene: %s" % [context, scene_path])

		if not enemy_dict.has("spawn_count"):
			return _fatal("%s.spawn_count is required" % context)
		var spawn_count_value: Variant = enemy_dict["spawn_count"]
		if typeof(spawn_count_value) != TYPE_INT and typeof(spawn_count_value) != TYPE_FLOAT:
			return _fatal("%s.spawn_count must be a number" % context)
		var spawn_count: int = int(roundi(float(spawn_count_value)))
		if spawn_count <= 0:
			return _fatal("%s.spawn_count must be >= 1" % context)

		if not enemy_dict.has("weight"):
			return _fatal("%s.weight is required" % context)
		var weight_value: Variant = enemy_dict["weight"]
		if typeof(weight_value) != TYPE_INT and typeof(weight_value) != TYPE_FLOAT:
			return _fatal("%s.weight must be a number" % context)
		var weight: float = float(weight_value)
		if weight <= 0.0:
			return _fatal("%s.weight must be > 0" % context)

		var enemy_entry: Dictionary = {
			"id": enemy_id,
			"scene": loaded_scene as PackedScene,
			"spawn_count": spawn_count,
			"weight": weight
		}
		_enemy_catalog.append(enemy_entry)
		_enemy_by_id[enemy_id] = enemy_entry

	return true


func _parse_spawn_plan(root: Dictionary) -> bool:
	if not root.has("spawn_plan"):
		return true
	if typeof(root["spawn_plan"]) != TYPE_ARRAY:
		return _fatal("spawn_plan must be an array")

	var spawn_plan_raw: Array = root["spawn_plan"]
	for i: int in spawn_plan_raw.size():
		var raw_entry: Variant = spawn_plan_raw[i]
		var context: String = "spawn_plan[%d]" % i
		if typeof(raw_entry) != TYPE_DICTIONARY:
			return _fatal("%s must be a dictionary" % context)
		var entry: Dictionary = raw_entry

		if not entry.has("round"):
			return _fatal("%s.round is required" % context)
		var round_value: Variant = entry["round"]
		if typeof(round_value) != TYPE_INT and typeof(round_value) != TYPE_FLOAT:
			return _fatal("%s.round must be a number" % context)
		var round_number: int = int(roundi(float(round_value)))
		if round_number <= 0:
			return _fatal("%s.round must be >= 1" % context)
		if _final_round_limit > 0 and round_number > _final_round_limit:
			return _fatal("%s.round (%d) must be <= final_round (%d)" % [context, round_number, _final_round_limit])

		if not entry.has("enemy_id") or typeof(entry["enemy_id"]) != TYPE_STRING:
			return _fatal("%s.enemy_id must be a string" % context)
		var enemy_id_text: String = String(entry["enemy_id"]).strip_edges()
		if enemy_id_text.is_empty():
			return _fatal("%s.enemy_id must not be empty" % context)
		var enemy_id: StringName = StringName(enemy_id_text)
		if not _enemy_by_id.has(enemy_id):
			return _fatal("%s.enemy_id references unknown id: %s" % [context, enemy_id_text])

		if not entry.has("count"):
			return _fatal("%s.count is required" % context)
		var count_value: Variant = entry["count"]
		if typeof(count_value) != TYPE_INT and typeof(count_value) != TYPE_FLOAT:
			return _fatal("%s.count must be a number" % context)
		var count: int = int(roundi(float(count_value)))
		if count <= 0:
			return _fatal("%s.count must be >= 1" % context)

		var round_entries: Array = _spawn_plan_by_round.get(round_number, [])
		round_entries.append({
			"enemy_id": enemy_id,
			"count": count
		})
		_spawn_plan_by_round[round_number] = round_entries

	return true


func _build_round_spawn_queue(round_number: int) -> Array[PackedScene]:
	if _spawn_plan_by_round.has(round_number):
		return _build_spawn_plan_queue(round_number)
	return _build_weighted_random_queue(round_number)


func _build_spawn_plan_queue(round_number: int) -> Array[PackedScene]:
	var queue: Array[PackedScene] = []
	var plan_entries: Array = _spawn_plan_by_round.get(round_number, [])
	for plan_entry_var: Variant in plan_entries:
		var plan_entry: Dictionary = plan_entry_var as Dictionary
		var enemy_id: StringName = StringName(String(plan_entry.get("enemy_id", "")))
		var count: int = int(plan_entry.get("count", 0))
		if count <= 0:
			continue
		var enemy_entry: Dictionary = _enemy_by_id.get(enemy_id, {})
		var enemy_scene: PackedScene = enemy_entry.get("scene", null) as PackedScene
		if enemy_scene == null:
			continue
		for _i: int in range(count):
			queue.append(enemy_scene)
	return queue


func _build_weighted_random_queue(round_number: int) -> Array[PackedScene]:
	var queue: Array[PackedScene] = []
	var remaining_counts: Dictionary = {}
	var remaining_total: int = 0
	for enemy_entry: Dictionary in _enemy_catalog:
		var enemy_id: StringName = StringName(String(enemy_entry.get("id", "")))
		var spawn_count: int = int(enemy_entry["spawn_count"])
		remaining_counts[enemy_id] = spawn_count
		remaining_total += spawn_count

	_reset_round_rng(round_number)

	while remaining_total > 0:
		var selected_enemy_id: StringName = _pick_weighted_enemy_id(remaining_counts)
		if selected_enemy_id == StringName():
			break
		var selected_entry: Dictionary = _enemy_by_id.get(selected_enemy_id, {})
		var selected_scene: PackedScene = selected_entry.get("scene", null) as PackedScene
		if selected_scene == null:
			break
		queue.append(selected_scene)
		remaining_counts[selected_enemy_id] = int(remaining_counts.get(selected_enemy_id, 0)) - 1
		remaining_total -= 1

	return queue


func _pick_weighted_enemy_id(remaining_counts: Dictionary) -> StringName:
	var total_weight: float = 0.0
	for enemy_entry: Dictionary in _enemy_catalog:
		var enemy_id: StringName = StringName(String(enemy_entry.get("id", "")))
		var remaining: int = int(remaining_counts.get(enemy_id, 0))
		if remaining <= 0:
			continue
		total_weight += float(enemy_entry["weight"])
	if total_weight <= 0.0:
		return StringName()

	var roll: float = _rng.randf() * total_weight
	var cumulative_weight: float = 0.0
	var fallback_enemy_id: StringName = StringName()
	for enemy_entry: Dictionary in _enemy_catalog:
		var enemy_id: StringName = StringName(String(enemy_entry.get("id", "")))
		var remaining: int = int(remaining_counts.get(enemy_id, 0))
		if remaining <= 0:
			continue
		fallback_enemy_id = enemy_id
		cumulative_weight += float(enemy_entry["weight"])
		if roll <= cumulative_weight:
			return enemy_id

	return fallback_enemy_id


func _reset_round_rng(round_number: int) -> void:
	var mixed_seed: int = int(_seed_value * 1103515245 + _node_id * 12345 + round_number * 265443576)
	_rng.seed = int(absi(mixed_seed))


func _fatal(message: String) -> bool:
	push_error("EnemySpawnController: %s" % message)
	return false


func _get_spawn_parent() -> Node:
	if _spawn_parent != null and is_instance_valid(_spawn_parent):
		return _spawn_parent
	if spawn_parent_path != NodePath():
		_spawn_parent = get_node_or_null(spawn_parent_path)
		if _spawn_parent != null and is_instance_valid(_spawn_parent):
			return _spawn_parent
	var fallback_parent: Node = get_parent()
	if fallback_parent != null and is_instance_valid(fallback_parent):
		return fallback_parent
	return null
