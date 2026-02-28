extends Area2D
class_name Hero

const EquipmentStateRef = preload("res://scripts/items/EquipmentState.gd")
const ItemEnumsRef = preload("res://scripts/items/ItemEnums.gd")

signal hero_clicked(hero: Hero)
signal hero_moved(hero: Hero, world_position: Vector2)
signal hero_stats_changed(hero: Hero, stats: HeroStats)
signal equipment_changed(hero: Hero, slot: int, item: ItemData)
signal health_changed(hero: Hero, current: float, max_value: float, ratio: float)
signal progression_changed(hero: Hero, level: int, current_exp: int, required_exp: int)
signal died(hero: Hero)

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var drag_shape: CollisionShape2D = $DragShape
@onready var attack_timer: Timer = $AttackTimer
@onready var status_anchor: Marker2D = $StatusAnchor
@onready var _animator: Node = $HeroAnimator
@onready var _visual: Node = $HeroVisualController
@onready var _attack_ctrl: Node = $HeroAttackController

enum State {
	IDLE,
	WALK,
	ATTACK01,
	DEATH
}

enum TargetPriority {
	PATH_PROGRESS,
	LOWEST_HEALTH,
	NEAREST
}

enum HeroClass {
	WARRIOR,
	ARCHER,
	MAGE,
	ASSASSIN
}

@export_group("공격 기본값")
## 자동 공격 동작 활성화 여부입니다.
@export var attack_enabled: bool = true
## 기본 1회 공격 피해량입니다.
@export_range(0.1, 9999.0, 0.1) var attack_damage: float = 10.0
## 초당 공격 횟수(APS)입니다.
@export_range(0.1, 20.0, 0.1) var attacks_per_second: float = 1.2
## 공격 대상 우선순위 규칙입니다.
@export var target_priority: TargetPriority = TargetPriority.PATH_PROGRESS
## 공격 애니메이션에서 실제 타격이 발생하는 프레임 인덱스입니다.
@export_range(0, 99, 1) var attack_hit_frame_index: int = 2
## 공격 방향 반전 시 무시할 X축 데드존입니다.
@export_range(0.0, 20.0, 0.1) var attack_flip_deadzone: float = 0.1

@export_group("타일 전투 설정")
## 히어로 클래스 타입입니다.
@export var hero_class: HeroClass = HeroClass.WARRIOR
## 전사 기본 공격 범위(타일)입니다.
@export_range(1, 15, 1) var warrior_attack_tile_span: int = 4
## 궁수 기본 공격 범위(타일)입니다.
@export_range(1, 15, 1) var archer_attack_tile_span: int = 5
## 마법사 기본 공격 범위(타일)입니다.
@export_range(1, 15, 1) var mage_attack_tile_span: int = 5
## 암살자 기본 공격 범위(타일)입니다.
@export_range(1, 15, 1) var assassin_attack_tile_span: int = 3

@export_group("이동")
## 이동 속도(px/s)입니다.
@export_range(1.0, 500.0, 1.0) var move_speed: float = 160.0
## 이동 목표 도착으로 간주하는 거리(px)입니다.
@export_range(0.1, 64.0, 0.1) var move_stop_distance: float = 6.0

@export_group("기본 스탯")
## 기본 힘 스탯입니다.
@export_range(-999, 999, 1) var base_strength: int = 2
## 기본 민첩 스탯입니다.
@export_range(-999, 999, 1) var base_agility: int = 2
## 기본 지능 스탯입니다.
@export_range(-999, 999, 1) var base_intelligence: int = 1
## 기본 물리 공격력입니다.
@export_range(0.1, 9999.0, 0.1) var base_physical_attack: float = 10.0
## 기본 마법 공격력입니다.
@export_range(0.0, 9999.0, 0.1) var base_magic_attack: float = 5.0
## 기본 최대 체력 값입니다.
@export_range(1.0, 9999.0, 1.0) var base_max_health: float = 100.0
## 기본 초당 공격 횟수(APS)입니다.
@export_range(0.1, 20.0, 0.1) var base_attacks_per_second: float = 1.2

