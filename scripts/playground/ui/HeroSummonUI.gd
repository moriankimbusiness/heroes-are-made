extends CanvasLayer

@onready var summon_button: Button = $BottomCenterUI/SummonButton


func _ready() -> void:
	summon_button.pressed.connect(_on_summon_button_pressed)


func _on_summon_button_pressed() -> void:
	var playground: Node2D = get_parent()
	playground.summon_hero()
