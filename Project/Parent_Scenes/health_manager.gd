extends MeshInstance3D


var base_health : float = 1
var base_armor : float = 0.1

var health_bar_visible: bool:
	set(value):	
		health_bar_visible = value
		visible = value
var is_damaged := false

##	max health after any modifiers
@onready var max_health : float = base_health 
## active health after any modifiers
@onready var health : float = max_health :
	set(value):
		health = clampf(value,-1,max_health)
		mesh.material.set_shader_parameter("health_amount", health/max_health)
		if health != max_health:
			is_damaged = true
			health_bar_visible = true
			return
		is_damaged = false
@onready var armor : float = base_armor ## base armor after modifers

func init_health(val: float):
	max_health = val
	health = val


func init_armor(val: float):
	armor = val


func damage(amt: float, _type: String):
	health -= (amt - amt*armor)
