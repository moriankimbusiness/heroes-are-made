extends PanelContainer

signal node_resolved(result: Dictionary)
signal resolution_cancelled

const NODE_TYPE_ITEM := "item"
const NODE_TYPE_TOWN := "town"
const NODE_TYPE_EVENT := "event"

@onready var _node_title_label: Label = $MarginContainer/VBoxContainer/NodeTitleLabel
@onready var _node_description_label: Label = $MarginContainer/VBoxContainer/NodeDescriptionLabel
@onready var _node_choices_root: VBoxContainer = $MarginContainer/VBoxContainer/NodeChoices

var _rng := RandomNumberGenerator.new()
var _node_id: int = -1
var _node_type: String = ""
var _current_gold: int = 0
var _item_candidates: Array[String] = []


func _ready() -> void:
	hide_screen()


func show_screen(payload: Dictionary = {}) -> void:
	_node_id = int(payload.get("node_id", -1))
	_node_type = String(payload.get("node_type", ""))
	_current_gold = int(payload.get("current_gold", 0))
	var rng_seed: int = int(payload.get("rng_seed", 0))
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()

	_node_title_label.text = "노드 %d: %s" % [_node_id, _node_title(_node_type)]
	_node_description_label.text = _node_description(_node_type)
	_rebuild_choices()
	visible = true


func hide_screen() -> void:
	for child in _node_choices_root.get_children():
		child.queue_free()
	visible = false


func _node_title(node_type: String) -> String:
	match node_type:
		NODE_TYPE_ITEM:
			return "아이템 획득"
		NODE_TYPE_TOWN:
			return "마을"
		NODE_TYPE_EVENT:
			return "이벤트"
		_:
			return node_type


func _node_description(node_type: String) -> String:
	match node_type:
		NODE_TYPE_ITEM:
			return "보상 3개 중 1개를 선택합니다."
		NODE_TYPE_TOWN:
			return "회복/강화/상점 중 하나를 선택하고 정비를 마칩니다."
		NODE_TYPE_EVENT:
			return "선택지에 따라 보상과 리스크가 결정됩니다."
		_:
			return "처리 가능한 액션이 없습니다."


func _rebuild_choices() -> void:
	for child in _node_choices_root.get_children():
		child.queue_free()

	match _node_type:
		NODE_TYPE_ITEM:
			_build_item_choices()
		NODE_TYPE_TOWN:
			_build_town_choices()
		NODE_TYPE_EVENT:
			_build_event_choices()
		_:
			_add_choice_button("계속", "resolve_generic", {})


func _build_item_choices() -> void:
	_item_candidates = _roll_reward_candidates(3)
	for reward in _item_candidates:
		_add_choice_button("획득: %s" % reward, "item_reward", {"reward": reward})
	_add_choice_button("건너뛰기", "item_skip", {})


func _build_town_choices() -> void:
	_add_choice_button("회복 (20G)", "town_heal", {"cost": 20})
	_add_choice_button("강화 (30G)", "town_upgrade", {"cost": 30})
	_add_choice_button("상점 구매 (25G)", "town_shop", {"cost": 25})
	_add_choice_button("정비 완료", "town_finish", {})


func _build_event_choices() -> void:
	_add_choice_button("안전한 선택 (+20G)", "event_safe", {})
	_add_choice_button("위험한 선택 (고위험 고보상)", "event_risky", {})


func _add_choice_button(label: String, action: String, payload: Dictionary) -> void:
	var button := Button.new()
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.set_meta("action", action)
	button.set_meta("payload", payload)
	button.pressed.connect(_on_choice_button_pressed.bind(button))
	_node_choices_root.add_child(button)


func _on_choice_button_pressed(button: Button) -> void:
	var action: String = String(button.get_meta("action", ""))
	var payload: Dictionary = button.get_meta("payload", {}) as Dictionary
	match action:
		"item_reward":
			_emit_result({
				"result_type": "success",
				"gold_delta": 0,
				"hp_delta": 0,
				"granted_rewards": [String(payload.get("reward", ""))],
				"consumed_resources": [],
				"next_state": "world",
				"note": "보상 선택 완료"
			})
		"item_skip":
			_emit_result({
				"result_type": "skip",
				"gold_delta": 0,
				"hp_delta": 0,
				"granted_rewards": [],
				"consumed_resources": [],
				"next_state": "world",
				"note": "보상을 건너뛰었습니다."
			})
		"town_heal":
			_try_town_action("회복", int(payload.get("cost", 20)))
		"town_upgrade":
			_try_town_action("강화", int(payload.get("cost", 30)))
		"town_shop":
			_try_town_action("상점", int(payload.get("cost", 25)))
		"town_finish":
			_emit_result({
				"result_type": "success",
				"gold_delta": 0,
				"hp_delta": 0,
				"granted_rewards": [],
				"consumed_resources": [],
				"next_state": "world",
				"note": "마을 정비를 마쳤습니다."
			})
		"event_safe":
			_emit_result({
				"result_type": "success",
				"gold_delta": 20,
				"hp_delta": 0,
				"granted_rewards": [],
				"consumed_resources": [],
				"next_state": "world",
				"note": "안전한 선택으로 20골드를 획득했습니다."
			})
		"event_risky":
			_resolve_risky_event()
		"resolve_generic":
			_emit_result({
				"result_type": "success",
				"gold_delta": 0,
				"hp_delta": 0,
				"granted_rewards": [],
				"consumed_resources": [],
				"next_state": "world",
				"note": "노드를 처리했습니다."
			})
		_:
			pass


func _try_town_action(action_name: String, cost: int) -> void:
	if _current_gold < cost:
		_node_description_label.text = "골드가 부족합니다. (필요: %d, 보유: %d)" % [cost, _current_gold]
		return
	var rewards: Array[String] = []
	if action_name == "상점":
		var candidate: Array[String] = _roll_reward_candidates(1)
		if not candidate.is_empty():
			rewards.append(candidate[0])
	_emit_result({
		"result_type": "success",
		"gold_delta": -cost,
		"hp_delta": 0,
		"granted_rewards": rewards,
		"consumed_resources": ["gold:%d" % cost],
		"next_state": "world",
		"note": "마을에서 %s을(를) 수행했습니다." % action_name
	})


func _resolve_risky_event() -> void:
	var success: bool = _rng.randf() < 0.5
	if success:
		_emit_result({
			"result_type": "success",
			"gold_delta": 60,
			"hp_delta": 0,
			"granted_rewards": [],
			"consumed_resources": [],
			"next_state": "world",
			"note": "위험한 선택 성공: +60G"
		})
		return
	_emit_result({
		"result_type": "success",
		"gold_delta": -25,
		"hp_delta": 0,
		"granted_rewards": [],
		"consumed_resources": ["gold:25"],
		"next_state": "world",
		"note": "위험한 선택 실패: -25G"
	})


func _emit_result(result: Dictionary) -> void:
	var payload: Dictionary = result.duplicate(true)
	payload["node_id"] = _node_id
	node_resolved.emit(payload)


func _roll_reward_candidates(count: int) -> Array[String]:
	var reward_pool: Array[String] = [
		"정밀 조준 카드",
		"철갑 갑옷",
		"전술 유물",
		"화력 증폭 카드",
		"방벽 유물",
		"속사 장갑",
		"치유 물약",
		"강철 방패"
	]
	reward_pool.shuffle()
	var result: Array[String] = []
	for i in range(mini(count, reward_pool.size())):
		result.append(reward_pool[i])
	return result
