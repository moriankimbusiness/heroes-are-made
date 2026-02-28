extends Node
class_name EnemyAttackController

## 적의 공격 실행과 쿨다운을 관리하는 컴포넌트입니다.

signal cooldown_expired()

var _timer: Timer


func configure(timer: Timer) -> void:
	_timer = timer
	if _timer != null:
		_timer.one_shot = true
		_timer.timeout.connect(_on_timeout)


func perform_attack(target: Area2D, damage: float, attacks_per_second: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("apply_damage"):
		target.call("apply_damage", damage)
	_start_cooldown(attacks_per_second)


func perform_core_attack(core: Node2D, damage: float, attacks_per_second: float) -> void:
	if core == null or not is_instance_valid(core):
		return
	if core.has_method("apply_damage"):
		core.call("apply_damage", damage)
	_start_cooldown(attacks_per_second)


func is_on_cooldown() -> bool:
	if _timer == null:
		return false
	return not _timer.is_stopped()


func stop() -> void:
	if _timer != null:
		_timer.stop()


func _start_cooldown(attacks_per_second: float) -> void:
	if _timer == null:
		return
	var rate: float = maxf(0.1, attacks_per_second)
	_timer.start(1.0 / rate)


func _on_timeout() -> void:
	cooldown_expired.emit()
