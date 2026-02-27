extends Node2D

@export var hero_scene: PackedScene
@export_range(10.0, 2000.0, 1.0) var play_area_radius: float = 220.0
@export var core_path: NodePath
@export_flags_2d_physics var los_collision_mask: int = 1
@export_range(0.0, 64.0, 0.1) var los_probe_radius: float = 6.0
@export_range(0.0, 64.0, 0.1) var los_hit_backoff: float = 2.0
@export var enable_los_debug_draw: bool = false

@onready var play_area_outline: Line2D = $PlayAreaOutline
@onready var hero_container: Node2D = $HeroContainer

const PLAY_AREA_OUTLINE_SEGMENTS: int = 72
const LOS_BINARY_SEARCH_STEPS: int = 10
const LOS_MIN_SEGMENT_SQ: float = 0.0001
const MOVE_MIN_DISTANCE_SQ: float = 4.0
const PATH_SWEEP_MIN_STEP: float = 2.0

var _last_los_from_local: Vector2 = Vector2.ZERO
var _last_los_to_local: Vector2 = Vector2.ZERO
var _last_los_hit_local: Vector2 = Vector2.ZERO
var _last_los_has_hit: bool = false


func _ready() -> void:
	_refresh_play_area_outline()


func get_play_area_center_global() -> Vector2:
	var core: Node2D = get_node_or_null(core_path) as Node2D
	if core != null:
		return core.global_position
	return global_position


func _get_core_area() -> Area2D:
	return get_node_or_null(core_path) as Area2D


func _get_core_collision_shape() -> CollisionShape2D:
	var core: Area2D = _get_core_area()
	if core == null:
		return null
	return core.get_node_or_null("CollisionShape2D") as CollisionShape2D


func _get_core_rect_half_extents() -> Vector2:
	var core_collision: CollisionShape2D = _get_core_collision_shape()
	if core_collision == null:
		return Vector2(-1.0, -1.0)
	var rect: RectangleShape2D = core_collision.shape as RectangleShape2D
	if rect == null:
		return Vector2(-1.0, -1.0)
	return rect.size * 0.5


func _push_point_outside_core(point: Vector2, clearance: float = 0.0) -> Vector2:
	var core_collision: CollisionShape2D = _get_core_collision_shape()
	if core_collision == null:
		return point
	var half_extents: Vector2 = _get_core_rect_half_extents()
	if half_extents.x <= 0.0 or half_extents.y <= 0.0:
		return point
	var expanded: Vector2 = half_extents + Vector2(clearance, clearance)
	var core_center: Vector2 = core_collision.global_position
	var local: Vector2 = point - core_center
	if absf(local.x) > expanded.x or absf(local.y) > expanded.y:
		return point

	var x_pen: float = expanded.x - absf(local.x)
	var y_pen: float = expanded.y - absf(local.y)
	if x_pen < y_pen:
		var x_sign: float = signf(local.x)
		if is_zero_approx(x_sign):
			x_sign = 1.0
		local.x = expanded.x * x_sign
	else:
		var y_sign: float = signf(local.y)
		if is_zero_approx(y_sign):
			y_sign = 1.0
		local.y = expanded.y * y_sign
	return core_center + local


func is_inside_play_area(point: Vector2) -> bool:
	return point.distance_to(get_play_area_center_global()) <= play_area_radius


func clamp_to_play_area(point: Vector2) -> Vector2:
	var center: Vector2 = get_play_area_center_global()
	var offset: Vector2 = point - center
	var distance: float = offset.length()
	var clamped: Vector2 = point
	if distance > play_area_radius:
		if distance <= 0.0001:
			clamped = center
		else:
			clamped = center + offset / distance * play_area_radius
	clamped = _push_point_outside_core(clamped)
	var recenter_offset: Vector2 = clamped - center
	var recenter_distance: float = recenter_offset.length()
	if recenter_distance > play_area_radius and recenter_distance > 0.0001:
		clamped = center + recenter_offset / recenter_distance * play_area_radius
	return clamped


func is_inside_diamond(point: Vector2) -> bool:
	return is_inside_play_area(point)


func clamp_to_diamond(point: Vector2) -> Vector2:
	return clamp_to_play_area(point)


