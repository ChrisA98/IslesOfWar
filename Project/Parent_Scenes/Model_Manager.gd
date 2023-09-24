extends Node3D

@export var attack_animations := 1

var unit_nodes := {}
var model_masters : = []
var unit_Color : Color
var base_animation_state : String = "idle"
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
			base_animation_state = "walk"
			_set_unit_animation_state("walk")
			return
		set_idle()
var attacking := false:
	set(value):
		attacking = value
		if !value and base_animation_state == "idle":
			set_idle()
var last_model_burst_animated: int = 0
## Process calls
var animate_calls : Array[Callable]


func load_data(_model_masters : Array, faction_clr : Color):
	model_masters = _model_masters
	for mm in _model_masters:
		mm.unit_reordered.connect(reorder_units)
	## Prepare unit models list
	for i in get_children():
		var m_id = _assign_model_master(i.name)
		unit_nodes[i] = [m_id,model_masters[m_id].spawn_unit_instance(i.global_position,faction_clr)]
		i.get_child(0).queue_free()
	flip_nodes()
	unit_Color = faction_clr


## flip the unit nodes so they go max to min
func flip_nodes():
	var keys = unit_nodes.keys()
	var out = {}
	for i in unit_nodes.size():
		var targ_nod = keys[unit_nodes.size()-i-1] 
		out[targ_nod] = unit_nodes[targ_nod]
	unit_nodes = out

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
	last_model_burst_animated += 1 
	if last_model_burst_animated >= unit_nodes.size():
		last_model_burst_animated = 0
	var unit_attacking = get_child(last_model_burst_animated)
	var node = unit_nodes[unit_attacking]
	model_masters[node[0]].burst_animation(node[1],"attack_"+attack_id,atk_spd)


## Reorder nodes from master list
func reorder_units(master, old_id, new_id):
	for u in unit_nodes:
		var node = unit_nodes[u]
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


## Remove unit from list
func remove_units():
	for u in unit_nodes:
		var node = unit_nodes[u]
		model_masters[node[0]].delete_unit(node[1])
		node[1] = 0


## Moves modelinstances based on node markers
func move_models(trgt = null):
	if !rendered:
		return
	var node = unit_nodes[get_child(0)]
	var unit_basis = model_masters[node[0]].get_unit_basis(node[1])
	for i in unit_nodes:
		node = unit_nodes[i]
		model_masters[node[0]].move_unit_instance(node[1],i.global_position,unit_basis)
	if trgt == null:
		return
	face_target(get_child(0).global_position+trgt)


## set current idle animation
func set_idle():
	base_animation_state = "idle"
	if attacking:		
		_set_unit_animation_state("idle_attacking")
		return
	_set_unit_animation_state("idle")


## Update all unit model instance aniamtions
func _set_unit_animation_state(state: String):
	for i in unit_nodes:
		var node = unit_nodes[i]
		model_masters[node[0]].set_animation_state(node[1],state)


func _hide_units(state: bool = true):
	for i in unit_nodes:
		var node = unit_nodes[i]
		model_masters[node[0]].hide_unit(node[1],unit_Color,state)
	
