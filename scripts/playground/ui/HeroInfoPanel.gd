extends PanelContainer

## 선택된 히어로의 초상화, 체력, 스탯, 장비를 표시하는 패널입니다.

const ItemEnumsRef = preload("res://scripts/items/ItemEnums.gd")

@export_group("HeroInfoPanel 표시 설정")
## 히어로 초상화 표시 배율입니다.
@export_range(1.0, 4.0, 0.1) var portrait_scale: float = 2.0

@onready var hero_name_label: Label = $MarginContainer/MainRow/PortraitColumn/NameLabel
@onready var portrait_sprite: AnimatedSprite2D = $MarginContainer/MainRow/PortraitColumn/PortraitFrame/PortraitCenter/PortraitSprite
@onready var hero_health_bar: ProgressBar = $MarginContainer/MainRow/PortraitColumn/HeroHealthStatus/HeroHealthBar
@onready var hero_health_label: Label = $MarginContainer/MainRow/PortraitColumn/HeroHealthStatus/HeroHealthLabel

@onready var weapon_slot: ItemSlotUI = $MarginContainer/MainRow/EquipColumn/EquipSlots/WeaponSlot
@onready var armor_slot: ItemSlotUI = $MarginContainer/MainRow/EquipColumn/EquipSlots/ArmorSlot
@onready var boots_slot: ItemSlotUI = $MarginContainer/MainRow/EquipColumn/EquipSlots/BootsSlot

@onready var level_label: Label = $MarginContainer/MainRow/StatColumn/LevelRow/LevelLabel
@onready var exp_bar: TextureProgressBar = $MarginContainer/MainRow/StatColumn/LevelRow/ExpBar
@onready var exp_label: Label = $MarginContainer/MainRow/StatColumn/LevelRow/ExpLabel
@onready var strength_label: Label = $MarginContainer/MainRow/StatColumn/StrengthLabel
@onready var agility_label: Label = $MarginContainer/MainRow/StatColumn/AgilityLabel
@onready var intelligence_label: Label = $MarginContainer/MainRow/StatColumn/IntelligenceLabel
@onready var range_label: Label = $MarginContainer/MainRow/StatColumn/RangeLabel

var _bound_hero: Hero = null
var _portrait_source_anim: AnimatedSprite2D = null
var _equipment_slots: Dictionary = {}
var _item_tooltip: Node = null


func _ready() -> void:
	_equipment_slots = {
		ItemEnumsRef.EquipSlot.WEAPON: weapon_slot,
		ItemEnumsRef.EquipSlot.ARMOR: armor_slot,
		ItemEnumsRef.EquipSlot.BOOTS: boots_slot
	}
	portrait_sprite.scale = Vector2.ONE * portrait_scale
	_connect_slot_tooltip_signals()
	_clear_display()


func _connect_slot_tooltip_signals() -> void:
	for slot: int in _equipment_slots.keys():
		var slot_ui: ItemSlotUI = _equipment_slots[slot]
		slot_ui.slot_hover_started.connect(_on_slot_hover_started.bind(slot_ui))
		slot_ui.slot_hover_ended.connect(_on_slot_hover_ended)


func _find_item_tooltip() -> Node:
	if _item_tooltip != null and is_instance_valid(_item_tooltip):
		return _item_tooltip
	var hud: Node = get_parent().get_parent()
	if hud == null:
		return null
	var tooltip_layer: Node = hud.get_node_or_null("TooltipLayer")
	if tooltip_layer == null:
		return null
	_item_tooltip = tooltip_layer.get_node_or_null("ItemTooltip")
	return _item_tooltip


func _on_slot_hover_started(_slot_kind: String, _slot_index: int, slot_ui: ItemSlotUI) -> void:
	var tooltip: Node = _find_item_tooltip()
	if tooltip == null:
		return
	if slot_ui.item == null:
		return
	var global_pos: Vector2 = slot_ui.get_global_rect().position
	tooltip.call("show_item", slot_ui.item, global_pos)


