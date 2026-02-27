extends PathFollow2D

@export_group("디버그 이동")
@export var speed: float = 60.0


func _process(delta: float) -> void:
	progress += speed * delta