@export_group("성장/레벨")
## UI에 표시할 히어로 이름입니다.
@export var hero_display_name: String = "용사"
## 현재 레벨입니다.
@export_range(1, 99, 1) var level: int = 1
## 현재 누적 경험치입니다.
@export_range(0, 999999, 1) var current_exp: int = 0
## 다음 레벨에 필요한 경험치입니다.
@export_range(1, 999999, 1) var required_exp: int = 60
## 민첩 1당 공격속도 가산 계수입니다.
@export_range(0.0, 3.0, 0.01) var agility_attack_speed_factor: float = 0.03

@export_group("피격/선택 비주얼")
## 피격 플래시 지속 시간(초)입니다.
@export_range(0.01, 2.0, 0.01) var damage_flash_duration: float = 0.14
## 마우스 호버 시 외곽선 색상입니다.
@export var hover_outline_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## 피격 시 외곽선 색상입니다.
@export var damage_outline_color: Color = Color(1.0, 0.2, 0.2, 1.0)
## 피격 시 내부 플래시 채움 색상입니다.
@export var damage_fill_color: Color = Color(1.0, 0.2, 0.2, 0.55)
## 선택 상태 외곽선 색상입니다.
@export var selected_outline_color: Color = Color(0.3, 1.0, 0.4, 1.0)
## 선택 상태 내부 채움 색상입니다.
@export var selected_fill_color: Color = Color(0.3, 1.0, 0.4, 0.35)
## 선택 상태 채움 강도(0~1)입니다.
@export_range(0.0, 1.0, 0.01) var selected_fill_strength: float = 1.0

@export_group("강화 계수 테이블")
## 강화 단계별 공격 배율 테이블입니다.
@export var enhance_attack_multipliers: Array[float] = [
	1.0, 1.12, 1.26, 1.42, 1.60, 1.80, 2.02, 2.26,
	2.52, 2.80, 3.10, 3.42, 3.76, 4.12, 4.50, 4.90
]
## 강화 단계별 스탯 배율 테이블입니다.
@export var enhance_stat_multipliers: Array[float] = [
	1.0, 1.05, 1.10, 1.16, 1.22, 1.29, 1.36, 1.44,
	1.52, 1.61, 1.70, 1.80, 1.91, 2.02, 2.14, 2.26
]

var state: State = State.IDLE
var _is_dead: bool = false
var _move_order_active: bool = false
var _move_order_target: Vector2 = Vector2.ZERO
var _move_path_points: Array[Vector2] = []
var _move_path_index: int = 0
var _show_attack_range_preview: bool = false
var _attack01_base_duration_seconds: float = 0.5
var _warned_missing_walk_animation: bool = false
var playground: Node2D = null
var _stats: HeroStats = HeroStats.new()
var _equipment: EquipmentState = null
var max_health: float = 100.0
var current_health: float = 100.0
var _attack_origin_cell: Vector2i = Vector2i.ZERO
var _attack_origin_cell_initialized: bool = false


func _ready() -> void:
	_animator.configure(anim)
	_visual.configure(self, anim)
	_attack_ctrl.configure(self, attack_timer, _animator)

	_animator.non_loop_finished.connect(_on_animator_non_loop_finished)
	_attack_ctrl.attack_requested.connect(_on_attack_requested)

	set_max_health(base_max_health)
	_setup_equipment_system()
	_attack01_base_duration_seconds = _animator.get_base_duration(&"attack01")
	update_attack_origin_cell()
	set_physics_process(false)
	_play_state(State.IDLE, true)
	_emit_progression_changed()
	if attack_enabled:
		call_deferred("_deferred_start_attack")


func _deferred_start_attack() -> void:
	_attack_ctrl.attempt_auto_attack()


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is not InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	hero_clicked.emit(self)
	if not _visual.is_damage_flash_active():
		_visual.apply_idle_outline()
	queue_redraw()
	get_viewport().set_input_as_handled()


# -- Movement ------------------------------------------------------------------

