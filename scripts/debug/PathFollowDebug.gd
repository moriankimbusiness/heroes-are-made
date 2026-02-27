extends PathFollow2D

@export_group("디버그 이동")
## 디버그 경로 이동 속도(px/s)입니다.
@export var speed: float = 60.0


func _process(delta: float) -> void:
	progress += speed * delta
