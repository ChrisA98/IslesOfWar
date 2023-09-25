extends Building

func _ready():
	super()
	can_attack = true
	attack_manager.call_deferred("init",attack_manager.attack_type.RANGE_PROJ, .125, 0, "damage_type")

