extends Node2D

@export var hero_scene: PackedScene
@export var diamond_radius: float = 170.0

@onready var hero_container: Node2D = $HeroContainer


func is_inside_diamond(point: Vector2) -> bool:
	var local: Vector2 = point - global_position
	return absf(local.x) / diamond_radius + absf(local.y) / diamond_radius <= 1.0


func clamp_to_diamond(point: Vector2) -> Vector2:
	if is_inside_diamond(point):
		return point
	var local: Vector2 = point - global_position
	var sum: float = absf(local.x) / diamond_radius + absf(local.y) / diamond_radius
	if sum <= 0.0:
		return global_position
	local /= sum
	return global_position + local


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
	var to := clamp_to_diamond(pos)
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
		var slide_target := clamp_to_diamond(safe + slide)
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
	if not _has_overlap(global_position, hero):
		return global_position
	var cap: CapsuleShape2D = hero.drag_shape.shape
	var step: float = cap.radius * 2.0 + SEPARATION_BIAS
	for ring in range(1, 8):
		var samples := maxi(8, ring * 4)
		for i in samples:
			var angle := TAU * float(i) / float(samples)
			var candidate := global_position + Vector2(cos(angle), sin(angle)) * step * ring
			candidate = clamp_to_diamond(candidate)
			if not _has_overlap(candidate, hero):
				return candidate
	return global_position
