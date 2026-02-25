extends Area2D
class_name Hero

const EquipmentStateRef = preload("res://scripts/items/EquipmentState.gd")
const ItemEnumsRef = preload("res://scripts/items/ItemEnums.gd")

signal hero_clicked(hero: Hero)
signal hero_moved(hero: Hero, world_position: Vector2)
signal hero_stats_changed(hero: Hero, stats: HeroStats)
signal equipment_changed(hero: Hero, slot: int, item: ItemData)

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var drag_shape: CollisionShape2D = $DragShape
@onready var attack_range: Area2D = $AttackRange
@onready var attack_range_shape: CollisionShape2D = $AttackRange/CollisionShape2D
@onready var attack_timer: Timer = $AttackTimer

enum State {
	IDLE,
	ATTACK01
}

enum TargetPriority {
	PATH_PROGRESS,
	LOWEST_HEALTH,
	NEAREST
}

@export var attack_enabled: bool = true
@export_range(0.1, 9999.0, 0.1) var attack_damage: float = 10.0
@export_range(0.1, 20.0, 0.1) var attacks_per_second: float = 1.2
@export var target_priority: TargetPriority = TargetPriority.PATH_PROGRESS
@export_range(0, 99, 1) var attack_hit_frame_index: int = 2
@export var disable_attack_while_dragging: bool = true
@export_range(0.0, 20.0, 0.1) var attack_flip_deadzone: float = 0.1
@export var show_drag_collision_debug: bool = false
@export_range(-999, 999, 1) var base_strength: int = 2
@export_range(-999, 999, 1) var base_agility: int = 2
@export_range(-999, 999, 1) var base_intelligence: int = 1
@export_range(0.1, 9999.0, 0.1) var base_physical_attack: float = 10.0
@export_range(0.0, 9999.0, 0.1) var base_magic_attack: float = 5.0
@export_range(0.1, 20.0, 0.1) var base_attacks_per_second: float = 1.2
@export_range(0.0, 3.0, 0.01) var agility_attack_speed_factor: float = 0.03
@export var enhance_attack_multipliers: Array[float] = [1.0, 1.12, 1.26, 1.42, 1.6, 1.8, 2.02, 2.26, 2.52, 2.8, 3.1]

var state: State = State.IDLE
static var _any_dragging: bool = false
var _is_finished: bool = false
var _is_dead: bool = false
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_target: Vector2 = Vector2.ZERO
var _drag_velocity: Vector2 = Vector2.ZERO
var _last_nonzero_move: Vector2 = Vector2.RIGHT
var _targets_in_range: Array[Area2D] = []
var _current_target: Area2D = null
var _warned_invalid_target_ids: Dictionary = {}
var _show_attack_range_preview: bool = false
var _preview_state_before_press: bool = false
var _press_start_position: Vector2 = Vector2.ZERO
var _attack01_base_duration_seconds: float = 0.5
var _pending_attack_target: Area2D = null
var _pending_attack_damage: float = 0.0
var _pending_hit_frame_fired: bool = false
var playground: Node2D = null
var _stats: HeroStats = HeroStats.new()
var _equipment: EquipmentState = null

const CLICK_SELECTION_DISTANCE_SQ: float = 25.0


