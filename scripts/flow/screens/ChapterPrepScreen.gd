extends PanelContainer

signal start_expedition_requested
signal back_to_menu_requested

@onready var _chapter_prep_label: Label = $MarginContainer/VBoxContainer/ChapterPrepLabel
@onready var _party_label: Label = $MarginContainer/VBoxContainer/PartyLabel
@onready var _start_button: Button = $MarginContainer/VBoxContainer/StartExpeditionButton
@onready var _back_button: Button = $MarginContainer/VBoxContainer/BackToMenuButton


func _ready() -> void:
	_start_button.pressed.connect(func() -> void: start_expedition_requested.emit())
	_back_button.pressed.connect(func() -> void: back_to_menu_requested.emit())
	hide_screen()


func show_screen(payload: Dictionary = {}) -> void:
	var chapter_index: int = int(payload.get("chapter_index", 1))
	var selected_count: int = int(payload.get("selected_count", 3))
	var max_count: int = int(payload.get("max_count", 4))
	_chapter_prep_label.text = "챕터 %d 출정 준비" % chapter_index
	_party_label.text = "편성: %d/%d (준비 화면에서는 편성/장비관리만 허용)" % [selected_count, max_count]
	visible = true


func hide_screen() -> void:
	visible = false