func issue_move_command(world_target: Vector2) -> bool:
	if _is_dead:
		return false

	var path_points: Array[Vector2] = []
	if playground != null and playground.has_method("build_world_path_to_target"):
		var built_path = playground.call("build_world_path_to_target", global_position, world_target)
		for point_variant in built_path:
			path_points.append(Vector2(point_variant))
	else:
		path_points.append(world_target)

	if path_points.is_empty():
		return false

	_move_path_points.clear()
	for point: Vector2 in path_points:
		if _move_path_points.is_empty() and global_position.distance_to(point) <= move_stop_distance:
			continue
		_move_path_points.append(point)
	if _move_path_points.is_empty():
		return false

	_move_path_index = 0
	_move_order_target = _move_path_points[_move_path_points.size() - 1]
	_attack_ctrl.clear_pending()
	_attack_ctrl.stop()

	_move_order_active = true
	set_physics_process(true)
	_play_state(State.WALK, true)
	queue_redraw()
	return true


func get_move_order_target() -> Vector2:
	return _move_order_target


func is_move_order_active() -> bool:
	return _move_order_active


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	if not _move_order_active:
		set_physics_process(false)
		return
	_step_move_order(delta)


func _step_move_order(delta: float) -> void:
	if move_speed <= 0.0:
		_stop_move_order(true)
		return

	while _move_path_index < _move_path_points.size() and global_position.distance_to(_move_path_points[_move_path_index]) <= move_stop_distance:
		_move_path_index += 1

	if _move_path_index >= _move_path_points.size():
		_stop_move_order(true)
		return

	var waypoint: Vector2 = _move_path_points[_move_path_index]
	var to_waypoint: Vector2 = waypoint - global_position
	var remaining: float = to_waypoint.length()
	if remaining <= move_stop_distance:
		_move_path_index += 1
		if _move_path_index >= _move_path_points.size():
			_stop_move_order(true)
		return

	var max_step: float = move_speed * delta
	if max_step <= 0.0:
		return
	var next_position: Vector2 = global_position + to_waypoint.normalized() * minf(max_step, remaining)
	var move_vector: Vector2 = next_position - global_position
	if move_vector.length_squared() <= 0.0001:
		_stop_move_order(true)
		return

	global_position = next_position
	update_attack_origin_cell()
	_update_walk_facing(move_vector)
	hero_moved.emit(self, global_position)

	if global_position.distance_to(_move_order_target) <= move_stop_distance:
		_stop_move_order(true)


func _stop_move_order(play_idle: bool) -> void:
	_move_order_active = false
	_move_path_points.clear()
	_move_path_index = 0
	set_physics_process(false)
	if _is_dead:
		return
	if play_idle:
		_play_state(State.IDLE, true)
	if attack_enabled and attack_timer != null and attack_timer.is_stopped():
		_attack_ctrl.attempt_auto_attack()


func _update_walk_facing(move: Vector2) -> void:
	if move.x > attack_flip_deadzone:
		_animator.set_flip_h(false)
	elif move.x < -attack_flip_deadzone:
		_animator.set_flip_h(true)


# -- Equipment / Stats ---------------------------------------------------------

func _setup_equipment_system() -> void:
	_equipment = EquipmentStateRef.new()
	_equipment.changed.connect(_on_equipment_state_changed)
	_recalculate_stats()


func get_current_stats() -> HeroStats:
	return _stats.duplicate_state()


func get_display_name() -> String:
	if not hero_display_name.is_empty():
		return hero_display_name
	return String(name)


func get_hero_class_name() -> String:
	match hero_class:
		HeroClass.WARRIOR:
			return "전사"
		HeroClass.ARCHER:
			return "궁수"
		HeroClass.MAGE:
			return "마법사"
		HeroClass.ASSASSIN:
			return "암살자"
	return "전사"


func get_hero_class_id() -> int:
	return int(hero_class)


func get_level() -> int:
	return level


func get_current_exp() -> int:
	return current_exp


func get_required_exp() -> int:
	return required_exp


func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	current_exp += amount
	while current_exp >= required_exp:
		current_exp -= required_exp
		level += 1
		required_exp = maxi(1, required_exp + 20)
	_emit_progression_changed()


