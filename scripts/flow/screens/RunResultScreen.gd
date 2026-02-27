extends PanelContainer

signal restart_requested
signal back_to_menu_requested

@onready var _run_result_label: Label = $MarginContainer/VBoxContainer/RunResultLabel
@onready var _restart_button: Button = $MarginContainer/VBoxContainer/RestartButton
@onready var _to_menu_button: Button = $MarginContainer/VBoxContainer/ToMenuButton


func _ready() -> void:
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	_to_menu_button.pressed.connect(func() -> void: back_to_menu_requested.emit())
	hide_screen()


func show_screen(payload: Dictionary = {}) -> void:
	var result_kind: String = String(payload.get("result_kind", "failed"))
	if result_kind == "cleared":
		var chapter_id: int = int(payload.get("chapter_id", 1))
		_run_result_label.text = "런 성공\n챕터 %d 클리어" % chapter_id
	else:
		_run_result_label.text = "런 실패\n사유: %s" % String(payload.get("reason", "unknown"))
	visible = true


func hide_screen() -> void:
	visible = false
