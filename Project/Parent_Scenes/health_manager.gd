extends MeshInstance3D


var base_health : float = 1
var base_armor : float = 0.1

var health_bar_visible: bool:
	set(value):	
		health_bar_visible = value
		if hide_override:
			visible = false
			return
		visible = health_bar_visible
var is_damaged := false
## Force hide health_bar
var hide_override: bool:
	set(value):
		hide_override = value
		health_bar_visible = health_bar_visible

##	Max health after any modifiers
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