func get_status_anchor_canvas_position() -> Vector2:
	if status_anchor != null:
		return status_anchor.get_global_transform_with_canvas().origin
	return get_global_transform_with_canvas().origin


func get_equipment_item(slot: int) -> ItemData:
	if _equipment == null:
		return null
	return _equipment.get_item(slot)


func can_equip_item(slot: int, item: ItemData) -> bool:
	if _equipment == null:
		return false
	if item == null:
		return false
	return ItemEnumsRef.default_slot_for_item(item.item_type) == slot


func equip_item(slot: int, item: ItemData) -> bool:
	if not can_equip_item(slot, item):
		return false
	_equipment.set_item(slot, item)
	return true


func unequip_item(slot: int) -> ItemData:
	if _equipment == null:
		return null
	var equipped_item: ItemData = _equipment.get_item(slot)
	if equipped_item == null:
		return null
	_equipment.set_item(slot, null)
	return equipped_item


func _on_equipment_state_changed(slot: int, item: ItemData) -> void:
	_recalculate_stats()
	equipment_changed.emit(self, slot, item)


func _recalculate_stats() -> void:
	var total_strength: int = base_strength
	var total_agility: int = base_agility
	var total_intelligence: int = base_intelligence
	var total_physical_bonus: float = 0.0
	var total_magic_bonus: float = 0.0
	for slot: int in ItemEnumsRef.all_equip_slots():
		var item: ItemData = _equipment.get_item(slot) if _equipment != null else null
		if item == null:
			continue
		var stat_multiplier: float = _get_enhance_stat_multiplier(item.enhance_level)
		total_strength += int(roundi(float(item.strength_bonus) * stat_multiplier))
		total_agility += int(roundi(float(item.agility_bonus) * stat_multiplier))
		total_intelligence += int(roundi(float(item.intelligence_bonus) * stat_multiplier))
		var attack_multiplier: float = _get_enhance_attack_multiplier(item.enhance_level)
		total_physical_bonus += item.physical_attack_bonus * attack_multiplier
		total_magic_bonus += item.magic_attack_bonus * attack_multiplier

	_stats.strength = total_strength
	_stats.agility = total_agility
	_stats.intelligence = total_intelligence
	_stats.physical_attack = base_physical_attack + float(total_strength) + total_physical_bonus
	_stats.magic_attack = base_magic_attack + float(total_intelligence) + total_magic_bonus
	_stats.attacks_per_second = maxf(0.1, base_attacks_per_second * (1.0 + float(total_agility) * agility_attack_speed_factor))

	attack_damage = maxf(0.1, _stats.physical_attack)
	attacks_per_second = _stats.attacks_per_second
	if state == State.ATTACK01:
		_apply_attack_anim_speed()
	queue_redraw()
	hero_stats_changed.emit(self, _stats.duplicate_state())


# -- Tile / Range --------------------------------------------------------------

func get_attack_range_tile_span() -> int:
	return _normalize_tile_span(_get_base_tile_span_for_class())


func get_attack_range_tile_radius() -> int:
	return get_attack_range_tile_span() / 2


func get_max_enhance_level() -> int:
	return _get_max_enhance_level()


func get_enhance_attack_multiplier(level: int) -> float:
	return _get_enhance_attack_multiplier(level)


func get_enhance_stat_multiplier(level: int) -> float:
	return _get_enhance_stat_multiplier(level)


func _get_max_enhance_level() -> int:
	return ItemData.MAX_ENHANCE_LEVEL


func _get_enhance_attack_multiplier(level: int) -> float:
	var clamped_level: int = clampi(level, 0, _get_max_enhance_level())
	if clamped_level <= 0:
		return 1.0
	if enhance_attack_multipliers.is_empty():
		return 1.0 + float(clamped_level) * 0.12
	var index: int = clampi(clamped_level, 0, enhance_attack_multipliers.size() - 1)
	return enhance_attack_multipliers[index]


func _get_enhance_stat_multiplier(level: int) -> float:
	var clamped_level: int = clampi(level, 0, _get_max_enhance_level())
	if clamped_level <= 0:
		return 1.0
	if enhance_stat_multipliers.is_empty():
		return 1.0 + float(clamped_level) * 0.05
	var index: int = clampi(clamped_level, 0, enhance_stat_multipliers.size() - 1)
	return enhance_stat_multipliers[index]