func _on_slot_hover_ended(_slot_kind: String, _slot_index: int) -> void:
	var tooltip: Node = _find_item_tooltip()
	if tooltip == null:
		return
	tooltip.call("hide_tooltip")


func bind_hero(hero: Hero) -> void:
	if hero == _bound_hero:
		return
	unbind_hero()
	if hero == null:
		return
	if not is_instance_valid(hero):
		return
	_bound_hero = hero
	hero.hero_moved.connect(_on_hero_moved)
	hero.hero_stats_changed.connect(_on_hero_stats_changed)
	hero.health_changed.connect(_on_hero_health_changed)
	hero.equipment_changed.connect(_on_hero_equipment_changed)
	if hero.has_signal("progression_changed"):
		hero.progression_changed.connect(_on_hero_progression_changed)
	_bind_portrait_source(hero)
	_refresh_all()
	_update_dead_visual()


func unbind_hero() -> void:
	if _bound_hero != null and is_instance_valid(_bound_hero):
		if _bound_hero.hero_moved.is_connected(_on_hero_moved):
			_bound_hero.hero_moved.disconnect(_on_hero_moved)
		if _bound_hero.hero_stats_changed.is_connected(_on_hero_stats_changed):
			_bound_hero.hero_stats_changed.disconnect(_on_hero_stats_changed)
		if _bound_hero.health_changed.is_connected(_on_hero_health_changed):
			_bound_hero.health_changed.disconnect(_on_hero_health_changed)
		if _bound_hero.equipment_changed.is_connected(_on_hero_equipment_changed):
			_bound_hero.equipment_changed.disconnect(_on_hero_equipment_changed)
		if _bound_hero.has_signal("progression_changed"):
			if _bound_hero.progression_changed.is_connected(_on_hero_progression_changed):
				_bound_hero.progression_changed.disconnect(_on_hero_progression_changed)
	_unbind_portrait_source()
	_bound_hero = null
	modulate = Color.WHITE
	_clear_display()


# -- Signal callbacks ----------------------------------------------------------

func _on_hero_moved(hero: Hero, _world_position: Vector2) -> void:
	if hero != _bound_hero:
		return
	_sync_portrait_from_source()


func _on_hero_stats_changed(hero: Hero, _stats: HeroStats) -> void:
	if hero != _bound_hero:
		return
	_refresh_stat_labels()


func _on_hero_health_changed(hero: Hero, _current: float, _max_value: float, _ratio: float) -> void:
	if hero != _bound_hero:
		return
	_refresh_hero_health_status()
	_update_dead_visual()


func _on_hero_progression_changed(hero: Hero, _level: int, _current_exp: int, _required_exp: int) -> void:
	if hero != _bound_hero:
		return
	_refresh_progression_labels()


func _on_hero_equipment_changed(hero: Hero, _slot: int, _item: ItemData) -> void:
	if hero != _bound_hero:
		return
	_refresh_equipment_slots()
	_refresh_stat_labels()


# -- Portrait mirroring --------------------------------------------------------

func _bind_portrait_source(hero: Hero) -> void:
	_unbind_portrait_source()
	if hero == null:
		return
	var source: AnimatedSprite2D = hero.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if source == null:
		return
	_portrait_source_anim = source
	if not _portrait_source_anim.frame_changed.is_connected(_on_portrait_source_frame_changed):
		_portrait_source_anim.frame_changed.connect(_on_portrait_source_frame_changed)
	if not _portrait_source_anim.animation_changed.is_connected(_on_portrait_source_animation_changed):
		_portrait_source_anim.animation_changed.connect(_on_portrait_source_animation_changed)
	_sync_portrait_from_source()


func _unbind_portrait_source() -> void:
	if _portrait_source_anim != null and is_instance_valid(_portrait_source_anim):
		if _portrait_source_anim.frame_changed.is_connected(_on_portrait_source_frame_changed):
			_portrait_source_anim.frame_changed.disconnect(_on_portrait_source_frame_changed)
		if _portrait_source_anim.animation_changed.is_connected(_on_portrait_source_animation_changed):
			_portrait_source_anim.animation_changed.disconnect(_on_portrait_source_animation_changed)
	_portrait_source_anim = null
	portrait_sprite.stop()
	portrait_sprite.sprite_frames = null


