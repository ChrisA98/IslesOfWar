extends Node3D

@export var attack_animations := 1

var unit_nodes := {}
var model_masters : = []
var unit_Color : Color
var rendered = false:
	set(value):
		rendered = value
		_hide_units(!value)
		if value:
			move_models(Vector3.ZERO)
var moving	:= false:
	set(value):
		if moving == value:
			return
		moving = value
		if value:
			_set_unit_animation_state("walk")
			return
		_set_unit_animation_state("idle")
## Process calls
var animate_calls : Array[Callable]



func load_data(_model_masters : Array, faction_clr : Color):
	model_masters = _model_masters
	## Prepare unit models list
	for i in get_children():
		var m_id = _assign_model_master(i.name)
		unit_nodes[i] = [m_id,model_masters[m_id].spawn_unit_instance(i.global_position,faction_clr)]
		i.get_child(0).queue_free()
	unit_Color = faction_clr
	


## Do on process
func _process(_delta):
	#move_models()
	pass


## Make units face target
func face_target(trgt):
	if !rendered:
		return
	for i in unit_nodes:
		var node = unit_nodes[i]
		var unit_basis = model_masters[node[0]].get_unit_basis(node[1])
		model_masters[node[0]].face_unit_instance(node[1],trgt,unit_basis)


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
func move_models(trgt):
	if !rendered:
		return
	var node = unit_nodes[get_child(0)]
	var unit_basis = model_masters[node[0]].get_unit_basis(node[1])
	for i in unit_nodes:
		node = unit_nodes[i]
		model_masters[node[0]].move_unit_instance(node[1],i.global_position,unit_basis)
	face_target(get_child(0).global_position+trgt)


## Update all unit model instance aniamtions
func _set_unit_animation_state(state: String):
	for i in unit_nodes:
		var node = unit_nodes[i]
		model_masters[node[0]].set_animation_state(node[1],state)


func _hide_units(state: bool = true):
	for i in unit_nodes:
		var node = unit_nodes[i]
		model_masters[node[0]].hide_unit(node[1],unit_Color,state)
	
