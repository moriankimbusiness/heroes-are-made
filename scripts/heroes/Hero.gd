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

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var drag_shape: CollisionShape2D = $DragShape
@onready var attack_range: Area2D = $AttackRange
@onready var attack_range_shape: CollisionShape2D = $AttackRange/CollisionShape2D
@onready var attack_timer: Timer = $AttackTimer
@onready var status_anchor: Marker2D = $StatusAnchor
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

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
@export_group("공격 기본값")
## 자동 공격 동작 활성화 여부입니다.
@export var attack_enabled: bool = true
## 기본 1회 공격 피해량입니다.
@export_range(0.1, 9999.0, 0.1) var attack_damage: float = 10.0
## 초당 공격 횟수(APS)입니다.
@export_range(0.1, 20.0, 0.1) var attacks_per_second: float = 1.2
## 공격 사거리 기본값입니다.
@export_range(1.0, 9999.0, 0.1) var base_attack_range: float = 35.014282
## 공격 사거리 가산값입니다.
@export_range(-9999.0, 9999.0, 0.1) var attack_range_add: float = 0.0
## 공격 사거리 배율값입니다.
@export_range(0.1, 10.0, 0.01) var attack_range_scale: float = 1.0
## 공격 대상 우선순위 규칙입니다.
@export var target_priority: TargetPriority = TargetPriority.PATH_PROGRESS
## 공격 애니메이션에서 실제 타격이 발생하는 프레임 인덱스입니다.
@export_range(0, 99, 1) var attack_hit_frame_index: int = 2
## 공격 방향 반전 시 무시할 X축 데드존입니다.
@export_range(0.0, 20.0, 0.1) var attack_flip_deadzone: float = 0.1
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
var _is_finished: bool = false
var _is_dead: bool = false
var _move_order_active: bool = false
var _move_order_target: Vector2 = Vector2.ZERO
var _targets_in_range: Array[Area2D] = []
var _current_target: Area2D = null
var _warned_invalid_target_ids: Dictionary = {}
var _show_attack_range_preview: bool = false
var _attack01_base_duration_seconds: float = 0.5
var _pending_attack_target: Area2D = null
var _pending_attack_damage: float = 0.0
var _pending_hit_frame_fired: bool = false
var _warned_missing_walk_animation: bool = false
var _warned_missing_navigation_agent: bool = false
var _is_hovering: bool = false
var _is_selected: bool = false
var _is_damage_flash_active: bool = false
var _damage_flash_tween: Tween = null
var playground: Node2D = null
var _stats: HeroStats = HeroStats.new()
var _equipment: EquipmentState = null
var max_health: float = 100.0
var current_health: float = 100.0


