extends Node
class_name HeroVisualController

## 히어로의 비주얼 이펙트(외곽선, 피격 플래시, 선택 강조)를 관리하는 컴포넌트입니다.

var _hero: Hero
var _anim: AnimatedSprite2D
var _is_hovering: bool = false
var _is_selected: bool = false
var _is_damage_flash_active: bool = false
var _damage_flash_tween: Tween = null


func configure(hero: Hero, animated_sprite: AnimatedSprite2D) -> void:
	_hero = hero
	_anim = animated_sprite
	if _hero != null:
		_hero.mouse_entered.connect(_on_mouse_entered)
		_hero.mouse_exited.connect(_on_mouse_exited)
	_set_damage_fill_color(_hero.damage_fill_color)
	_set_damage_fill_strength(0.0)
	apply_idle_outline()


func set_selected(selected: bool) -> void:
	if _is_selected == selected:
		return
	_is_selected = selected
	if _is_damage_flash_active:
		return
	apply_idle_outline()


func is_selected() -> bool:
	return _is_selected


func is_damage_flash_active() -> bool:
	return _is_damage_flash_active


func play_damage_flash() -> void:
	if _anim == null or _anim.material == null:
		return
	cancel_damage_flash()
	_is_damage_flash_active = true
	_set_damage_fill_color(_hero.damage_fill_color)
	_set_outline_visual(true, _hero.damage_outline_color)
	_set_damage_fill_strength(1.0)
	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_method(_set_damage_fill_strength, 1.0, 0.0, maxf(0.01, _hero.damage_flash_duration))
	_damage_flash_tween.finished.connect(_on_damage_flash_finished)


func cancel_damage_flash() -> void:
	if _damage_flash_tween != null and is_instance_valid(_damage_flash_tween):
		_damage_flash_tween.kill()
	_damage_flash_tween = null
	_is_damage_flash_active = false


func apply_idle_outline() -> void:
	if _hero == null:
		return
	if _is_selected:
		_set_outline_visual(true, _hero.selected_outline_color)
		_set_damage_fill_color(_hero.selected_fill_color)
		_set_damage_fill_strength(_hero.selected_fill_strength)
		return
	_set_damage_fill_strength(0.0)
	if _is_hovering and not _hero.is_dead():
		_set_outline_visual(true, _hero.hover_outline_color)
	else:
		_set_outline_visual(false, _hero.hover_outline_color)


func _set_outline_visual(enabled: bool, color: Color) -> void:
	if _anim == null or _anim.material == null:
		return
	_anim.material.set_shader_parameter(&"enabled", enabled)
	if enabled:
		_anim.material.set_shader_parameter(&"outline_color", color)


func _set_damage_fill_color(color: Color) -> void:
	if _anim == null or _anim.material == null:
		return
	_anim.material.set_shader_parameter(&"damage_flash_color", color)


func _set_damage_fill_strength(value: float) -> void:
	if _anim == null or _anim.material == null:
		return
	_anim.material.set_shader_parameter(&"damage_flash", clampf(value, 0.0, 1.0))


func _on_damage_flash_finished() -> void:
	_damage_flash_tween = null
	_is_damage_flash_active = false
	_set_damage_fill_strength(0.0)
	apply_idle_outline()


func _on_mouse_entered() -> void:
	_is_hovering = true
	if _is_damage_flash_active:
		return
	apply_idle_outline()


func _on_mouse_exited() -> void:
	_is_hovering = false
	if _is_damage_flash_active:
		return
	apply_idle_outline()
