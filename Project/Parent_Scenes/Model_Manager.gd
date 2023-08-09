extends Node3D

@export var attack_animations := 1

var unit_nodes := {}
var model_masters : = []
var unit_Color : Color
var rendered = false:
	set(value):
		rendered = value
		_hide_units(!value)
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
		var m_id = _assign_model_master(i.name)
		unit_nodes[i] = [m_id,model_masters[m_id].spawn_unit_instance(i.global_position,faction_clr)]
	for i in model_masters:
		model_masters[i].unit_reordered.connect(reorder_units)


## Do on process
func _process(_delta):
	_move_models()


## Make units face target
func face_target(trgt):
	for i in unit_nodes:
		var node = unit_nodes[i]
		model_masters[node[0]].face_unit_instance(node[1],trgt)


func unit_attack(atk_spd: float):
	var attack_id = str(randi_range(1,attack_animations))
	
	var unit_attacking = get_child(randi_range(0,unit_nodes.size()-1))
	var node = unit_nodes[unit_attacking]
	model_masters[node[0]].burst_animation(node[1],"attack_"+attack_id,atk_spd)


## Reorder nodes from master list
func reorder_units(master,old_id,new_id):
	for node in unit_nodes:
		if model_masters[node[0]] != master:
			continue
		if old_id == node[1]:
			node[1] = new_id


## Get target modle master from list
func _assign_model_master(mod_name:String):
	for i in range(0,model_masters.size()):
		if mod_name.contains(model_masters[i].model_name):
			return i
	return 0


## Remove unit from  list
func remove_units():
	for u in unit_nodes:
		var node = unit_nodes[u]
		model_masters[node[0]].delete_unit(node[1])


## Moves modelinstances based on node markers
func _move_models():
	for i in unit_nodes:
		var node = unit_nodes[i]
		model_masters[node[0]].move_unit_instance(node[1],i.global_position)


## Update all unit model instance aniamtions
func _set_unit_animation_state(state: String):
	for i in unit_nodes:
		var node = unit_nodes[i]
		model_masters[node[0]].set_animation_state(node[1],state)


## Probably change this when I look more at animating
func _animate(delta):
	for c in animate_calls:
		c.call(delta)


## Push animation and ensure it doesnt alreayd exist in the array
func _add_anim_function(anim:Callable):
	if(animate_calls.has(anim)):
		return
	animate_calls.push_back(anim)


func _hide_units(state: bool = true):
	for i in unit_nodes:
		var node = unit_nodes[i]
		model_masters[node[0]].hide_unit(node[1],state)
	