func _get_base_tile_span_for_class() -> int:
	match hero_class:
		HeroClass.WARRIOR:
			return warrior_attack_tile_span
		HeroClass.ARCHER:
			return archer_attack_tile_span
		HeroClass.MAGE:
			return mage_attack_tile_span
		HeroClass.ASSASSIN:
			return assassin_attack_tile_span
	return warrior_attack_tile_span


func _normalize_tile_span(value: int) -> int:
	var span: int = maxi(1, value)
	if span % 2 == 0:
		span += 1
	return span


func get_attack_origin_cell() -> Vector2i:
	if not _attack_origin_cell_initialized:
		update_attack_origin_cell()
	return _attack_origin_cell


func update_attack_origin_cell() -> void:
	var next_cell: Vector2i = world_to_cell(global_position)
	if _attack_origin_cell_initialized and next_cell == _attack_origin_cell:
		return
	_attack_origin_cell = next_cell
	_attack_origin_cell_initialized = true
	if _show_attack_range_preview:
		_update_attack_range_overlay()


func world_to_cell(world_pos: Vector2) -> Vector2i:
	if playground != null and playground.has_method("world_to_cell"):
		return Vector2i(playground.call("world_to_cell", world_pos))
	var tile_size: int = _get_tile_size_px()
	return Vector2i(floori(world_pos.x / float(tile_size)), floori(world_pos.y / float(tile_size)))


func _get_tile_size_px() -> int:
	if playground != null and playground.has_method("get_tile_size_px"):
		return int(playground.call("get_tile_size_px"))
	return 32


# -- Run state serialization ---------------------------------------------------

func to_run_state() -> Dictionary:
	return {
		"hero_display_name": hero_display_name,
		"class_id": int(hero_class),
		"level": level,
		"current_exp": current_exp,
		"required_exp": required_exp,
		"max_health": max_health,
		"current_health": current_health,
		"is_dead": _is_dead
	}


func apply_run_state(snapshot: Dictionary) -> void:
	hero_display_name = String(snapshot.get("hero_display_name", hero_display_name))
	hero_class = clampi(int(snapshot.get("class_id", int(hero_class))), HeroClass.WARRIOR, HeroClass.ASSASSIN)
	level = maxi(1, int(snapshot.get("level", level)))
	required_exp = maxi(1, int(snapshot.get("required_exp", required_exp)))
	current_exp = clampi(int(snapshot.get("current_exp", current_exp)), 0, required_exp)
	_emit_progression_changed()

	var snapshot_max_health: float = float(snapshot.get("max_health", max_health))
	var snapshot_current_health: float = float(snapshot.get("current_health", snapshot_max_health))
	set_max_health(snapshot_max_health, false)
	current_health = clampf(snapshot_current_health, 0.0, max_health)

	var should_be_dead: bool = bool(snapshot.get("is_dead", false)) or current_health <= 0.0
	if should_be_dead:
		current_health = 0.0
		_enter_dead_state(false)
	else:
		_exit_dead_state()
	_emit_health_changed()
	_recalculate_stats()
	update_attack_origin_cell()


# -- Health management ---------------------------------------------------------

func set_max_health(value: float, reset_current: bool = true) -> void:
	max_health = maxf(1.0, value)
	if reset_current:
		current_health = max_health
	else:
		current_health = clampf(current_health, 0.0, max_health)
	_emit_health_changed()


func apply_damage(amount: float) -> void:
	if _is_dead:
		return
	if amount <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	_emit_health_changed()
	_visual.play_damage_flash()
	if current_health <= 0.0:
		_die()


func get_current_health() -> float:
	return current_health


func get_max_health() -> float:
	return max_health


func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return current_health / max_health


func is_dead() -> bool:
	return _is_dead


# -- Public animation convenience methods --------------------------------------

func play_idle() -> void:
	_play_state(State.IDLE, true)


func play_walk() -> void:
	_play_state(State.WALK, true)