func resolve_los_safe_target(from: Vector2, to: Vector2, hero_radius: float) -> Vector2:
	var clamped_from: Vector2 = clamp_to_play_area(from)
	var clamped_to: Vector2 = clamp_to_play_area(to)
	# Raycast is preview-only and does not block movement.
	_update_los_debug(clamped_from, clamped_to, {})
	return clamped_to


func evaluate_hero_move(
	from: Vector2,
	desired_to: Vector2,
	hero: Node,
	min_distance_sq: float = MOVE_MIN_DISTANCE_SQ
) -> Dictionary:
	var candidate: Vector2 = clamp_to_play_area(desired_to)
	var hint: Vector2 = desired_to - from
	candidate = resolve_overlaps_smooth(candidate, hero, hint)

	var result := {
		"final_position": candidate,
		"is_movable": true,
		"reason": &"ok"
	}

	if _is_core_overlap_at(candidate, hero):
		result["is_movable"] = false
		result["reason"] = &"blocked_by_core_or_bounds"
		return result
	if _has_enemy_overlap_at(candidate, hero):
		result["is_movable"] = false
		result["reason"] = &"blocked_by_enemy_destination"
		return result
	if _has_hero_overlap_only(candidate, hero):
		result["is_movable"] = false
		result["reason"] = &"blocked_by_hero_destination"
		return result
	if _is_enemy_path_blocked(from, candidate, hero):
		result["is_movable"] = false
		result["reason"] = &"blocked_by_enemy_path"
		return result
	if _is_hero_path_blocked(from, candidate, hero):
		result["is_movable"] = false
		result["reason"] = &"blocked_by_hero_path"
		return result
	var required_min_distance_sq: float = maxf(0.0, min_distance_sq)
	if from.distance_squared_to(candidate) < required_min_distance_sq:
		result["is_movable"] = false
		result["reason"] = &"too_close"
		return result
	return result


func _is_core_overlap_at(hero_position: Vector2, hero: Node) -> bool:
	var hero_shape: CollisionShape2D = hero.drag_shape
	if hero_shape == null:
		return false
	var hero_capsule: CapsuleShape2D = hero_shape.shape as CapsuleShape2D
	if hero_capsule == null:
		return false
	var core_clearance: float = hero_capsule.height * 0.5 + OVERLAP_EPSILON
	var core_probe: Vector2 = hero_position + hero_shape.position
	var pushed_from_core: Vector2 = _push_point_outside_core(core_probe, core_clearance)
	return not core_probe.is_equal_approx(pushed_from_core)


func _has_hero_overlap_only(pos: Vector2, exclude: Node) -> bool:
	var ex_shape: CollisionShape2D = exclude.drag_shape
	if ex_shape == null:
		return false
	var ex_cap: CapsuleShape2D = ex_shape.shape as CapsuleShape2D
	if ex_cap == null:
		return false
	for node: Node in get_tree().get_nodes_in_group(&"hero"):
		if node == exclude:
			continue
		if not is_instance_valid(node):
			continue
		var nd_shape: CollisionShape2D = node.drag_shape
		if nd_shape == null:
			continue
		var nd_cap: CapsuleShape2D = nd_shape.shape as CapsuleShape2D
		if nd_cap == null:
			continue
		var push := _capsule_push(
			pos, ex_cap, ex_shape.position,
			node.global_position, nd_cap, nd_shape.position,
			OVERLAP_EPSILON
		)
		if push.length_squared() > 0.0:
			return true
	return false


func _is_hero_path_blocked(from: Vector2, to: Vector2, exclude: Node) -> bool:
	var ex_shape: CollisionShape2D = exclude.drag_shape
	if ex_shape == null:
		return false
	var ex_cap: CapsuleShape2D = ex_shape.shape as CapsuleShape2D
	if ex_cap == null:
		return false
	var distance: float = from.distance_to(to)
	if distance <= 0.001:
		return false
	var step: float = maxf(PATH_SWEEP_MIN_STEP, ex_cap.radius * 0.5)
	var sample_count: int = maxi(1, int(ceili(distance / step)))
	for i: int in range(1, sample_count + 1):
		var t: float = float(i) / float(sample_count)
		var probe: Vector2 = from.lerp(to, t)
		if _has_hero_overlap_only(probe, exclude):
			return true
	return false


