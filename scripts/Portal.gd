extends Node2D

@export var portal_id: StringName = &"portal_01"
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	if anim.animation != &"idle":
		anim.animation = &"idle"
	anim.play(&"idle")
