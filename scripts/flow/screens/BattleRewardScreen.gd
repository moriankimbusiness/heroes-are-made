extends PanelContainer

signal reward_selected(result: Dictionary)

const DEFAULT_REWARD_POOL: Array[String] = [
	"전술 유물",
	"화력 증폭 카드",
	"방벽 유물",
	"치유 물약",
	"속사 장갑",
	"정밀 조준 카드",
	"철갑 갑옷",
	"재생의 부적"
]

const REWARD_POOL_BY_NODE_TYPE: Dictionary = {
	"normal_battle": DEFAULT_REWARD_POOL,
	"mid_boss": [
		"중간보스 트로피",
		"희귀 전술 유물",
		"강인함의 문장",
		"폭풍 사격 카드",
		"강화형 철갑 갑옷"
	],
	"final_boss": [
		"최종보스 트로피",
		"전설 전술 유물",
		"마왕 격파 문장",
		"궁극 화력 카드",
		"불멸의 갑주"
	]
}

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _summary_label: Label = $MarginContainer/VBoxContainer/SummaryLabel
@onready var _option_1_button: Button = $MarginContainer/VBoxContainer/ChoiceButtons/Option1Button
@onready var _option_2_button: Button = $MarginContainer/VBoxContainer/ChoiceButtons/Option2Button
@onready var _option_3_button: Button = $MarginContainer/VBoxContainer/ChoiceButtons/Option3Button
@onready var _confirm_button: Button = $MarginContainer/VBoxContainer/ConfirmButton

var _rng := RandomNumberGenerator.new()
var _node_id: int = -1
var _node_type: String = ""
var _choice_buttons: Array[Button] = []
var _selected_reward: String = ""


func _ready() -> void:
	_choice_buttons = [_option_1_button, _option_2_button, _option_3_button]
	for i in range(_choice_buttons.size()):
		_choice_buttons[i].pressed.connect(_on_option_pressed.bind(i))
	_confirm_button.pressed.connect(_on_confirm_pressed)
	hide_screen()


func show_screen(payload: Dictionary = {}) -> void:
	_node_id = int(payload.get("node_id", -1))
	_node_type = String(payload.get("node_type", "normal_battle"))
	_selected_reward = ""
	_confirm_button.disabled = true

	var rng_seed: int = int(payload.get("rng_seed", 0))
	if rng_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = rng_seed

	var battle_summary: Dictionary = payload.get("battle_summary", {}) as Dictionary
	_title_label.text = "전투 보상 선택 (노드 %d)" % _node_id
	_summary_label.text = _build_summary_text(battle_summary)
	_assign_reward_options()
	_refresh_selection_visual()
	visible = true


func hide_screen() -> void:
	visible = false
	_selected_reward = ""
	_confirm_button.disabled = true
	_summary_label.text = "-"
	for button in _choice_buttons:
		button.text = "-"
	_refresh_selection_visual()


func _build_summary_text(battle_summary: Dictionary) -> String:
	var round_index: int = int(battle_summary.get("round_index", 0))
	var round_total: int = int(battle_summary.get("round_total", 0))
	var elapsed_seconds: float = float(battle_summary.get("elapsed_seconds", 0.0))
	var gold_end: int = int(battle_summary.get("gold_end", 0))
	if round_index <= 0 or round_total <= 0:
		return "전투 종료 · %.1fs · 현재 골드 %d" % [elapsed_seconds, gold_end]
	return "라운드 %d/%d 클리어 · %.1fs · 현재 골드 %d" % [round_index, round_total, elapsed_seconds, gold_end]


func _assign_reward_options() -> void:
	var pool: Array[String] = _resolve_reward_pool(_node_type)
	if pool.is_empty():
		pool = DEFAULT_REWARD_POOL.duplicate()
	var shuffled: Array[String] = []
	var working: Array[String] = pool.duplicate()
	while not working.is_empty():
		var index: int = _rng.randi_range(0, working.size() - 1)
		shuffled.append(working[index])
		working.remove_at(index)

	for i in range(_choice_buttons.size()):
		var reward_name: String = "보상 없음"
		if i < shuffled.size():
			reward_name = shuffled[i]
		var button: Button = _choice_buttons[i]
		button.text = reward_name
		button.set_meta("reward_name", reward_name)


func _resolve_reward_pool(node_type: String) -> Array[String]:
	var candidate: Variant = REWARD_POOL_BY_NODE_TYPE.get(node_type, DEFAULT_REWARD_POOL)
	var result: Array[String] = []
	if candidate is Array:
		for row in candidate:
			result.append(String(row))
	return result


func _on_option_pressed(index: int) -> void:
	if index < 0 or index >= _choice_buttons.size():
		return
	var selected_button: Button = _choice_buttons[index]
	_selected_reward = String(selected_button.get_meta("reward_name", ""))
	_confirm_button.disabled = _selected_reward.is_empty()
	_refresh_selection_visual()


func _refresh_selection_visual() -> void:
	for button in _choice_buttons:
		var is_selected: bool = String(button.get_meta("reward_name", "")) == _selected_reward and not _selected_reward.is_empty()
		button.disabled = false
		button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if is_selected:
			button.modulate = Color(0.72, 1.0, 0.78, 1.0)


func _on_confirm_pressed() -> void:
	if _selected_reward.is_empty():
		return
	reward_selected.emit({
		"node_id": _node_id,
		"result_type": "success",
		"gold_delta": 0,
		"hp_delta": 0,
		"granted_rewards": [_selected_reward],
		"consumed_resources": [],
		"next_state": "result",
		"note": "전투 보상 선택 완료: %s" % _selected_reward
	})