func _on_portrait_source_frame_changed() -> void:
	_sync_portrait_from_source()


func _on_portrait_source_animation_changed() -> void:
	_sync_portrait_from_source()


func _sync_portrait_from_source() -> void:
	if _portrait_source_anim == null:
		return
	if not is_instance_valid(_portrait_source_anim):
		return
	portrait_sprite.scale = Vector2.ONE * portrait_scale
	portrait_sprite.sprite_frames = _portrait_source_anim.sprite_frames
	if portrait_sprite.sprite_frames == null:
		portrait_sprite.stop()
		return
	if not portrait_sprite.sprite_frames.has_animation(_portrait_source_anim.animation):
		portrait_sprite.stop()
		return
	if portrait_sprite.animation != _portrait_source_anim.animation:
		portrait_sprite.animation = _portrait_source_anim.animation
	if _portrait_source_anim.is_playing():
		if not portrait_sprite.is_playing():
			portrait_sprite.play(portrait_sprite.animation)
	else:
		portrait_sprite.stop()
	portrait_sprite.frame = _portrait_source_anim.frame
	portrait_sprite.flip_h = _portrait_source_anim.flip_h
	portrait_sprite.speed_scale = _portrait_source_anim.speed_scale


# -- Refresh functions ---------------------------------------------------------

func _refresh_all() -> void:
	_refresh_hero_header()
	_refresh_hero_health_status()
	_refresh_progression_labels()
	_refresh_stat_labels()
	_refresh_equipment_slots()


func _update_dead_visual() -> void:
	if _bound_hero == null or not is_instance_valid(_bound_hero):
		modulate = Color.WHITE
		return
	if _bound_hero.has_method("is_dead") and bool(_bound_hero.call("is_dead")):
		modulate = Color(0.5, 0.5, 0.5, 0.7)
	else:
		modulate = Color.WHITE


func _clear_display() -> void:
	hero_name_label.text = "히어로 미선택"
	hero_health_bar.max_value = 1.0
	hero_health_bar.value = 0.0
	hero_health_label.text = "-/-"
	level_label.text = "Level -"
	exp_bar.max_value = 1
	exp_bar.value = 0
	exp_label.text = "0/0"
	strength_label.text = "힘: -"
	agility_label.text = "민첩: -"
	intelligence_label.text = "지능: -"
	range_label.text = "사거리: -"
	for slot: int in _equipment_slots.keys():
		_equipment_slots[slot].set_item(null)


func _refresh_hero_header() -> void:
	if _bound_hero == null or not is_instance_valid(_bound_hero):
		hero_name_label.text = "히어로 미선택"
		return
	hero_name_label.text = _bound_hero.get_display_name()
	_sync_portrait_from_source()


func _refresh_hero_health_status() -> void:
	if _bound_hero == null or not is_instance_valid(_bound_hero):
		hero_health_bar.max_value = 1.0
		hero_health_bar.value = 0.0
		hero_health_label.text = "-/-"
		return
	var current: float = _bound_hero.get_current_health()
	var max_value: float = _bound_hero.get_max_health()
	var clamped_max: float = maxf(1.0, max_value)
	var clamped_current: float = clampf(current, 0.0, clamped_max)
	hero_health_bar.max_value = clamped_max
	hero_health_bar.value = clamped_current
	hero_health_label.text = "%d/%d" % [roundi(clamped_current), roundi(clamped_max)]