func _has_enemy_overlap_at(hero_position: Vector2, hero: Node) -> bool:
	var hero_shape: CollisionShape2D = hero.drag_shape
	if hero_shape == null:
		return false
	var hero_capsule: CapsuleShape2D = hero_shape.shape as CapsuleShape2D
	if hero_capsule == null:
		return false
	var hero_center: Vector2 = hero_position + hero_shape.position
	var hero_half_spine: float = maxf(0.0, hero_capsule.height * 0.5 - hero_capsule.radius)
	var hero_radius: float = hero_capsule.radius

	for enemy_node: Node in get_tree().get_nodes_in_group(&"enemy"):
		if not is_instance_valid(enemy_node):
			continue
		var enemy: Area2D = enemy_node as Area2D
		if enemy == null:
			continue
		if enemy.has_method("is_dead") and bool(enemy.call("is_dead")):
			continue
		var enemy_shape_node: CollisionShape2D = enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if enemy_shape_node == null or enemy_shape_node.disabled:
			continue
		var enemy_radius: float = _get_shape_block_radius(enemy_shape_node.shape)
		if enemy_radius <= 0.0:
			continue
		var enemy_center: Vector2 = enemy_shape_node.global_position
		var nearest_on_hero_spine: Vector2 = Vector2(
			hero_center.x,
			clampf(enemy_center.y, hero_center.y - hero_half_spine, hero_center.y + hero_half_spine)
		)
		if nearest_on_hero_spine.distance_to(enemy_center) < hero_radius + enemy_radius + OVERLAP_EPSILON:
			return true
	return false


func _is_enemy_path_blocked(from: Vector2, to: Vector2, hero: Node) -> bool:
	var hero_shape: CollisionShape2D = hero.drag_shape
	if hero_shape == null:
		return false
	var hero_capsule: CapsuleShape2D = hero_shape.shape as CapsuleShape2D
	if hero_capsule == null:
		return false
	var distance: float = from.distance_to(to)
	if distance <= 0.001:
		return false
	var step: float = maxf(PATH_SWEEP_MIN_STEP, hero_capsule.radius * 0.5)
	var sample_count: int = maxi(1, int(ceili(distance / step)))
	for i: int in range(1, sample_count + 1):
		var t: float = float(i) / float(sample_count)
		var probe: Vector2 = from.lerp(to, t)
		if _has_enemy_overlap_at(probe, hero):
			return true
	return false


func _get_shape_block_radius(shape: Shape2D) -> float:
	if shape == null:
		return 0.0
	if shape is CircleShape2D:
		return (shape as CircleShape2D).radius
	if shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape as CapsuleShape2D
		return maxf(capsule.radius, capsule.height * 0.5)
	if shape is RectangleShape2D:
		var rect: RectangleShape2D = shape as RectangleShape2D
		return maxf(rect.size.x, rect.size.y) * 0.5
	return 0.0


func _query_los_hit(from: Vector2, to: Vector2) -> Dictionary:
	# Movement LOS raycast is configured as pass-through.
	return {}


func _has_los_blocker(from: Vector2, to: Vector2) -> bool:
	return false


func _binary_search_los_clear(from: Vector2, to: Vector2) -> Vector2:
	return to


func _update_los_debug(from: Vector2, to: Vector2, hit: Dictionary) -> void:
	if not enable_los_debug_draw:
		return
	_last_los_from_local = to_local(from)
	_last_los_to_local = to_local(to)
	_last_los_has_hit = not hit.is_empty()
	if _last_los_has_hit:
		_last_los_hit_local = to_local(Vector2(hit.get("position", to)))
	queue_redraw()


const OVERLAP_EPSILON := 0.08   # 겹침 판정 버퍼 (작게 유지)
const SEPARATION_BIAS := 0.25   # 해소 계산 시 추가 분리 여유
const TANGENT_MIN_MOVE := 0.03  # 접선 이동 최소량
const MAX_SOLVE_ITER := 8


