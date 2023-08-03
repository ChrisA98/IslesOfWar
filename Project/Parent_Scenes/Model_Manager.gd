extends Node3D

@export var attack_animations := 1

var unit_models := []
var animating := false:
	set(value):
		animating = value
		if value:
			animation_func = Callable(_animate)
			return
		## Pass an idle lambda function to stop animating
		animation_func = func(_d):
			pass
var moving	:= false:
	set(value):
		moving = value
		if(value):
			_add_anim_function(Callable(snap_to_ground))
			return
		animate_calls.erase(Callable(snap_to_ground))
## Process calls
var animate_calls : Array[Callable]
var animation_func := Callable(_animate)
## Gets level hieghtmap to snap to floor
var get_height: Callable

@onready var animation_trees: Array[AnimationTree]

func _ready():
	## Prepare unit models list and animation trees
	for i in get_children():
		unit_models.push_back(i)
		var tree = i.find_child("AnimationTree")
		if tree == null:
			continue
		tree.active = true
		animation_trees.push_back(tree)


## Do on process
func _process(delta):
	animation_func.call(delta)


## Snap unit models to ground
func snap_to_ground(delta):
	for mod in unit_models:
		mod.position.y =  mod.position.y + ((get_height.call(mod.global_position) - get_parent().position.y)-mod.position.y)*delta


## Make units face target
func face_target(trgt):
	var lookdir = atan2(trgt.x, trgt.z)
	for i in unit_models:
		i.rotation.y = lerp(i.rotation.y, lookdir, 0.1)


func unit_attack(atk_spd: float):
	var attack_id = randi_range(0,attack_animations-1)
	call_deferred("_pulse_rand_animation_parameter","conditions/primary_attack")


## Probably change this when I look more at animating
func _animate(delta):
	for c in animate_calls:
		c.call(delta)


## Push animation and ensure it doesnt alreayd exist in the array
func _add_anim_function(anim:Callable):
	if(animate_calls.has(anim)):
		return
	animate_calls.push_back(anim)


