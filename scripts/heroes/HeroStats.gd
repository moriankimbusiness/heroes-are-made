extends RefCounted
class_name HeroStats

var strength: int = 0
var agility: int = 0
var intelligence: int = 0
var physical_attack: float = 0.0
var magic_attack: float = 0.0
var attacks_per_second: float = 1.0


func duplicate_state() -> HeroStats:
	var copied := HeroStats.new()
	copied.strength = strength
	copied.agility = agility
	copied.intelligence = intelligence
	copied.physical_attack = physical_attack
	copied.magic_attack = magic_attack
	copied.attacks_per_second = attacks_per_second
	return copied
