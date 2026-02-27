extends Node

signal battle_finished(victory: bool, summary: Dictionary)

const LEVEL_SCENE := preload("res://scenes/levels/level_01.tscn")

@onready var _battle_root: Node = $BattleRoot

var _battle_instance: Node = null
var _battle_completed: bool = false


func show_screen(payload: Dictionary = {}) -> void:
	hide_screen()
	_battle_completed = false

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


func hide_screen() -> void:
	if _battle_instance != null and is_instance_valid(_battle_instance):
		_battle_instance.queue_free()
	_battle_instance = null
	_battle_completed = false


func _configure_battle_scene(battle_scene: Node, payload: Dictionary) -> void:
	var party_count: int = int(payload.get("party_count", 3))
	var playground: Node = battle_scene.get_node_or_null("PlayGround")
	if playground != null and playground.has_method("summon_hero"):
		for _i in range(maxi(1, party_count)):
			playground.call("summon_hero")

	var summon_button: Button = battle_scene.get_node_or_null(
		"PlayGround/HeroHUD/BottomCenterUI/ButtonsRow/SummonButton"
	) as Button
	if summon_button != null:
		summon_button.visible = false
		summon_button.disabled = true


func _on_rounds_cleared() -> void:
	_emit_once(true, {"reason": "all_rounds_cleared"})


func _on_round_failed(_alive_enemy_count: int, _threshold: int) -> void:
	_emit_once(false, {"reason": "game_failed"})


func _on_core_destroyed(_core: Area2D) -> void:
	_emit_once(false, {"reason": "core_destroyed"})


func _emit_once(victory: bool, summary: Dictionary) -> void:
	if _battle_completed:
		return
	_battle_completed = true
	battle_finished.emit(victory, summary)
