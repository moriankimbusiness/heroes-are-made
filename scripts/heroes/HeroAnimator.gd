extends Node
class_name HeroAnimator

## 히어로의 애니메이션 재생을 관리하는 컴포넌트입니다.

signal non_loop_finished()
signal frame_changed()

var _anim: AnimatedSprite2D
var _is_animation_finished: bool = false


func configure(animated_sprite: AnimatedSprite2D) -> void:
	_anim = animated_sprite
	if _anim != null:
		_anim.animation_finished.connect(_on_animation_finished)
		_anim.frame_changed.connect(_on_frame_changed)


func play(anim_name: StringName, force: bool = false) -> void:
	if _anim == null:
		return
	var same_anim: bool = _anim.animation == anim_name
	if not force and same_anim:
		return
	_is_animation_finished = false
	if force and same_anim:
		_anim.stop()
	_anim.play(anim_name)


func has_animation(anim_name: StringName) -> bool:
	if _anim == null or _anim.sprite_frames == null:
		return false
	return _anim.sprite_frames.has_animation(anim_name)


func is_animation_finished() -> bool:
	return _is_animation_finished


func set_flip_h(value: bool) -> void:
	if _anim != null:
		_anim.flip_h = value


func get_flip_h() -> bool:
	if _anim == null:
		return false
	return _anim.flip_h


func set_speed_scale(value: float) -> void:
	if _anim != null:
		_anim.speed_scale = value


func reset_speed() -> void:
	set_speed_scale(1.0)


func get_current_frame() -> int:
	if _anim == null:
		return 0
	return _anim.frame


func get_frame_count(anim_name: StringName) -> int:
	if _anim == null or _anim.sprite_frames == null:
		return 0
	if not _anim.sprite_frames.has_animation(anim_name):
		return 0
	return _anim.sprite_frames.get_frame_count(anim_name)


func get_base_duration(anim_name: StringName) -> float:
	if _anim == null or _anim.sprite_frames == null:
		return 0.5
	if not _anim.sprite_frames.has_animation(anim_name):
		return 0.5
	var fps: float = maxf(0.001, _anim.sprite_frames.get_animation_speed(anim_name))
	var count: int = _anim.sprite_frames.get_frame_count(anim_name)
	if count <= 0:
		return 0.5
	var total_units: float = 0.0
	for i: int in count:
		total_units += _anim.sprite_frames.get_frame_duration(anim_name, i)
	if total_units <= 0.0:
		return 0.5
	return total_units / fps


func _on_animation_finished() -> void:
	if _anim == null or _anim.sprite_frames == null:
		return
	var current: StringName = _anim.animation
	if not _anim.sprite_frames.has_animation(current):
		return
	if _anim.sprite_frames.get_animation_loop(current):
		return
	if _is_animation_finished:
		return
	_is_animation_finished = true
	non_loop_finished.emit()


func _on_frame_changed() -> void:
	frame_changed.emit()
