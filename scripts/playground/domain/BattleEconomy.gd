extends Node
class_name BattleEconomy

## 전투 내 골드/리롤 상태와 결제 규칙을 소유하는 도메인 서비스입니다.

signal gold_changed(new_amount: int)
signal reroll_state_changed(free_remaining: int, free_total: int, current_cost: int)

@export_group("BattleEconomy 시작 자원")
## 전투 시작 payload에 골드가 없을 때 사용할 기본 골드입니다.
@export_range(0, 99999, 1) var fallback_starting_gold: int = 100
## 전투 시작 시 제공하는 무료 리롤 횟수입니다.
@export_range(0, 20, 1) var free_reroll_uses: int = 5
## 무료 리롤 이후 유료 리롤의 단계당 증가 비용입니다.
@export_range(1, 999, 1) var paid_reroll_step_cost: int = 10

var _current_gold: int = 0
var _free_reroll_remaining: int = 0
var _paid_reroll_count: int = 0


func _ready() -> void:
	set_starting_gold(fallback_starting_gold)


func set_starting_gold(amount: int) -> void:
	_current_gold = maxi(0, amount)
	_free_reroll_remaining = maxi(0, free_reroll_uses)
	_paid_reroll_count = 0
	_emit_state_changed()


func get_gold() -> int:
	return _current_gold


func get_free_reroll_remaining() -> int:
	return _free_reroll_remaining


func get_free_reroll_uses() -> int:
	return maxi(0, free_reroll_uses)


func get_current_reroll_cost() -> int:
	if _free_reroll_remaining > 0:
		return 0
	return maxi(1, paid_reroll_step_cost) * (_paid_reroll_count + 1)


func can_afford(cost: int) -> bool:
	return _current_gold >= maxi(0, cost)


func try_spend_gold(cost: int) -> bool:
	var spend_amount: int = maxi(0, cost)
	if _current_gold < spend_amount:
		return false
	_current_gold -= spend_amount
	_emit_state_changed()
	return true


func try_consume_reroll() -> bool:
	var reroll_cost: int = get_current_reroll_cost()
	if reroll_cost > 0:
		if _current_gold < reroll_cost:
			return false
		_current_gold -= reroll_cost
		_paid_reroll_count += 1
	else:
		_free_reroll_remaining = maxi(0, _free_reroll_remaining - 1)
	_emit_state_changed()
	return true


func _emit_state_changed() -> void:
	gold_changed.emit(_current_gold)
	reroll_state_changed.emit(_free_reroll_remaining, get_free_reroll_uses(), get_current_reroll_cost())
