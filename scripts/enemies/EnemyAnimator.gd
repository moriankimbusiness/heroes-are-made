extends Node
class_name EnemyAnimator

## 적의 애니메이션 재생을 관리하는 컴포넌트입니다.

signal non_loop_finished()

var _anim: AnimatedSprite2D
var _is_animation_finished: bool = false


func configure(animated_sprite: AnimatedSprite2D) -> void:
	_anim = animated_sprite
	if _anim != null:
		_anim.animation_finished.connect(_on_animation_finished)


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
