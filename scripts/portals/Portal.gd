extends Node2D
@export_group("포탈 식별자")
## 포탈을 식별하기 위한 고유 ID입니다.
@export var portal_id: StringName = &"portal_01"
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	if anim.animation != &"idle":
		anim.animation = &"idle"
	anim.play(&"idle")