func _capsule_push(
	pos_a: Vector2, cap_a: CapsuleShape2D, off_a: Vector2,
	pos_b: Vector2, cap_b: CapsuleShape2D, off_b: Vector2,
	extra_separation: float = 0.0,
	fallback_dir: Vector2 = Vector2.ZERO
) -> Vector2:
	var ca := pos_a + off_a
	var cb := pos_b + off_b
	var sa := cap_a.height * 0.5 - cap_a.radius
	var sb := cap_b.height * 0.5 - cap_b.radius
	var dx := ca.x - cb.x
	var dy := ca.y - cb.y
	var abs_dy := absf(dy)
	var spine_sum := sa + sb
	var direction: Vector2
	var dist: float
	if abs_dy <= spine_sum:
		dist = absf(dx)
		if dist < 0.001:
			var base := fallback_dir if fallback_dir.length_squared() > 0.0001 else (ca - cb)
			if base.length_squared() < 0.0001:
				base = Vector2.RIGHT
			var x_sign := signf(base.x)
			if is_zero_approx(x_sign):
				x_sign = 1.0
			direction = Vector2(x_sign, 0.0)
		else:
			direction = Vector2(signf(dx), 0.0)
	else:
		var gap := abs_dy - spine_sum
		dist = sqrt(dx * dx + gap * gap)
		if dist < 0.001:
			var base := fallback_dir if fallback_dir.length_squared() > 0.0001 else (ca - cb)
			if base.length_squared() < 0.0001:
				base = Vector2.RIGHT
			direction = base.normalized()
		else:
			direction = Vector2(dx, signf(dy) * gap) / dist
	var pen := cap_a.radius + cap_b.radius + extra_separation - dist
	if pen <= 0.0:
		return Vector2.ZERO
	return direction * pen


func _has_overlap(pos: Vector2, exclude: Node) -> bool:
	var ex_shape: CollisionShape2D = exclude.drag_shape
	var ex_cap: CapsuleShape2D = ex_shape.shape
	var core_clearance: float = ex_cap.height * 0.5 + OVERLAP_EPSILON
	var core_probe: Vector2 = pos + ex_shape.position
	var pushed_from_core: Vector2 = _push_point_outside_core(core_probe, core_clearance)
	if not core_probe.is_equal_approx(pushed_from_core):
		return true
	for node in get_tree().get_nodes_in_group(&"hero"):
		if node == exclude:
			continue
		var nd_shape: CollisionShape2D = node.drag_shape
		var nd_cap: CapsuleShape2D = nd_shape.shape
		var ca := pos + ex_shape.position
		var cb = node.global_position + nd_shape.position
		var sa = ex_cap.height * 0.5 - ex_cap.radius
		var sb = nd_cap.height * 0.5 - nd_cap.radius
		var dx = ca.x - cb.x
		var dy = ca.y - cb.y
		var abs_dy := absf(dy)
		var spine_sum = sa + sb
		var dist: float
		if abs_dy <= spine_sum:
			dist = absf(dx)
		else:
			var gap = abs_dy - spine_sum
			dist = sqrt(dx * dx + gap * gap)
		if dist < ex_cap.radius + nd_cap.radius + OVERLAP_EPSILON:
			return true
	return false


func _find_deepest_push(
	pos: Vector2,
	exclude: Node,
	hint_dir: Vector2 = Vector2.ZERO,
	extra_separation: float = 0.0
) -> Vector2:
	var ex_shape: CollisionShape2D = exclude.drag_shape
	var deepest := Vector2.ZERO
	for node in get_tree().get_nodes_in_group(&"hero"):
		if node == exclude:
			continue
		var nd_shape: CollisionShape2D = node.drag_shape
		var push := _capsule_push(
			pos, ex_shape.shape, ex_shape.position,
			node.global_position, nd_shape.shape, nd_shape.position,
			extra_separation, hint_dir
		)
		if push.length() > deepest.length():
			deepest = push
	return deepest


func _find_total_push(
	pos: Vector2,
	exclude: Node,
	hint_dir: Vector2 = Vector2.ZERO,
	extra_separation: float = 0.0
) -> Vector2:
	var ex_shape: CollisionShape2D = exclude.drag_shape
	var total := Vector2.ZERO
	for node in get_tree().get_nodes_in_group(&"hero"):
		if node == exclude:
			continue
		var nd_shape: CollisionShape2D = node.drag_shape
		var push := _capsule_push(
			pos, ex_shape.shape, ex_shape.position,
			node.global_position, nd_shape.shape, nd_shape.position,
			extra_separation, hint_dir
		)
		total += push
	return total