func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)
	anim.frame_changed.connect(_on_animation_frame_changed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_setup_equipment_system()
	_attack01_base_duration_seconds = _get_animation_base_duration_seconds(&"attack01")
	if attack_range != null:
		attack_range.area_entered.connect(_on_attack_range_area_entered)
		attack_range.area_exited.connect(_on_attack_range_area_exited)
	if attack_timer != null:
		attack_timer.one_shot = true
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	set_process(false)
	_play(State.IDLE, true)
	if attack_enabled:
		call_deferred("_attempt_auto_attack")


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if _is_dead:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_dragging = true
			_any_dragging = true
			_preview_state_before_press = _show_attack_range_preview
			_press_start_position = global_position
			_drag_offset = global_position - get_global_mouse_position()
			_drag_target = global_position
			_drag_velocity = Vector2.ZERO
			_show_attack_range_preview = true
			set_process(true)
			if disable_attack_while_dragging and attack_timer != null:
				attack_timer.stop()
			anim.material.set_shader_parameter(&"enabled", false)
			_request_visual_redraw()
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		_drag_target = get_global_mouse_position() + _drag_offset
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			var was_click: bool = global_position.distance_squared_to(_press_start_position) <= CLICK_SELECTION_DISTANCE_SQ
			_dragging = false
			_any_dragging = false
			_drag_velocity = Vector2.ZERO
			if was_click:
				_show_attack_range_preview = not _preview_state_before_press
				hero_clicked.emit(self)
			else:
				_show_attack_range_preview = false
			set_process(false)
			if attack_enabled and attack_timer != null and attack_timer.is_stopped():
				_attempt_auto_attack()
			anim.material.set_shader_parameter(&"enabled", false)
			_request_visual_redraw()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _dragging:
		return
	if not _show_attack_range_preview:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_show_attack_range_preview = false
			queue_redraw()


func _process(delta: float) -> void:
	if not _dragging:
		return
	var follow_alpha := clampf(delta * 20.0, 0.0, 1.0)
	var raw_target := _drag_target
	if playground:
		raw_target = playground.clamp_to_diamond(raw_target)
	_drag_velocity = _drag_velocity.lerp(raw_target - global_position, follow_alpha)
	var desired := global_position + _drag_velocity
	if playground:
		desired = playground.clamp_to_diamond(desired)
		desired = playground.resolve_overlaps_smooth(desired, self, _last_nonzero_move)
	var move := desired - global_position
	if move.length_squared() > 0.0001:
		_last_nonzero_move = move
	global_position = desired
	hero_moved.emit(self, global_position)


func _setup_equipment_system() -> void:
	_equipment = EquipmentStateRef.new()
	_equipment.changed.connect(_on_equipment_state_changed)
	_recalculate_stats()


func get_current_stats() -> HeroStats:
	return _stats.duplicate_state()


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
		total_strength += item.strength_bonus
		total_agility += item.agility_bonus
		total_intelligence += item.intelligence_bonus
		var enhance_multiplier: float = _get_enhance_multiplier(item.enhance_level)
		total_physical_bonus += item.physical_attack_bonus * enhance_multiplier
		total_magic_bonus += item.magic_attack_bonus * enhance_multiplier

	_stats.strength = total_strength
	_stats.agility = total_agility
	_stats.intelligence = total_intelligence
	_stats.physical_attack = base_physical_attack + float(total_strength) + total_physical_bonus
	_stats.magic_attack = base_magic_attack + float(total_intelligence) + total_magic_bonus
	_stats.attacks_per_second = maxf(0.1, base_attacks_per_second * (1.0 + float(total_agility) * agility_attack_speed_factor))

	attack_damage = maxf(0.1, _stats.physical_attack)
	attacks_per_second = _stats.attacks_per_second
	if state == State.ATTACK01:
		_apply_attack_anim_speed_for_aps()
	hero_stats_changed.emit(self, _stats.duplicate_state())


func _get_enhance_multiplier(level: int) -> float:
	if level <= 0:
		return 1.0
	if enhance_attack_multipliers.is_empty():
		return 1.0 + float(level) * 0.12
	var index: int = clampi(level, 0, enhance_attack_multipliers.size() - 1)
	return enhance_attack_multipliers[index]


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
	if disable_attack_while_dragging and _dragging:
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


func _draw_capsule(color: Color, width: float = 1.0) -> void:
	var cap: CapsuleShape2D = drag_shape.shape
	var off: Vector2 = drag_shape.position
	var r: float = cap.radius
	var h: float = cap.height / 2.0 - r  # half-spine
	# 상단 반원 (왼쪽→위→오른쪽)
	draw_arc(off + Vector2(0, -h), r, PI, TAU, 32, color, width)
	# 하단 반원 (오른쪽→아래→왼쪽)
	draw_arc(off + Vector2(0, h), r, 0, PI, 32, color, width)
	# 좌/우 직선
	draw_line(off + Vector2(-r, -h), off + Vector2(-r, h), color, width)
	draw_line(off + Vector2(r, -h), off + Vector2(r, h), color, width)


func _draw_attack_range_preview() -> void:
	var circle_shape: CircleShape2D = attack_range_shape.shape as CircleShape2D
	if circle_shape == null:
		return
	var center: Vector2 = attack_range.position + attack_range_shape.position
	var radius: float = circle_shape.radius
	draw_circle(center, radius, Color(0.35, 0.85, 1.0, 0.08))
	draw_arc(center, radius, 0.0, TAU, 72, Color(0.35, 0.85, 1.0, 0.7), 1.6)


func _request_visual_redraw() -> void:
	if show_drag_collision_debug:
		get_tree().call_group(&"hero", "queue_redraw")
		return
	queue_redraw()


func _draw() -> void:
	if _dragging or _show_attack_range_preview:
		_draw_attack_range_preview()
	if not show_drag_collision_debug:
		return
	if not _any_dragging:
		return
	if _dragging:
		_draw_capsule(Color(1.0, 1.0, 1.0, 0.6))
	else:
		_draw_capsule(Color(1.0, 1.0, 1.0, 0.25))


func _on_mouse_entered() -> void:
	if _is_dead or _any_dragging:
		return
	anim.material.set_shader_parameter(&"enabled", true)


func _on_mouse_exited() -> void:
	if _dragging:
		return
	anim.material.set_shader_parameter(&"enabled", false)


func play_idle() -> void:
	_play(State.IDLE, true)


func play_attack01() -> void:
	_play(State.ATTACK01, true)


func is_state_finished() -> bool:
	return _is_finished


func is_dead() -> bool:
	return _is_dead


func _play(new_state: State, force: bool = false) -> void:
	if _is_dead:
		return
	var same_state: bool = new_state == state
	if not force and same_state:
		return
	state = new_state
	_is_finished = false

	var anim_name: StringName = _anim_name_from_state(state)
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(anim_name):
		push_warning("Missing animation for state: %s" % [anim_name])
		return
	if state == State.IDLE:
		anim.speed_scale = 1.0
	elif state == State.ATTACK01:
		_apply_attack_anim_speed_for_aps()
	if force and same_state:
		anim.stop()
	anim.play(anim_name)


func _on_animation_finished() -> void:
	if anim.sprite_frames == null:
		return

	var anim_name: StringName = _anim_name_from_state(state)
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
	_clear_pending_attack()
	_play(State.IDLE, true)


func _anim_name_from_state(target_state: State) -> StringName:
	match target_state:
		State.IDLE:
			return &"idle"
		State.ATTACK01:
			return &"attack01"
	return &"idle"
