extends PanelContainer

## 아이템 슬롯 호버 시 아이템 정보를 표시하는 팝업 툴팁입니다.

const TIER_COLORS: Dictionary = {
	0: Color(0.65, 0.65, 0.65, 1.0),  # COMMON - 회색
	1: Color(0.3, 0.85, 0.4, 1.0),    # UNCOMMON - 녹색
	2: Color(0.3, 0.5, 1.0, 1.0),     # RARE - 파랑
	3: Color(0.7, 0.3, 1.0, 1.0),     # EPIC - 보라
	4: Color(1.0, 0.85, 0.3, 1.0),    # LEGENDARY - 금색
}

const TIER_NAMES: Dictionary = {
	0: "일반",
	1: "고급",
	2: "희귀",
	3: "영웅",
	4: "전설",
}

@onready var item_name_label: Label = $MarginContainer/VBoxContainer/ItemNameLabel
@onready var tier_label: Label = $MarginContainer/VBoxContainer/TierLabel
@onready var stats_label: Label = $MarginContainer/VBoxContainer/StatsLabel
@onready var enhance_label: Label = $MarginContainer/VBoxContainer/EnhanceLabel


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_item(item: ItemData, global_pos: Vector2) -> void:
	if item == null:
		hide_tooltip()
		return

	item_name_label.text = item.display_name if not item.display_name.is_empty() else String(item.item_id)
	var tier_color: Color = TIER_COLORS.get(item.tier, Color.WHITE)
	item_name_label.add_theme_color_override("font_color", tier_color)

	tier_label.text = TIER_NAMES.get(item.tier, "일반")
	tier_label.add_theme_color_override("font_color", tier_color)

	var stat_lines: PackedStringArray = PackedStringArray()
	if item.strength_bonus != 0:
		stat_lines.append("힘: %+d" % item.strength_bonus)
	if item.agility_bonus != 0:
		stat_lines.append("민첩: %+d" % item.agility_bonus)
	if item.intelligence_bonus != 0:
		stat_lines.append("지능: %+d" % item.intelligence_bonus)
	if not is_zero_approx(item.physical_attack_bonus):
		stat_lines.append("물리 공격: %+.1f" % item.physical_attack_bonus)
	if not is_zero_approx(item.magic_attack_bonus):
		stat_lines.append("마법 공격: %+.1f" % item.magic_attack_bonus)
	stats_label.text = "\n".join(stat_lines) if not stat_lines.is_empty() else "보너스 없음"

	if item.enhance_level > 0:
		enhance_label.text = "강화: +%d" % item.enhance_level
		enhance_label.visible = true
	else:
		enhance_label.visible = false

	visible = true
	await get_tree().process_frame
	_position_tooltip(global_pos)


func hide_tooltip() -> void:
	visible = false


func _position_tooltip(anchor_pos: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var tooltip_size: Vector2 = size
	var pos := anchor_pos + Vector2(8, -tooltip_size.y - 8)
	if pos.y < 0:
		pos.y = anchor_pos.y + 8
	if pos.x + tooltip_size.x > viewport_size.x:
		pos.x = viewport_size.x - tooltip_size.x - 4
	if pos.x < 0:
		pos.x = 4
	global_position = pos