func _binary_search_safe(from: Vector2, to: Vector2, exclude: Node) -> Vector2:
	if not _has_overlap(to, exclude):
		return to
	var lo := 0.0
	var hi := 1.0
	for i in 10:
		var mid := (lo + hi) * 0.5
		if _has_overlap(from.lerp(to, mid), exclude):
			hi = mid
		else:
			lo = mid
	return from.lerp(to, lo)


func resolve_overlaps(pos: Vector2, exclude: Node) -> Vector2:
	var hint = pos - exclude.global_position
	return resolve_overlaps_smooth(pos, exclude, hint)


func resolve_overlaps_smooth(pos: Vector2, exclude: Node, hint_dir: Vector2 = Vector2.ZERO) -> Vector2:
	var from: Vector2 = exclude.global_position
	var to := clamp_to_play_area(pos)
	var safe := _binary_search_safe(from, to, exclude)
	var hint = hint_dir if hint_dir.length_squared() > 0.0001 else (to - from)
	for slide_idx in MAX_SOLVE_ITER:
		var remaining := to - safe
		if remaining.length() < TANGENT_MIN_MOVE and slide_idx >= 2:
			break
		if remaining.length_squared() < 0.0001:
			remaining = hint
		var probe := safe + remaining.normalized() * (OVERLAP_EPSILON + SEPARATION_BIAS)
		var push := _find_total_push(probe, exclude, hint, SEPARATION_BIAS)
		if push.length_squared() < 0.001:
			push = _find_deepest_push(probe, exclude, hint, SEPARATION_BIAS)
		if push.length_squared() < 0.001:
			if slide_idx >= 2:
				break
			continue
		var normal := push.normalized()
		var slide := remaining - normal * remaining.dot(normal)
		if slide.length() < TANGENT_MIN_MOVE:
			if slide_idx >= 2:
				break
			continue
		var slide_target := clamp_to_play_area(safe + slide)
		var new_safe := _binary_search_safe(safe, slide_target, exclude)
		if new_safe.distance_to(safe) < TANGENT_MIN_MOVE:
			if slide_idx >= 2:
				break
			continue
		hint = new_safe - safe
		safe = new_safe
	return safe


func summon_hero() -> Hero:
	if hero_scene == null:
		push_warning("PlayGround: hero_scene is not set")
		return null
	var hero: Hero = hero_scene.instantiate()
	hero.playground = self
	hero_container.add_child(hero)
	hero.global_position = _find_spawn_position(hero)
	return hero


func _find_spawn_position(hero: Area2D) -> Vector2:
	var center: Vector2 = get_play_area_center_global()
	if not _has_overlap(center, hero):
		return center
	var cap: CapsuleShape2D = hero.drag_shape.shape
	var step: float = cap.radius * 2.0 + SEPARATION_BIAS
	for ring in range(1, 8):
		var samples := maxi(8, ring * 4)
		for i in samples:
			var angle := TAU * float(i) / float(samples)
			var candidate := center + Vector2(cos(angle), sin(angle)) * step * ring
			candidate = clamp_to_play_area(candidate)
			if not _has_overlap(candidate, hero):
				return candidate
	return center


func _refresh_play_area_outline() -> void:
	if play_area_outline == null:
		return
	var center_local: Vector2 = to_local(get_play_area_center_global())
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(PLAY_AREA_OUTLINE_SEGMENTS + 1):
		var angle: float = TAU * float(i) / float(PLAY_AREA_OUTLINE_SEGMENTS)
		points.append(center_local + Vector2(cos(angle), sin(angle)) * play_area_radius)
	play_area_outline.points = points


func _draw() -> void:
	if not enable_los_debug_draw:
		return
	draw_line(_last_los_from_local, _last_los_to_local, Color(1.0, 0.8, 0.2, 0.75), 1.5)
	if _last_los_has_hit:
		draw_circle(_last_los_hit_local, 3.0, Color(1.0, 0.25, 0.25, 0.9))
