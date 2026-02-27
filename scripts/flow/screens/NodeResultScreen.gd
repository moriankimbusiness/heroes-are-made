extends PanelContainer

signal continue_requested

@onready var _result_label: Label = $MarginContainer/VBoxContainer/ResultLabel
@onready var _continue_button: Button = $MarginContainer/VBoxContainer/ContinueButton


func _ready() -> void:
	_continue_button.pressed.connect(func() -> void: continue_requested.emit())
	hide_screen()


func show_screen(payload: Dictionary = {}) -> void:
	var rewards: Array = payload.get("granted_rewards", [])
	var reward_text: String = "-"
	if not rewards.is_empty():
		reward_text = ", ".join(rewards)
	_result_label.text = "노드 해결 완료\n결과: %s\n골드 변화: %+d\n획득: %s" % [
		String(payload.get("note", "")),
		int(payload.get("gold_delta", 0)),
		reward_text
	]
	visible = true


func hide_screen() -> void:
	visible = false
