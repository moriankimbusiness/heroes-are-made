extends Node

const SETTINGS_PATH := "user://settings.cfg"
const DISPLAY_SECTION := "display"
const AUDIO_SECTION := "audio"

const KEY_RESOLUTION_WIDTH := "resolution_width"
const KEY_RESOLUTION_HEIGHT := "resolution_height"
const KEY_FULLSCREEN := "fullscreen"
const KEY_BGM_VOLUME_DB := "bgm_volume_db"
const KEY_BGM_MUTED := "bgm_muted"
const KEY_SFX_VOLUME_DB := "sfx_volume_db"
const KEY_SFX_MUTED := "sfx_muted"

const MIN_VOLUME_DB := -80.0
const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080)
]

var _settings: Dictionary = {}


func _ready() -> void:
	load_settings()
	apply_all()


func get_settings() -> Dictionary:
	return _settings.duplicate(true)


func get_resolution_presets() -> Array[Vector2i]:
	return RESOLUTION_PRESETS.duplicate()


func volume_linear_to_db(linear: float) -> float:
	var safe_linear: float = clampf(linear, 0.0, 1.0)
	if safe_linear <= 0.0:
		return MIN_VOLUME_DB
	return maxf(MIN_VOLUME_DB, linear_to_db(safe_linear))


func volume_db_to_linear(volume_db: float) -> float:
	if volume_db <= MIN_VOLUME_DB:
		return 0.0
	return clampf(db_to_linear(volume_db), 0.0, 1.0)


func load_settings() -> Dictionary:
	_settings = _build_default_settings()
	var config := ConfigFile.new()
	var load_error: int = config.load(SETTINGS_PATH)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_warning("AppSettings: settings load failed (error=%d). Defaults will be used." % load_error)

	if load_error == OK:
		_settings[KEY_RESOLUTION_WIDTH] = int(config.get_value(DISPLAY_SECTION, KEY_RESOLUTION_WIDTH, _settings[KEY_RESOLUTION_WIDTH]))
		_settings[KEY_RESOLUTION_HEIGHT] = int(config.get_value(DISPLAY_SECTION, KEY_RESOLUTION_HEIGHT, _settings[KEY_RESOLUTION_HEIGHT]))
		_settings[KEY_FULLSCREEN] = bool(config.get_value(DISPLAY_SECTION, KEY_FULLSCREEN, _settings[KEY_FULLSCREEN]))
		_settings[KEY_BGM_VOLUME_DB] = float(config.get_value(AUDIO_SECTION, KEY_BGM_VOLUME_DB, _settings[KEY_BGM_VOLUME_DB]))
		_settings[KEY_BGM_MUTED] = bool(config.get_value(AUDIO_SECTION, KEY_BGM_MUTED, _settings[KEY_BGM_MUTED]))
		_settings[KEY_SFX_VOLUME_DB] = float(config.get_value(AUDIO_SECTION, KEY_SFX_VOLUME_DB, _settings[KEY_SFX_VOLUME_DB]))
		_settings[KEY_SFX_MUTED] = bool(config.get_value(AUDIO_SECTION, KEY_SFX_MUTED, _settings[KEY_SFX_MUTED]))

	_normalize_settings()

	if load_error != OK:
		save_settings()

	return get_settings()


func save_settings() -> int:
	var config := ConfigFile.new()
	config.set_value(DISPLAY_SECTION, KEY_RESOLUTION_WIDTH, int(_settings[KEY_RESOLUTION_WIDTH]))
	config.set_value(DISPLAY_SECTION, KEY_RESOLUTION_HEIGHT, int(_settings[KEY_RESOLUTION_HEIGHT]))
	config.set_value(DISPLAY_SECTION, KEY_FULLSCREEN, bool(_settings[KEY_FULLSCREEN]))
	config.set_value(AUDIO_SECTION, KEY_BGM_VOLUME_DB, float(_settings[KEY_BGM_VOLUME_DB]))
	config.set_value(AUDIO_SECTION, KEY_BGM_MUTED, bool(_settings[KEY_BGM_MUTED]))
	config.set_value(AUDIO_SECTION, KEY_SFX_VOLUME_DB, float(_settings[KEY_SFX_VOLUME_DB]))
	config.set_value(AUDIO_SECTION, KEY_SFX_MUTED, bool(_settings[KEY_SFX_MUTED]))

	var save_error: int = config.save(SETTINGS_PATH)
	if save_error != OK:
		push_warning("AppSettings: settings save failed (error=%d)." % save_error)
	return save_error


func apply_all() -> void:
	_apply_display_settings()
	_apply_audio_settings()


func set_resolution(resolution: Vector2i) -> void:
	var safe_resolution: Vector2i = _resolve_supported_resolution(resolution.x, resolution.y)
	_settings[KEY_RESOLUTION_WIDTH] = safe_resolution.x
	_settings[KEY_RESOLUTION_HEIGHT] = safe_resolution.y
	_apply_display_settings()
	save_settings()


