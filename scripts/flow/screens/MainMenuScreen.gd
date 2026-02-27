extends PanelContainer

signal start_new_run_requested
signal continue_requested
signal quit_requested

@onready var _start_run_button: Button = $MarginContainer/VBoxContainer/StartRunButton
@onready var _continue_button: Button = $MarginContainer/VBoxContainer/ContinueRunButton
@onready var _quit_button: Button = $MarginContainer/VBoxContainer/QuitButton
@onready var _save_info_label: Label = $MarginContainer/VBoxContainer/SaveInfoLabel


func _ready() -> void:
	_start_run_button.pressed.connect(func() -> void: start_new_run_requested.emit())
	_continue_button.pressed.connect(func() -> void: continue_requested.emit())
	_quit_button.pressed.connect(func() -> void: quit_requested.emit())
	hide_screen()


func show_screen(payload: Dictionary = {}) -> void:
	var has_save: bool = bool(payload.get("has_save", false))
	_continue_button.visible = has_save
	_save_info_label.text = "저장된 진행 데이터가 있습니다." if has_save else "저장된 진행 데이터가 없습니다."
	visible = true


func hide_screen() -> void:
	visible = false