func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)
	anim.frame_changed.connect(_on_animation_frame_changed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_set_damage_fill_color(damage_fill_color)
	_set_damage_fill_strength(0.0)
	_apply_idle_outline_visual()
	set_max_health(base_max_health)
	_setup_equipment_system()
	_attack01_base_duration_seconds = _get_animation_base_duration_seconds(&"attack01")
	_refresh_attack_range()
	if attack_range != null:
		attack_range.area_entered.connect(_on_attack_range_area_entered)
		attack_range.area_exited.connect(_on_attack_range_area_exited)
	if attack_timer != null:
		attack_timer.one_shot = true
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	set_physics_process(false)
	_play(State.IDLE, true)
	_emit_progression_changed()
	if attack_enabled:
		call_deferred("_attempt_auto_attack")


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is not InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	hero_clicked.emit(self)
	if not _is_damage_flash_active:
		_apply_idle_outline_visual()
	_request_visual_redraw()
	get_viewport().set_input_as_handled()


func issue_move_command(world_target: Vector2) -> void:
	if _is_dead:
		return
	_move_order_target = _clamp_to_play_area(world_target)
	_clear_pending_attack()
	_current_target = null
	if attack_timer != null:
		attack_timer.stop()
	if global_position.distance_to(_move_order_target) <= move_stop_distance:
		_stop_move_order(true)
		return
	if navigation_agent != null:
		navigation_agent.target_position = _move_order_target
	elif not _warned_missing_navigation_agent:
		_warned_missing_navigation_agent = true
		push_warning("Hero: NavigationAgent2D is missing. Falling back to direct move.")
	_move_order_active = true
	set_physics_process(true)
	_play(State.WALK, true)
	_request_visual_redraw()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	if not _move_order_active:
		set_physics_process(false)
		return
	_step_move_order(delta)


func _step_move_order(delta: float) -> void:
	var to_target: Vector2 = _move_order_target - global_position
	var remaining: float = to_target.length()
	if remaining <= move_stop_distance:
		_stop_move_order(true)
		return
	if move_speed <= 0.0:
		_stop_move_order(true)
		return

	var max_step: float = move_speed * delta
	if max_step <= 0.0:
		return
	var next_position: Vector2 = _resolve_next_move_position(max_step, to_target, remaining)

	var move_vector: Vector2 = next_position - global_position
	if move_vector.length_squared() <= 0.0001:
		_stop_move_order(true)
		return

	global_position = next_position
	_update_walk_facing(move_vector)
	hero_moved.emit(self, global_position)

	if global_position.distance_to(_move_order_target) <= move_stop_distance:
		_stop_move_order(true)


func _resolve_next_move_position(max_step: float, to_target: Vector2, remaining: float) -> Vector2:
	if navigation_agent == null:
		var fallback_step: Vector2 = global_position + to_target.normalized() * minf(max_step, remaining)
		return _clamp_to_play_area(fallback_step)

	navigation_agent.target_position = _move_order_target
	if navigation_agent.is_navigation_finished():
		return global_position
	var path_next: Vector2 = navigation_agent.get_next_path_position()
	if not path_next.is_finite():
		return global_position

	var to_next: Vector2 = path_next - global_position
	if to_next.length_squared() <= 0.0001:
		return global_position
	var step_target: Vector2 = global_position + to_next.normalized() * minf(max_step, to_next.length())
	return _clamp_to_play_area(step_target)


func _stop_move_order(play_idle: bool) -> void:
	_move_order_active = false
	set_physics_process(false)
	if _is_dead:
		return
	if play_idle:
		_play(State.IDLE, true)
	if attack_enabled and attack_timer != null and attack_timer.is_stopped():
		_attempt_auto_attack()


func _update_walk_facing(move: Vector2) -> void:
	if move.x > attack_flip_deadzone:
		anim.flip_h = false
	elif move.x < -attack_flip_deadzone:
		anim.flip_h = true


func _clamp_to_play_area(point: Vector2) -> Vector2:
	if playground == null:
		return point
	if playground.has_method("clamp_to_play_area"):
		return Vector2(playground.call("clamp_to_play_area", point))
	if playground.has_method("clamp_to_diamond"):
		return Vector2(playground.call("clamp_to_diamond", point))
	return point


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
	_refresh_attack_range()
	if state == State.ATTACK01:
		_apply_attack_anim_speed_for_aps()
	hero_stats_changed.emit(self, _stats.duplicate_state())


func get_final_attack_range() -> float:
	return _get_final_attack_range()


func _refresh_attack_range() -> void:
	if attack_range_shape == null:
		return
	var circle_shape: CircleShape2D = attack_range_shape.shape as CircleShape2D
	if circle_shape == null:
		return
	circle_shape.radius = _get_final_attack_range()
	if _show_attack_range_preview:
		queue_redraw()


func _get_final_attack_range() -> float:
	return maxf(1.0, (base_attack_range + attack_range_add) * attack_range_scale)


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


func _on_attack_range_area_entered(area: Area2D) -> void:
	if not _is_valid_enemy_target(area):
		return
	if not _targets_in_range.has(area):
		_targets_in_range.append(area)
	if attack_enabled and attack_timer != null and attack_timer.is_stopped():
		_attempt_auto_attack()


func _on_attack_range_area_exited(area: Area2D) -> void:
	_targets_in_range.erase(area)
	if _current_target == area:
		_current_target = null
	if attack_enabled and attack_timer != null and attack_timer.is_stopped():
		_attempt_auto_attack()


func _on_attack_timer_timeout() -> void:
	_attempt_auto_attack()


func _attempt_auto_attack() -> void:
	if not attack_enabled or _is_dead:
		return
	if _move_order_active:
		return
	_cleanup_targets()
	if _targets_in_range.is_empty():
		_current_target = null
		return

	_current_target = _pick_target()
	if _current_target == null:
		return
	if not _current_target.has_method("apply_damage"):
		_warn_invalid_target_once(_current_target, "apply_damage")
		_targets_in_range.erase(_current_target)
		_current_target = null
		if attack_timer != null and attack_timer.is_stopped():
			_attempt_auto_attack()
		return

	_update_attack_facing(_current_target)
	_queue_pending_attack(_current_target, attack_damage)
	_play_next_attack_animation()
	_try_fire_pending_attack_on_current_frame()
	if attack_timer != null:
		attack_timer.start(_get_attack_cooldown_seconds())


func _cleanup_targets() -> void:
	for i: int in range(_targets_in_range.size() - 1, -1, -1):
		var target: Area2D = _targets_in_range[i]
		if not _is_valid_enemy_target(target):
			_targets_in_range.remove_at(i)


func _pick_target() -> Area2D:
	match target_priority:
		TargetPriority.LOWEST_HEALTH:
			return _pick_target_by_lowest_health()
		TargetPriority.NEAREST:
			return _pick_target_by_nearest()
		_:
			return _pick_target_by_path_progress()


func _pick_target_by_path_progress() -> Area2D:
	var best_target: Area2D = null
	var best_progress: float = -INF
	var best_distance_sq: float = INF
	for target: Area2D in _targets_in_range:
		if not _is_valid_enemy_target(target):
			continue
		var progress: float = _get_enemy_path_progress(target)
		var distance_sq: float = global_position.distance_squared_to(target.global_position)
		if best_target == null:
			best_target = target
			best_progress = progress
			best_distance_sq = distance_sq
			continue
		if progress > best_progress:
			best_target = target
			best_progress = progress
			best_distance_sq = distance_sq
			continue
		if is_equal_approx(progress, best_progress) and distance_sq < best_distance_sq:
			best_target = target
			best_progress = progress
			best_distance_sq = distance_sq
	return best_target


func _pick_target_by_lowest_health() -> Area2D:
	var best_target: Area2D = null
	var best_health: float = INF
	var best_progress: float = -INF
	var best_distance_sq: float = INF
	for target: Area2D in _targets_in_range:
		if not _is_valid_enemy_target(target):
			continue
		var health: float = _get_enemy_current_health(target)
		var progress: float = _get_enemy_path_progress(target)
		var distance_sq: float = global_position.distance_squared_to(target.global_position)
		if best_target == null:
			best_target = target
			best_health = health
			best_progress = progress
			best_distance_sq = distance_sq
			continue
		if health < best_health:
			best_target = target
			best_health = health
			best_progress = progress
			best_distance_sq = distance_sq
			continue
		if is_equal_approx(health, best_health) and progress > best_progress:
			best_target = target
			best_health = health
			best_progress = progress
			best_distance_sq = distance_sq
			continue
		if is_equal_approx(health, best_health) and is_equal_approx(progress, best_progress) and distance_sq < best_distance_sq:
			best_target = target
			best_health = health
			best_progress = progress
			best_distance_sq = distance_sq
	return best_target


func _pick_target_by_nearest() -> Area2D:
	var best_target: Area2D = null
	var best_distance_sq: float = INF
	var best_progress: float = -INF
	for target: Area2D in _targets_in_range:
		if not _is_valid_enemy_target(target):
			continue
		var distance_sq: float = global_position.distance_squared_to(target.global_position)
		var progress: float = _get_enemy_path_progress(target)
		if best_target == null:
			best_target = target
			best_distance_sq = distance_sq
			best_progress = progress
			continue
		if distance_sq < best_distance_sq:
			best_target = target
			best_distance_sq = distance_sq
			best_progress = progress
			continue
		if is_equal_approx(distance_sq, best_distance_sq) and progress > best_progress:
			best_target = target
			best_distance_sq = distance_sq
			best_progress = progress
	return best_target


func _get_enemy_current_health(target: Area2D) -> float:
	if not is_instance_valid(target):
		return INF
	if target.has_method("get_current_health"):
		return float(target.call("get_current_health"))
	return INF


func _get_enemy_path_progress(target: Area2D) -> float:
	if not is_instance_valid(target):
		return -INF
	var parent: Node = target.get_parent()
	if parent is PathFollow2D:
		return (parent as PathFollow2D).progress
	return -1.0


func _play_next_attack_animation() -> void:
	play_attack01()


func _get_attack_cooldown_seconds() -> float:
	var rate: float = maxf(0.1, attacks_per_second)
	return 1.0 / rate


func _get_animation_base_duration_seconds(anim_name: StringName) -> float:
	if anim.sprite_frames == null:
		return 0.5
	if not anim.sprite_frames.has_animation(anim_name):
		return 0.5
	var fps: float = maxf(0.001, anim.sprite_frames.get_animation_speed(anim_name))
	var frame_count: int = anim.sprite_frames.get_frame_count(anim_name)
	if frame_count <= 0:
		return 0.5
	var total_units: float = 0.0
	for i: int in frame_count:
		total_units += anim.sprite_frames.get_frame_duration(anim_name, i)
	if total_units <= 0.0:
		return 0.5
	return total_units / fps


func _apply_attack_anim_speed_for_aps() -> void:
	var cooldown: float = _get_attack_cooldown_seconds()
	var base_duration: float = maxf(0.001, _attack01_base_duration_seconds)
	anim.speed_scale = base_duration / maxf(0.001, cooldown)


func _queue_pending_attack(target: Area2D, damage: float) -> void:
	_pending_attack_target = target
	_pending_attack_damage = damage
	_pending_hit_frame_fired = false


func _clear_pending_attack() -> void:
	_pending_attack_target = null
	_pending_attack_damage = 0.0
	_pending_hit_frame_fired = false


func _get_clamped_attack_hit_frame_index() -> int:
	if anim.sprite_frames == null:
		return 0
	if not anim.sprite_frames.has_animation(&"attack01"):
		return 0
	var frame_count: int = anim.sprite_frames.get_frame_count(&"attack01")
	if frame_count <= 0:
		return 0
	return clampi(attack_hit_frame_index, 0, frame_count - 1)


func _try_fire_pending_attack_on_current_frame() -> void:
	if state != State.ATTACK01:
		return
	if _pending_hit_frame_fired:
		return
	if _pending_attack_target == null:
		return
	if anim.frame != _get_clamped_attack_hit_frame_index():
		return
	_execute_pending_attack()


func _execute_pending_attack() -> void:
	var target: Area2D = _pending_attack_target
	var damage: float = _pending_attack_damage
	_pending_hit_frame_fired = true
	if not _is_valid_enemy_target(target):
		return
	if not target.has_method("apply_damage"):
		_warn_invalid_target_once(target, "apply_damage")
		return
	target.call("apply_damage", damage)


func _update_attack_facing(target: Area2D) -> void:
	if not is_instance_valid(target):
		return
	var dx: float = target.global_position.x - global_position.x
	if dx > attack_flip_deadzone:
		anim.flip_h = false
	elif dx < -attack_flip_deadzone:
		anim.flip_h = true


func _is_valid_enemy_target(target: Area2D) -> bool:
	if not is_instance_valid(target):
		return false
	if not target.is_in_group(&"enemy"):
		return false
	if target.has_method("is_dead") and bool(target.call("is_dead")):
		return false
	return true


func _warn_invalid_target_once(target: Area2D, method_name: String) -> void:
	if not is_instance_valid(target):
		return
	var target_id: int = target.get_instance_id()
	if _warned_invalid_target_ids.has(target_id):
		return
	_warned_invalid_target_ids[target_id] = true
	push_warning("Hero: target '%s' is missing method '%s'." % [target.name, method_name])


func _draw_attack_range_preview() -> void:
	var circle_shape: CircleShape2D = attack_range_shape.shape as CircleShape2D
	if circle_shape == null:
		return
	var center: Vector2 = attack_range.position + attack_range_shape.position
	var radius: float = circle_shape.radius
	draw_circle(center, radius, Color(0.35, 0.85, 1.0, 0.08))
	draw_arc(center, radius, 0.0, TAU, 72, Color(0.35, 0.85, 1.0, 0.7), 1.6)


func _request_visual_redraw() -> void:
	queue_redraw()


func _draw() -> void:
	if _show_attack_range_preview:
		_draw_attack_range_preview()


func _set_outline_visual(enabled: bool, color: Color) -> void:
	if anim.material == null:
		return
	anim.material.set_shader_parameter(&"enabled", enabled)
	if enabled:
		anim.material.set_shader_parameter(&"outline_color", color)


func _set_damage_fill_color(color: Color) -> void:
	if anim.material == null:
		return
	anim.material.set_shader_parameter(&"damage_flash_color", color)


func _set_damage_fill_strength(value: float) -> void:
	if anim.material == null:
		return
	anim.material.set_shader_parameter(&"damage_flash", clampf(value, 0.0, 1.0))


func _apply_idle_outline_visual() -> void:
	if _is_selected:
		_set_outline_visual(true, selected_outline_color)
		_set_damage_fill_color(selected_fill_color)
		_set_damage_fill_strength(selected_fill_strength)
		return
	_set_damage_fill_strength(0.0)
	if _is_hovering and not _is_dead:
		_set_outline_visual(true, hover_outline_color)
	else:
		_set_outline_visual(false, hover_outline_color)


func _cancel_damage_flash() -> void:
	if _damage_flash_tween != null and is_instance_valid(_damage_flash_tween):
		_damage_flash_tween.kill()
	_damage_flash_tween = null
	_is_damage_flash_active = false


func _on_damage_flash_finished() -> void:
	_damage_flash_tween = null
	_is_damage_flash_active = false
	_set_damage_fill_strength(0.0)
	_apply_idle_outline_visual()


func _play_damage_flash() -> void:
	if anim.material == null:
		return
	_cancel_damage_flash()
	_is_damage_flash_active = true
	_set_damage_fill_color(damage_fill_color)
	_set_outline_visual(true, damage_outline_color)
	_set_damage_fill_strength(1.0)
	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_method(Callable(self, "_set_damage_fill_strength"), 1.0, 0.0, maxf(0.01, damage_flash_duration))
	_damage_flash_tween.finished.connect(_on_damage_flash_finished)


func _on_mouse_entered() -> void:
	_is_hovering = true
	if _is_damage_flash_active:
		return
	_apply_idle_outline_visual()


func _on_mouse_exited() -> void:
	_is_hovering = false
	if _is_damage_flash_active:
		return
	_apply_idle_outline_visual()


func set_selected_visual(selected: bool) -> void:
	if _is_selected == selected:
		return
	_is_selected = selected
	if _is_damage_flash_active:
		return
	_apply_idle_outline_visual()


func is_selected_visual() -> bool:
	return _is_selected


func set_attack_range_preview_visible(visible: bool) -> void:
	if _show_attack_range_preview == visible:
		return
	_show_attack_range_preview = visible
	queue_redraw()


func play_idle() -> void:
	_play(State.IDLE, true)


func play_walk() -> void:
	_play(State.WALK, true)


func play_attack01() -> void:
	_play(State.ATTACK01, true)


func play_death() -> void:
	_play(State.DEATH, true)


func is_state_finished() -> bool:
	return _is_finished


func is_dead() -> bool:
	return _is_dead


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
	_play_damage_flash()
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


func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	_move_order_active = false
	_targets_in_range.clear()
	_current_target = null
	_clear_pending_attack()
	set_physics_process(false)
	_cancel_damage_flash()
	_set_damage_fill_strength(0.0)
	if attack_timer != null:
		attack_timer.stop()
	_apply_idle_outline_visual()
	modulate = Color(1.0, 1.0, 1.0, 0.45)
	play_death()
	_request_visual_redraw()


func _play(new_state: State, force: bool = false) -> void:
	if _is_dead and new_state != State.DEATH:
		return
	var same_state: bool = new_state == state
	if not force and same_state:
		return
	state = new_state
	_is_finished = false

	var anim_name: StringName = _anim_name_from_state(state)
	if state == State.WALK and (anim.sprite_frames == null or not anim.sprite_frames.has_animation(anim_name)):
		if not _warned_missing_walk_animation:
			_warned_missing_walk_animation = true
			push_warning("Hero: walk animation is missing. Falling back to idle.")
		anim_name = &"idle"

	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(anim_name):
		push_warning("Missing animation for state: %s" % [anim_name])
		return
	if state == State.ATTACK01:
		_apply_attack_anim_speed_for_aps()
	else:
		anim.speed_scale = 1.0
	if force and same_state:
		anim.stop()
	anim.play(anim_name)


func _on_animation_finished() -> void:
	if anim.sprite_frames == null:
		return

	var anim_name: StringName = _anim_name_from_state(state)
	if state == State.WALK and not anim.sprite_frames.has_animation(anim_name):
		anim_name = &"idle"
	if not anim.sprite_frames.has_animation(anim_name):
		return
	if anim.sprite_frames.get_animation_loop(anim_name):
		return
	if _is_finished:
		return
	_is_finished = true
	_on_non_loop_finished()


func _on_animation_frame_changed() -> void:
	_try_fire_pending_attack_on_current_frame()


func _on_non_loop_finished() -> void:
	if state == State.DEATH:
		return
	_clear_pending_attack()
	if _move_order_active:
		_play(State.WALK, true)
	else:
		_play(State.IDLE, true)


func _emit_health_changed() -> void:
	health_changed.emit(self, current_health, max_health, get_health_ratio())


func _emit_progression_changed() -> void:
	level = maxi(1, level)
	required_exp = maxi(1, required_exp)
	current_exp = clampi(current_exp, 0, required_exp)
	progression_changed.emit(self, level, current_exp, required_exp)


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
