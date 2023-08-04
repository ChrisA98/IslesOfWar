extends Node3D

@export var attack_animations := 1

var unit_nodes := {}
var model_masters : = []
var unit_Color : Color
var moving	:= false:
	set(value):
		moving = value
		if value:
			_set_unit_animation_state("walk")
			return
		_set_unit_animation_state("idle")
## Process calls
var animate_calls : Array[Callable]


func _ready():
	pass


func load_data(_model_masters : Array, faction_clr : Color):
	model_masters = _model_masters
	## Prepare unit models list
	for i in get_children():
		if i.name.contains("temp"):
			## Remove once attack indicator is gone
			return
		unit_nodes[i] = model_masters[0].spawn_unit_instance(i.global_position,Color.GOLD)


## Do on process
func _process(delta):
	_move_models()


##Does that vvv
func _move_models():
	for i in unit_nodes:
		model_masters[0].move_unit_instance(unit_nodes[i],i.global_position)


## Update all unit model instance aniamtions
func _set_unit_animation_state(state: String):
	for i in unit_nodes:
		model_masters[0].set_animation_state(unit_nodes[i],state)


## Make units face target
func face_target(trgt):
	for i in unit_nodes:
		model_masters[0].face_unit_instance(unit_nodes[i],trgt)


func unit_attack(atk_spd: float):
	var attack_id = randi_range(0,attack_animations-1)
	
	var unit_attacking = get_child(randi_range(0,unit_nodes.size()-1))
	model_masters[0].burst_animation(unit_nodes[unit_attacking],"attack_01",atk_spd)


## Probably change this when I look more at animating
func _animate(delta):
	for c in animate_calls:
		c.call(delta)


## Push animation and ensure it doesnt alreayd exist in the array
func _add_anim_function(anim:Callable):
	if(animate_calls.has(anim)):
		return
	animate_calls.push_back(anim)


