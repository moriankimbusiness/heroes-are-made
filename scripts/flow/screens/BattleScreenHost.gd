extends Node

signal battle_finished(victory: bool, summary: Dictionary)

const LEVEL_SCENE := preload("res://scenes/levels/level_01.tscn")
const DEFAULT_BATTLE_MAP_VARIANTS: Array[PackedScene] = [
	preload("res://scenes/maps/variants/battle_map_01.tscn"),
	preload("res://scenes/maps/variants/battle_map_02.tscn")
]

@export_group("전투 맵 변형")
## 전투 진입 시 선택할 맵 변형 목록입니다.
@export var battle_map_variants: Array[PackedScene] = DEFAULT_BATTLE_MAP_VARIANTS
## payload에 seed가 없을 때 사용할 기본 시드 값입니다.
@export var fallback_map_seed: int = 0

@onready var _battle_root: Node = $BattleRoot

var _battle_instance: Node = null
var _battle_completed: bool = false
var _battle_started_msec: int = 0
var _battle_payload: Dictionary = {}


func show_screen(payload: Dictionary = {}) -> void:
	hide_screen()
	_battle_completed = false
	_battle_payload = payload.duplicate(true)
	_battle_started_msec = Time.get_ticks_msec()

	_battle_instance = LEVEL_SCENE.instantiate()
	_battle_root.add_child(_battle_instance)
	_configure_battle_scene(_battle_instance, payload)

	var round_manager: Node = _battle_instance.get_node_or_null("RoundSystem/RoundManager")
	if round_manager != null:
		if round_manager.has_signal("all_rounds_cleared"):
			round_manager.connect("all_rounds_cleared", _on_rounds_cleared)
		if round_manager.has_signal("game_failed"):
			round_manager.connect("game_failed", _on_round_failed)

	var core_node: Node = _battle_instance.get_node_or_null("CoreRoot")
	if core_node != null and core_node.has_signal("destroyed"):
		core_node.connect("destroyed", _on_core_destroyed)

	_connect_hero_death_signals()
	call_deferred("_check_all_heroes_dead_after_setup")


func hide_screen() -> void:
	if _battle_instance != null and is_instance_valid(_battle_instance):
		_battle_instance.queue_free()
	_battle_instance = null
	_battle_completed = false
	_battle_started_msec = 0
	_battle_payload.clear()


func _configure_battle_scene(battle_scene: Node, payload: Dictionary) -> void:
	var party_count: int = int(payload.get("party_count", 3))
	var current_gold: int = int(payload.get("gold", 0))
	var party_snapshots: Array = payload.get("party_snapshots", [])
	_apply_map_variant(battle_scene, payload)
	var playground: Node = battle_scene.get_node_or_null("PlayGround")
	if playground != null and playground.has_method("summon_hero"):
		if party_snapshots.is_empty():
			for _i in range(maxi(1, party_count)):
				playground.call("summon_hero")
		else:
			for snapshot_var in party_snapshots:
				var hero: Node = playground.call("summon_hero")
				if hero == null or not is_instance_valid(hero):
					continue
				if snapshot_var is Dictionary and hero.has_method("apply_run_state"):
					if hero.has_method("is_node_ready") and not bool(hero.call("is_node_ready")):
						hero.call_deferred("apply_run_state", snapshot_var)
					else:
						hero.call("apply_run_state", snapshot_var)
	var hero_ui: CanvasLayer = battle_scene.get_node_or_null("PlayGround/HeroHUD") as CanvasLayer
	if hero_ui != null and hero_ui.has_method("set_starting_gold"):
		hero_ui.call("set_starting_gold", current_gold)
	_apply_core_state(payload)


func _apply_core_state(payload: Dictionary) -> void:
	if _battle_instance == null or not is_instance_valid(_battle_instance):
		return
	var core_state: Dictionary = payload.get("core_state", {}) as Dictionary
	if core_state.is_empty():
		return
	var core_node: Node = _battle_instance.get_node_or_null("CoreRoot")
	if core_node == null:
		return
	var max_health: float = maxf(1.0, float(core_state.get("max_health", 300.0)))
	var current_health: float = clampf(float(core_state.get("current_health", max_health)), 0.0, max_health)
	if core_node.has_method("set_max_health"):
		core_node.call("set_max_health", max_health, false)
	if core_node.has_method("set_current_health"):
		core_node.call("set_current_health", current_health, false)