func set_fullscreen(fullscreen: bool) -> void:
	_settings[KEY_FULLSCREEN] = fullscreen
	_apply_display_settings()
	save_settings()


func set_bgm_volume_db(volume_db: float) -> void:
	_settings[KEY_BGM_VOLUME_DB] = clampf(volume_db, MIN_VOLUME_DB, 6.0)
	_apply_audio_settings()
	save_settings()


func set_bgm_muted(muted: bool) -> void:
	_settings[KEY_BGM_MUTED] = muted
	_apply_audio_settings()
	save_settings()


func set_sfx_volume_db(volume_db: float) -> void:
	_settings[KEY_SFX_VOLUME_DB] = clampf(volume_db, MIN_VOLUME_DB, 6.0)
	_apply_audio_settings()
	save_settings()


func set_sfx_muted(muted: bool) -> void:
	_settings[KEY_SFX_MUTED] = muted
	_apply_audio_settings()
	save_settings()


func _build_default_settings() -> Dictionary:
	var default_resolution: Vector2i = RESOLUTION_PRESETS[0]
	return {
		KEY_RESOLUTION_WIDTH: default_resolution.x,
		KEY_RESOLUTION_HEIGHT: default_resolution.y,
		KEY_FULLSCREEN: false,
		KEY_BGM_VOLUME_DB: 0.0,
		KEY_BGM_MUTED: false,
		KEY_SFX_VOLUME_DB: 0.0,
		KEY_SFX_MUTED: false
	}


func _normalize_settings() -> void:
	var safe_resolution: Vector2i = _resolve_supported_resolution(
		int(_settings.get(KEY_RESOLUTION_WIDTH, RESOLUTION_PRESETS[0].x)),
		int(_settings.get(KEY_RESOLUTION_HEIGHT, RESOLUTION_PRESETS[0].y))
	)
	_settings[KEY_RESOLUTION_WIDTH] = safe_resolution.x
	_settings[KEY_RESOLUTION_HEIGHT] = safe_resolution.y
	_settings[KEY_FULLSCREEN] = bool(_settings.get(KEY_FULLSCREEN, false))
	_settings[KEY_BGM_VOLUME_DB] = clampf(float(_settings.get(KEY_BGM_VOLUME_DB, 0.0)), MIN_VOLUME_DB, 6.0)
	_settings[KEY_BGM_MUTED] = bool(_settings.get(KEY_BGM_MUTED, false))
	_settings[KEY_SFX_VOLUME_DB] = clampf(float(_settings.get(KEY_SFX_VOLUME_DB, 0.0)), MIN_VOLUME_DB, 6.0)
	_settings[KEY_SFX_MUTED] = bool(_settings.get(KEY_SFX_MUTED, false))


func _resolve_supported_resolution(width: int, height: int) -> Vector2i:
	var requested := Vector2i(width, height)
	for preset: Vector2i in RESOLUTION_PRESETS:
		if preset == requested:
			return preset

	var best_preset: Vector2i = RESOLUTION_PRESETS[0]
	var best_distance: int = abs(best_preset.x - requested.x) + abs(best_preset.y - requested.y)
	for i: int in range(1, RESOLUTION_PRESETS.size()):
		var current: Vector2i = RESOLUTION_PRESETS[i]
		var distance: int = abs(current.x - requested.x) + abs(current.y - requested.y)
		if distance < best_distance:
			best_distance = distance
			best_preset = current
	return best_preset


func _apply_display_settings() -> void:
	var resolution := Vector2i(
		int(_settings[KEY_RESOLUTION_WIDTH]),
		int(_settings[KEY_RESOLUTION_HEIGHT])
	)
	DisplayServer.window_set_size(resolution)

	var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if bool(_settings[KEY_FULLSCREEN]) else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func _apply_audio_settings() -> void:
	_apply_audio_bus_settings("BGM", float(_settings[KEY_BGM_VOLUME_DB]), bool(_settings[KEY_BGM_MUTED]))
	_apply_audio_bus_settings("SFX", float(_settings[KEY_SFX_VOLUME_DB]), bool(_settings[KEY_SFX_MUTED]))


func _apply_audio_bus_settings(bus_name: StringName, volume_db: float, muted: bool) -> void:
	var bus_index: int = _ensure_audio_bus(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_volume_db(bus_index, volume_db)
	AudioServer.set_bus_mute(bus_index, muted)


func _ensure_audio_bus(bus_name: StringName) -> int:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		return bus_index

	var insert_index: int = AudioServer.get_bus_count()
	AudioServer.add_bus(insert_index)
	AudioServer.set_bus_name(insert_index, bus_name)
	AudioServer.set_bus_send(insert_index, "Master")
	return insert_index