func _refresh_progression_labels() -> void:
	if _bound_hero == null or not is_instance_valid(_bound_hero):
		level_label.text = "Level -"
		exp_bar.max_value = 1
		exp_bar.value = 0
		exp_label.text = "0/0"
		return
	var level_value: int = _bound_hero.get_level()
	var current_exp: int = _bound_hero.get_current_exp()
	var required_exp: int = _bound_hero.get_required_exp()
	level_label.text = "Level %d" % level_value
	exp_bar.max_value = maxi(1, required_exp)
	exp_bar.value = clampi(current_exp, 0, required_exp)
	exp_label.text = "%d/%d" % [current_exp, required_exp]


func _refresh_stat_labels() -> void:
	if _bound_hero == null or not is_instance_valid(_bound_hero):
		strength_label.text = "힘: -"
		agility_label.text = "민첩: -"
		intelligence_label.text = "지능: -"
		range_label.text = "사거리: -"
		return
	var stats: HeroStats = _bound_hero.get_current_stats()
	var str_bonus: int = stats.strength - _bound_hero.base_strength
	var agi_bonus: int = stats.agility - _bound_hero.base_agility
	var int_bonus: int = stats.intelligence - _bound_hero.base_intelligence
	var tile_span: int = _bound_hero.get_attack_range_tile_span()

	strength_label.text = _format_stat_line_int("힘", stats.strength, str_bonus)
	agility_label.text = _format_stat_line_int("민첩", stats.agility, agi_bonus)
	intelligence_label.text = _format_stat_line_int("지능", stats.intelligence, int_bonus)
	range_label.text = "사거리: %dx%d 타일" % [tile_span, tile_span]


func _refresh_equipment_slots() -> void:
	for slot: int in _equipment_slots.keys():
		var slot_node: ItemSlotUI = _equipment_slots[slot]
		if _bound_hero == null or not is_instance_valid(_bound_hero):
			slot_node.set_item(null)
			continue
		slot_node.set_item(_bound_hero.get_equipment_item(slot))


# -- Stat formatting helpers ---------------------------------------------------

func _format_stat_line_int(label: String, total_value: int, bonus_value: int) -> String:
	if bonus_value == 0:
		return "%s: %d" % [label, total_value]
	return "%s: %d(%s)" % [label, total_value, _format_signed_bonus(bonus_value)]


func _format_stat_line_float(label: String, total_value: float, bonus_value: float) -> String:
	if absf(bonus_value) <= 0.05:
		return "%s: %.1f" % [label, total_value]
	return "%s: %.1f(%s)" % [label, total_value, _format_signed_bonus_float(bonus_value)]


func _format_signed_bonus(value: int) -> String:
	if value > 0:
		return "%d▲" % value
	if value < 0:
		return "%d▼" % absi(value)
	return "0"


func _format_signed_bonus_float(value: float) -> String:
	if value > 0.05:
		return "%.1f▲" % value
	if value < -0.05:
		return "%.1f▼" % absf(value)
	return "0"


# -- Stat preview (shop card hover) -------------------------------------------

var _preview_active: bool = false


func show_stat_preview(_slot: int, item: ItemData) -> void:
	if _bound_hero == null or not is_instance_valid(_bound_hero):
		return
	if item == null:
		return
	_preview_active = true
	var stats: HeroStats = _bound_hero.get_current_stats()
	var new_str: int = stats.strength + item.strength_bonus
	var new_agi: int = stats.agility + item.agility_bonus
	var new_int: int = stats.intelligence + item.intelligence_bonus

	strength_label.text = _format_preview_line("힘", stats.strength, new_str)
	agility_label.text = _format_preview_line("민첩", stats.agility, new_agi)
	intelligence_label.text = _format_preview_line("지능", stats.intelligence, new_int)


func clear_stat_preview() -> void:
	if not _preview_active:
		return
	_preview_active = false
	_refresh_stat_labels()


func _format_preview_line(label: String, current: int, preview: int) -> String:
	var diff: int = preview - current
	if diff == 0:
		return "%s: %d" % [label, current]
	if diff > 0:
		return "%s: %d → %d(%d▲)" % [label, current, preview, diff]
	return "%s: %d → %d(%d▼)" % [label, current, preview, absi(diff)]