func _apply_map_variant(battle_scene: Node, payload: Dictionary) -> void:
	var variants: Array[PackedScene] = _resolve_map_variants()
	if variants.is_empty():
		return

	var seed_value: int = int(payload.get("seed", fallback_map_seed))
	var node_id: int = int(payload.get("node_id", 0))
	var variant_index: int = _pick_variant_index(seed_value, node_id, variants.size())
	var selected_variant: PackedScene = variants[variant_index]

	var battle_map_slot: Node = battle_scene.get_node_or_null("BattleMapSlot")
	if battle_map_slot == null:
		push_warning("BattleScreenHost: BattleMapSlot not found, map variant apply skipped.")
		return

	for child: Node in battle_map_slot.get_children():
		child.queue_free()

	var battle_map_instance: Node = selected_variant.instantiate()
	battle_map_instance.name = "BattleMap"
	battle_map_slot.add_child(battle_map_instance)

	var playground: Node = battle_scene.get_node_or_null("PlayGround")
	if playground != null and playground.has_method("set_battle_map"):
		playground.call("set_battle_map", battle_map_instance)


func _resolve_map_variants() -> Array[PackedScene]:
	var resolved: Array[PackedScene] = []
	for scene: PackedScene in battle_map_variants:
		if scene != null:
			resolved.append(scene)
	return resolved


func _pick_variant_index(seed_value: int, node_id: int, variant_count: int) -> int:
	if variant_count <= 1:
		return 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var mixed_seed: int = seed_value * 1103515245 + node_id * 12345 + variant_count * 265443576
	rng.seed = int(absi(mixed_seed))
	return int(rng.randi() % variant_count)


func _on_rounds_cleared() -> void:
	_emit_once(true, {"reason": "all_rounds_cleared"})


func _on_round_failed(_alive_enemy_count: int, _threshold: int) -> void:
	_emit_once(false, {"reason": "game_failed"})


func _on_core_destroyed(_core: Area2D) -> void:
	_emit_once(false, {"reason": "core_destroyed"})


func _check_all_heroes_dead_after_setup() -> void:
	if _are_all_battle_heroes_dead():
		_emit_once(false, {"reason": "all_heroes_dead"})


func _emit_once(victory: bool, summary: Dictionary) -> void:
	if _battle_completed:
		return
	_battle_completed = true
	var merged_summary: Dictionary = _build_battle_summary(victory, summary)
	battle_finished.emit(victory, merged_summary)


func _build_battle_summary(victory: bool, base_summary: Dictionary) -> Dictionary:
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

	summary["party_snapshots"] = _collect_party_snapshots()
	summary["all_heroes_dead"] = _are_all_battle_heroes_dead()

	var collected_gold_end: int = _collect_gold_end()
	if collected_gold_end >= 0:
		summary["gold_end"] = collected_gold_end

	var collected_core_state: Dictionary = _collect_core_state()
	if not collected_core_state.is_empty():
		summary["core_state"] = collected_core_state

	return summary


func _connect_hero_death_signals() -> void:
	if _battle_instance == null or not is_instance_valid(_battle_instance):
		return
	for node: Node in get_tree().get_nodes_in_group(&"hero"):
		if not _battle_instance.is_ancestor_of(node):
			continue
		if not node.has_signal("died"):
			continue
		var died_callable: Callable = Callable(self, "_on_hero_died")
		if node.is_connected("died", died_callable):
			continue
		node.connect("died", died_callable)


func _on_hero_died(_hero: Node) -> void:
	if _are_all_battle_heroes_dead():
		_emit_once(false, {"reason": "all_heroes_dead"})


func _are_all_battle_heroes_dead() -> bool:
	if _battle_instance == null or not is_instance_valid(_battle_instance):
		return false
	var has_hero: bool = false
	for node: Node in get_tree().get_nodes_in_group(&"hero"):
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


func _collect_party_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	if _battle_instance == null or not is_instance_valid(_battle_instance):
		return snapshots
	for node: Node in get_tree().get_nodes_in_group(&"hero"):
		if not _battle_instance.is_ancestor_of(node):
			continue
		if not is_instance_valid(node):
			continue
		if not node.has_method("to_run_state"):
			continue
		var snapshot: Dictionary = node.call("to_run_state") as Dictionary
		snapshots.append(snapshot)
	return snapshots


func _collect_gold_end() -> int:
	if _battle_instance == null or not is_instance_valid(_battle_instance):
		return -1
	var shop_panel: Node = _battle_instance.get_node_or_null("PlayGround/HeroHUD/HeroInterfaceRoot/InterfacePanel/MarginContainer/MainRow/ShopColumn")
	if shop_panel == null:
		return -1
	if not shop_panel.has_method("get_gold"):
		return -1
	return int(shop_panel.call("get_gold"))


func _collect_core_state() -> Dictionary:
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