func play_attack01() -> void:
	_play_state(State.ATTACK01, true)


func play_death() -> void:
	_play_state(State.DEATH, true)


func is_state_finished() -> bool:
	return _animator.is_animation_finished()


# -- Visual delegates ----------------------------------------------------------

func set_selected_visual(selected: bool) -> void:
	_visual.set_selected(selected)


func is_selected_visual() -> bool:
	return _visual.is_selected()


func set_attack_range_preview_visible(visible: bool) -> void:
	if _show_attack_range_preview == visible:
		return
	_show_attack_range_preview = visible
	_update_attack_range_overlay()


func _update_attack_range_overlay() -> void:
	if playground == null:
		return
	if not playground.has_method("set_hero_attack_range_overlay"):
		return
	playground.call("set_hero_attack_range_overlay", self, _show_attack_range_preview)


# -- Component signal handlers -------------------------------------------------

func _on_animator_non_loop_finished() -> void:
	if state == State.DEATH:
		return
	_attack_ctrl.clear_pending()
	if _move_order_active:
		_play_state(State.WALK, true)
	else:
		_play_state(State.IDLE, true)


func _on_attack_requested(_target: Area2D) -> void:
	_play_state(State.ATTACK01, true)
	_attack_ctrl.try_fire_on_current_frame()


# -- Animation state -----------------------------------------------------------

func _play_state(new_state: State, force: bool = false) -> void:
	if _is_dead and new_state != State.DEATH:
		return
	var same_state: bool = new_state == state
	if not force and same_state:
		return
	state = new_state

	var anim_name: StringName = _anim_name_from_state(state)
	if state == State.WALK and not _animator.has_animation(anim_name):
		if not _warned_missing_walk_animation:
			_warned_missing_walk_animation = true
			push_warning("Hero: walk animation is missing. Falling back to idle.")
		anim_name = &"idle"

	if not _animator.has_animation(anim_name):
		push_warning("Missing animation for state: %s" % [anim_name])
		return
	if state == State.ATTACK01:
		_apply_attack_anim_speed()
	else:
		_animator.reset_speed()
	_animator.play(anim_name, force)


func _apply_attack_anim_speed() -> void:
	var cooldown: float = 1.0 / maxf(0.1, attacks_per_second)
	var base_duration: float = maxf(0.001, _attack01_base_duration_seconds)
	_animator.set_speed_scale(base_duration / maxf(0.001, cooldown))


func _anim_name_from_state(target_state: State) -> StringName:
	match target_state:
		State.IDLE:
			return &"idle"
		State.WALK:
			return &"walk"
		State.ATTACK01:
			return &"attack01"
		State.DEATH:
			return &"death"
	return &"idle"


# -- Death / lifecycle ---------------------------------------------------------

func _die() -> void:
	_enter_dead_state(true)


func _enter_dead_state(emit_signal: bool) -> void:
	if _is_dead:
		return
	_is_dead = true
	_move_order_active = false
	_move_path_points.clear()
	_move_path_index = 0
	set_physics_process(false)
	_attack_ctrl.stop()
	_visual.cancel_damage_flash()
	if _show_attack_range_preview:
		set_attack_range_preview_visible(false)
	_visual.apply_idle_outline()
	modulate = Color(1.0, 1.0, 1.0, 0.45)
	play_death()
	queue_redraw()
	if emit_signal:
		died.emit(self)


func _exit_dead_state() -> void:
	var was_dead: bool = _is_dead
	_is_dead = false
	_move_order_active = false
	_move_path_points.clear()
	_move_path_index = 0
	set_physics_process(false)
	_attack_ctrl.stop()
	modulate = Color.WHITE
	if was_dead:
		_play_state(State.IDLE, true)
	queue_redraw()


# -- Signal emission -----------------------------------------------------------

func _emit_health_changed() -> void:
	health_changed.emit(self, current_health, max_health, get_health_ratio())


func _emit_progression_changed() -> void:
	level = maxi(1, level)
	required_exp = maxi(1, required_exp)
	current_exp = clampi(current_exp, 0, required_exp)
	progression_changed.emit(self, level, current_exp, required_exp)
