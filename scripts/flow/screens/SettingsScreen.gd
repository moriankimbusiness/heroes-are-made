extends PanelContainer

signal back_requested

@onready var _resolution_option_button: OptionButton = $MarginContainer/VBoxContainer/ResolutionRow/ResolutionOptionButton
@onready var _fullscreen_check_box: CheckBox = $MarginContainer/VBoxContainer/ResolutionRow/FullscreenCheckBox
@onready var _bgm_volume_slider: HSlider = $MarginContainer/VBoxContainer/BgmRow/BgmVolumeSlider
@onready var _bgm_volume_label: Label = $MarginContainer/VBoxContainer/BgmRow/BgmVolumeLabel
@onready var _bgm_mute_check_box: CheckBox = $MarginContainer/VBoxContainer/BgmRow/BgmMuteCheckBox
@onready var _sfx_volume_slider: HSlider = $MarginContainer/VBoxContainer/SfxRow/SfxVolumeSlider
@onready var _sfx_volume_label: Label = $MarginContainer/VBoxContainer/SfxRow/SfxVolumeLabel
@onready var _sfx_mute_check_box: CheckBox = $MarginContainer/VBoxContainer/SfxRow/SfxMuteCheckBox
@onready var _back_button: Button = $MarginContainer/VBoxContainer/BackButton

var _syncing_ui: bool = false

const KEY_RESOLUTION_WIDTH := "resolution_width"
const KEY_RESOLUTION_HEIGHT := "resolution_height"
const KEY_FULLSCREEN := "fullscreen"
const KEY_BGM_VOLUME_DB := "bgm_volume_db"
const KEY_BGM_MUTED := "bgm_muted"
const KEY_SFX_VOLUME_DB := "sfx_volume_db"
const KEY_SFX_MUTED := "sfx_muted"


func _ready() -> void:
	_setup_resolution_options()
	_resolution_option_button.item_selected.connect(_on_resolution_selected)
	_fullscreen_check_box.toggled.connect(_on_fullscreen_toggled)
	_bgm_volume_slider.value_changed.connect(_on_bgm_volume_changed)
	_bgm_mute_check_box.toggled.connect(_on_bgm_mute_toggled)
	_sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	_sfx_mute_check_box.toggled.connect(_on_sfx_mute_toggled)
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	hide_screen()


func show_screen(payload: Dictionary = {}) -> void:
	var settings: Dictionary = payload.get("settings", AppSettings.get_settings()) as Dictionary
	apply_settings_to_ui(settings)
	visible = true


func hide_screen() -> void:
	visible = false


func apply_settings_to_ui(settings: Dictionary) -> void:
	_syncing_ui = true

	var resolution := Vector2i(
		int(settings.get(KEY_RESOLUTION_WIDTH, 1280)),
		int(settings.get(KEY_RESOLUTION_HEIGHT, 720))
	)
	var selected_index: int = _find_resolution_index(resolution)
	_resolution_option_button.select(selected_index)

	_fullscreen_check_box.button_pressed = bool(settings.get(KEY_FULLSCREEN, false))

	var bgm_db: float = float(settings.get(KEY_BGM_VOLUME_DB, 0.0))
	var bgm_percent: int = int(roundi(AppSettings.volume_db_to_linear(bgm_db) * 100.0))
	_bgm_volume_slider.value = bgm_percent
	_bgm_volume_label.text = "%d%%" % bgm_percent
	_bgm_mute_check_box.button_pressed = bool(settings.get(KEY_BGM_MUTED, false))

	var sfx_db: float = float(settings.get(KEY_SFX_VOLUME_DB, 0.0))
	var sfx_percent: int = int(roundi(AppSettings.volume_db_to_linear(sfx_db) * 100.0))
	_sfx_volume_slider.value = sfx_percent
	_sfx_volume_label.text = "%d%%" % sfx_percent
	_sfx_mute_check_box.button_pressed = bool(settings.get(KEY_SFX_MUTED, false))

	_syncing_ui = false


func _setup_resolution_options() -> void:
	_resolution_option_button.clear()
	var presets: Array[Vector2i] = AppSettings.get_resolution_presets()
	for preset: Vector2i in presets:
		var index: int = _resolution_option_button.item_count
		_resolution_option_button.add_item("%d x %d" % [preset.x, preset.y])
		_resolution_option_button.set_item_metadata(index, preset)


func _find_resolution_index(resolution: Vector2i) -> int:
	for i: int in range(_resolution_option_button.item_count):
		var metadata: Variant = _resolution_option_button.get_item_metadata(i)
		if typeof(metadata) != TYPE_VECTOR2I:
			continue
		if metadata == resolution:
			return i
	return 0


func _on_resolution_selected(index: int) -> void:
	if _syncing_ui:
		return
	var metadata: Variant = _resolution_option_button.get_item_metadata(index)
	if typeof(metadata) != TYPE_VECTOR2I:
		return
	AppSettings.set_resolution(metadata as Vector2i)


func _on_fullscreen_toggled(pressed: bool) -> void:
	if _syncing_ui:
		return
	AppSettings.set_fullscreen(pressed)


func _on_bgm_volume_changed(value: float) -> void:
	var rounded_value: int = int(roundi(value))
	_bgm_volume_label.text = "%d%%" % rounded_value
	if _syncing_ui:
		return
	var db: float = AppSettings.volume_linear_to_db(rounded_value / 100.0)
	AppSettings.set_bgm_volume_db(db)


func _on_bgm_mute_toggled(pressed: bool) -> void:
	if _syncing_ui:
		return
	AppSettings.set_bgm_muted(pressed)


func _on_sfx_volume_changed(value: float) -> void:
	var rounded_value: int = int(roundi(value))
	_sfx_volume_label.text = "%d%%" % rounded_value
	if _syncing_ui:
		return
	var db: float = AppSettings.volume_linear_to_db(rounded_value / 100.0)
	AppSettings.set_sfx_volume_db(db)


func _on_sfx_mute_toggled(pressed: bool) -> void:
	if _syncing_ui:
		return
	AppSettings.set_sfx_muted(pressed)
