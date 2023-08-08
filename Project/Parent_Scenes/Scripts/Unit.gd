class_name Unit_Base
extends CharacterBody3D

''' Signals '''
signal selected
signal died
signal update_fog
signal uncovered_area #area enters det area
signal attacked #did an attack
signal move_unlocked ## Can travel again

'''Enums'''
enum {LAND, NAVAL, AERIAL}
enum attack_type{MELEE, RANGE_PROJ, RANGE_AREA, RANGE_BEAM, LOCKED_RANGE_PROJ, LOCKED_RANGE_AREA }

''' Export Vars '''
## Area this unit reveals fog in
@export var unit_name: String
@export var fog_rev_radius : float = 50

''' Movement '''
@export_group("Travel")
@export var max_speed = 10
@export_flags("Land","Naval","Aerial") var travel_terrain
@export var accel = 3
@export var deccel = 3

''' Export Combat vars '''
@export_group("Combat")
@export var base_atk_spd : float = 1
@export_range(0,.99) var base_armor : float = 0.1
@export var base_health : float = 1
@export var base_atk_str : float = 10
@export var main_attack_type : attack_type	## Is a ranged attacker
@export var damage_type : String
@export var target_atk_rng : int = 5
## added variation to unit attacking
## can be improved by research
## melee numbers should be lower
@export_range(0,.5) var _m_attack_damage_variance : float = .25
@export_range(0,.25) var _r_attack_attack_spread : float = .125
@export_range(0,10) var unit_lockdown_time :int = 0 ## Unit doesn't have lockdown attack

var rng = RandomNumberGenerator.new()

''' Ai Controls '''
var ai_mode :StringName = "idle_basic":
	set(value):
		ai_mode = value
		if value.contains("attack"):
			atk_timer.start(current_atk_spd)
		else:
			target_enemy = null
			atk_timer.stop()
		unit_models.moving = !value.contains("idle")
		update_fog.emit(self, (!value.contains("idle") and is_visible))
		
var ai_methods : Dictionary = {
	"idle_basic" : Callable(_idling_basic),
	"idle_aggressive" : Callable(_idling_aggressive),
	"idle_defensive": Callable(_idling_defensive),
	"traveling_basic" : Callable(_traveling_basic),
	"wandering_basic" : Callable(_wandering_basic),
	"attack_commanded" : Callable(_targeted_attack),
	"garrison" : Callable(_garrisoning),
}
var intial_path_dist := 0.1
var target_garrison : Building
var formation_end_position: int	##position in formation when arriving at final location
var unit_id : int: ##unit id for prganizational purposes
	set(value):
		name = unit_name+"_"+str(actor_owner.actor_ID)+str(value)
		unit_id = value
var formation_core_position: Vector3

var stored_trgt_pos	## Target move stored for navmesh generation optimizing
var queued_move_target := Vector3.ZERO ## Target stored for long distance calculations
var is_locked_down: bool

''' Identifying Vars '''
var actor_owner
var unit_list

var is_selected: bool:
	set(value):
		is_selected = value
		$Selection.visible = value
var is_visible: bool:
	set(value):
		is_visible = value
		for i in $UnitModels.get_children():
			if i.name.contains("temp"):
				## Remove once attack indicator is gone
				continue
			##i.visible = value
		$Selection.visible = is_selected
		update_fog.emit(self, is_visible)

''' Cost Vars '''
var pop_cost := 0
var res_cost := {"wood": 0,
"stone": 0,
"riches": 10,
"crystals": 10,
"food": 0}

''' Derived and assigned Combat vars '''
var projectile_manager
var attack_method : Callable # method to attack with
var target_enemy:
	set(value):
		if(value != null):
			if(!value.died.is_connected(target_killed)):
				value.died.connect(target_killed)
			## Target is building
			if value.has_meta("show_base_radius"):
				target_atk_rng += value.bldg_radius
		else:
			actor_owner.erase_from_tracking_queue(self)
		
		## Previous enemy existed
		if(target_enemy != null):
			if(target_enemy.died.is_connected(target_killed)):
				target_enemy.died.disconnect(target_killed)
			## Target had building
			if target_enemy.has_meta("show_base_radius"):
				target_atk_rng -= target_enemy.bldg_radius
		
		target_enemy = value
var visible_enemies := []
var visible_allies := []

''' On-Ready Vars '''
''' Derived and assigned Combat vars '''
@onready var max_health : float = base_health ##max health after any modifiers
@onready var health : float = max_health :## active health after any modifiers
	set(value):
		health = clampf(value,-1,max_health)
@onready var armor : float = base_armor ## base armor after modifers
@onready var melee_dmg_var : float = _m_attack_damage_variance ## modified variance
@onready var ranged_atk_sprd : float = _r_attack_attack_spread ## modified variance
@onready var current_atk_str : float = base_atk_str  #with modifiers
@onready var current_atk_spd : float = base_atk_spd:  #with modifiers
	set(value):
		current_atk_spd = value
		atk_timer.start(current_atk_spd)
''' parts of scenetree '''
@onready var fog_reg = get_node("Fog_Breaker")
@onready var grnd_ping = get_node("Ground_Checker")
@onready var det_area = get_node("Detection_Area")
@onready var unit_models := $UnitModels
@onready var screen_notify = $VisibleOnScreenNotifier3D
## Combat vars
@onready var atk_timer := get_node("Attack_Timer")
## Navigation vars
@onready var nav_agent: NavigationAgent3D = get_node("NavigationAgent3D")
@onready var unit_radius = $CollisionShape3D.shape.get_radius()
''' travel vars '''
@onready var target_speed: int = max_speed:
	set(value):
		nav_agent.max_speed = value
## Function called to travel and can be changed to accomodate locked position
@onready var travel_function := Callable(_travel)

'''### Built-In Methods ###'''
func _ready():
	call_deferred("_prepare_nav_agent")
	## Connect signals
	nav_agent.waypoint_reached.connect(waypoint)
	atk_timer.timeout.connect(_attack)
	
	## Set attack type
	match main_attack_type:
		attack_type.MELEE:
			## Close range striking
			attack_method = Callable(__melee_attack)
		attack_type.RANGE_PROJ:
			## Preprocessed arc projectile is used
			attack_method = Callable(__ranged_proj_attack)
			projectile_manager = load("res://Parent_Scenes/Projectile_Arc.tscn")
		attack_type.RANGE_AREA:
			## Attack targets area and deals damage directly to target enemy from range
			attack_method = Callable(__ranged_area_attack)
		attack_type.RANGE_BEAM:
			## beam is creayed is used
			attack_method = Callable(__ranged_beam_attack)
			projectile_manager = load("res://Parent_Scenes/attack_beam.tscn")
			ai_methods["attack_commanded"] = Callable(_locked_targeted_attack)
		attack_type.LOCKED_RANGE_AREA:
			## Attack targets area and deals damage directly to target enemy from range
			attack_method = Callable(__ranged_area_attack)
			ai_methods["attack_commanded"] = Callable(_locked_targeted_attack)
		attack_type.LOCKED_RANGE_PROJ:
			## Preprocessed arc projectile is used
			attack_method = Callable(__ranged_proj_attack)
			projectile_manager = load("res://Parent_Scenes/Projectile_Arc.tscn")
			ai_methods["attack_commanded"] = Callable(_locked_targeted_attack)
	

func _process(delta):
	if(is_queued_for_deletion()):
		## Needed to fix bug with calling a callable on a queued for deletion object
		## It'd be cool if their was a workaround that didn't involve an if statement
		return
	ai_methods[ai_mode].call(delta)

'''### Public Methods ###'''
'''-------------------------------------------------------------------------------------'''
''' Startup Methods Start '''
## Load data from owning building
func load_data(data, model_masters, id):
	unit_id = id
	await get_tree().physics_frame
	unit_models.load_data(model_masters,Color(actor_owner.faction_data["magic_color"]))
	## Set data
	pop_cost = data["pop_cost"]
	for r in data["base_cost"]:
		res_cost[r] = data["base_cost"][r]
	
	## Set meta data
	set_meta("owner_id",actor_owner.actor_ID)
	
	## Fog Setup
	fog_reg.set_actor_owner(actor_owner.actor_ID)
	fog_reg.fog_break_radius = fog_rev_radius
	if(actor_owner.actor_ID == 0):
		fog_reg.visible = true
		fog_reg.active = true
	get_parent().added_fog_revealer(self)
	fog_reg.activate_area()
	
	if (actor_owner.actor_ID == 0):
		is_visible = true
		for m in $UnitModels.get_children():
			if(m.name.contains("Mesh")):
				if m.mesh.material != null:
					m.mesh.material.albedo_color = Color.BLUE
		det_area.set_collision_mask_value(5,false)
	else:
		## Non_player units need not clear fog
		fog_reg.detect_area.set_collision_mask_value(20,false)
		is_visible = false
		det_area.area_entered.connect(_det_area_entered)
		det_area.area_exited.connect(_det_area_exited)
		fog_reg.detect_area.area_entered.connect(_vision_area_entered)
		fog_reg.detect_area.area_exited.connect(_vision_area_exited)
	
	fog_reg.detect_area.body_entered.connect(_vision_body_entered)
	fog_reg.detect_area.body_exited.connect(_vision_body_exited)
	

## Prepare Navigation agent
func _prepare_nav_agent():
	await get_tree().physics_frame
	var travel_type = [false,false,false]
	## Set Navigation Layer based on movement type
	match travel_terrain:
		1,3,5:
			travel_type[0] = true
		2,3,6:
			travel_type[1] = true
		4,5,6:
			travel_type[2] = true
	
	for t in range(travel_type.size()):
		if travel_type[t]:
			nav_agent.set_navigation_layers(t+1)


''' Startup Methods End '''
'''-------------------------------------------------------------------------------------'''
''' Movement Methods Start '''
## Set target move location
##
## Called by outside functions
func set_mov_target(mov_tar: Vector3):
	if is_locked_down:
		call_deferred("delayed_unlock")
		await move_unlocked
		ai_mode = "traveling_basic"
		_set_target_position(mov_tar,true)
		return
	ai_mode = "traveling_basic"
	_set_target_position(mov_tar,true)


## Queue a movement to be caclulated
func queue_move(pos:Vector3):
	queued_move_target = Vector3.ZERO
	if position.distance_to(pos) > 575:
		queued_move_target = pos
		pos = position - (575*position.direction_to(pos))
	actor_owner.add_unit_tracking(self,Callable(set_mov_target.bind(pos)))


# Get gound depth at certain point
func get_ground_depth(pos = null):
	grnd_ping.enabled = true
	if(pos !=null):
		grnd_ping.position = Vector3(pos.x+position.x,250,pos.z+position.z)
	grnd_ping.force_raycast_update()
	var out =  grnd_ping.get_collision_point().y
	grnd_ping.position = Vector3(0,250,0)	## Reset to on unit
	update_fog.emit(self, is_visible)
	grnd_ping.enabled = false
	return out


## Set Garrison target
func set_garrison_target(bldg:Building):
	target_garrison = bldg
	_set_target_position(bldg.position,true)
	ai_mode = "garrison"


''' Movement Methods End '''

## Call to see if purchasable
func can_afford(builder_res):
	for res in builder_res:
		if builder_res[res] < res_cost[res] :
			return false
	return true


'''-------------------------------------------------------------------------------------'''
''' Player Input Methods Start '''
## Unit is selected and make selection visible
func select(state : bool = true):
	is_selected = state


## Signal being selected on click
func _on_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and Input.is_action_just_released("lmb"):
		selected.emit(self, event)

''' Player Input Methods End '''
'''-------------------------------------------------------------------------------------'''
''' Combat Methods Start '''
## Damage dealt
##
## returns true if killed or false if survived
## type is for later implementation
func damage(amt: float, _type: String):
	health -= (amt - amt*armor)
	## DIE
	if(health <= 0):
		died.emit()
		delayed_delete()
		return true
	return false


## Declares enemy
func declare_enemy(unit):
	ai_mode = "attack_commanded"
	target_enemy = unit


''' Combat Methods End '''
'''-------------------------------------------------------------------------------------'''
''' Destroy Unit Methods Start '''
## Signal from target dying
func target_killed():
	target_enemy = null
	atk_timer.stop()


## Delay delete and remove from lists
func delayed_delete():
	ai_mode = "idle_basic"
	## Deselect if selected
	get_parent().deselect_unit(self)
	unit_models.remove_units()
	actor_owner.units.erase(self)
	actor_owner.update_pop()
	unit_list.erase(self)
	await get_tree().physics_frame
	queue_free()


''' Destroy Unit Methods End '''
'''-------------------------------------------------------------------------------------'''
'''### Private Methods ###'''
''' Movement Methods Start '''
## Check target position for other units
func _check_pos(pos, mod = 1):
	for i in unit_list:
		if i == self:
			continue
		elif (i.position.distance_to(pos) <= unit_radius and i.ai_mode.contains("idle")):
			formation_end_position = i.formation_end_position+mod
			return _check_pos(i.formation_core_position+actor_owner.formation_pos(self,formation_end_position),mod+1)
	return pos



## set target move location 
func _set_target_position(mov_tar: Vector3, reset_formation := false):
	if(reset_formation):
		formation_core_position = mov_tar
		formation_end_position = 0
	nav_agent.set_target_position(mov_tar)
	intial_path_dist = nav_agent.distance_to_target()


## Speed up when starting movement
func _lerp_start(nv, dx):
	nv = nv.normalized()* target_speed
	nv = lerp(velocity,nv,dx*accel)
	return nv


## Speed up when starting movement
func _lerp_stop(nv, dx):
	nv = nv.normalized() * 0.2
	nv = lerp(velocity,nv,dx*deccel)
	return nv


## detection area code
func _det_area_entered(area):
	uncovered_area.emit(self, area)
	if(area.has_meta("fog_owner_id") and area.get_meta("fog_owner_id") == 0):
		## Area is player fog breaker
		is_visible = true


func _det_area_exited(area):
	if(area.has_meta("fog_owner_id") and area.get_meta("fog_owner_id") != 0):
		return
	## Area is player fog breaker
	is_visible = false
	await get_tree().physics_frame
	for ar in det_area.get_overlapping_areas():
		if(ar.has_meta("fog_owner_id") and ar.get_meta("fog_owner_id") == 0):
			## Still in player fog breaker
			is_visible = true


## Add enemies to sight array
func _vision_body_entered(body):
	if body.has_meta("owner_id") and body.get_meta("owner_id") != actor_owner.actor_ID:
		visible_enemies.push_back(body)


## Remove enemies from sight array
func _vision_body_exited(body):
	if visible_enemies.has(body):
		visible_enemies.erase(body)


## Add buildings to sight array
func _vision_area_entered(area):
	if area.has_meta("building_area") and area.get_parent().actor_owner.actor_ID != actor_owner.actor_ID:
		visible_enemies.push_back(area.get_parent())


## Remove buildings from  sight array
func _vision_area_exited(area):
	if area.has_meta("building_area") and area.get_parent().actor_owner.actor_ID == actor_owner.actor_ID:
		return
	if(visible_enemies.has(area.get_parent())):
		visible_enemies.erase(area.get_parent())


''' Movement Methods end '''
'''-------------------------------------------------------------------------------------'''
''' Combat Methods Start '''
## Attack function
func _attack():
	# Attack targeting
	if !is_instance_valid(target_enemy):
		return
	
	if (position.distance_to(target_enemy.position) > target_atk_rng) and !target_enemy.has_meta("show_base_radius"):
		return
	
	if target_enemy.has_meta("show_base_radius") and (position.distance_to(target_enemy.position)-target_enemy.bldg_radius > target_atk_rng):
		return
	
	## Temporasry Code for attack visualization
	unit_models.unit_attack(base_atk_spd)
	$UnitModels/attack_indicator_temp.visible = true
	
	atk_timer.start(base_atk_spd)
	attack_method.call()
	attacked.emit()
	await get_tree().create_timer(0.25).timeout
	$UnitModels/attack_indicator_temp.visible = false


## Ranged projectile attack callable
func __ranged_proj_attack():
	var dis = position.distance_to(target_enemy.position)
	var shot = projectile_manager.instantiate()
	var variance = Vector3(rng.randf_range(-ranged_atk_sprd,ranged_atk_sprd),0,rng.randf_range(-ranged_atk_sprd,ranged_atk_sprd))
	add_child(shot)
	shot.fire(position+Vector3.UP*3, target_enemy.position+variance, dis, current_atk_str, damage_type)


func __ranged_beam_attack():
	var beam = projectile_manager.instantiate()
	move_unlocked.connect(beam.end_beam)
	target_enemy.died.connect(beam.end_beam)
	add_child(beam)
	beam.begin_firing(Vector3.UP - Vector3.MODEL_FRONT*2, current_atk_str, damage_type, target_enemy.position - position)


## Ranged area attack callable
func __ranged_area_attack():
	if rng.randf_range(0,.25) < ranged_atk_sprd:
		## Target missed with shot
		return
	## Do animation later
	target_enemy.damage(current_atk_str,damage_type)


## Melee attack callable
func __melee_attack():
	var variance = rng.randf_range(-current_atk_str*melee_dmg_var,current_atk_str*melee_dmg_var)
	## Do animation later
	target_enemy.damage(current_atk_str+variance,damage_type)


''' Combat Methods End '''
'''-------------------------------------------------------------------------------------'''
''' AI Processes Methods Start '''
## Has a target set by player
func _targeted_attack(delta):
	# Attack targeting
	if !is_instance_valid(target_enemy):
		return
	
	## Handle tracking target
	if(position.distance_to(target_enemy.position) <= target_atk_rng):
		if nav_agent.is_navigation_finished():
			unit_models.face_target(target_enemy.position)
			return
		_set_target_position(position)
	else:
		__find_target(target_enemy,target_enemy.position,true)
	
	travel_function.call(delta)


## Has a target set by player
func _locked_targeted_attack(delta):
	# Attack targeting
	if !is_instance_valid(target_enemy):
		return
	
	## Handle tracking target
	if(position.distance_to(target_enemy.position) <= target_atk_rng):
		if nav_agent.is_navigation_finished():
			unit_models.face_target(target_enemy.position)
			return
		_set_target_position(position)
		_lock_position()
	elif (is_locked_down):
		#unlock unit		
		call_deferred("delayed_unlock")
	
	travel_function.call(delta)


## Travel to target location
func _traveling_basic(delta):
	travel_function.call(delta)


## Moving to Garrisoin target
func _garrisoning(delta):
	travel_function.call(delta)
	
	if position.distance_to(target_garrison.position) <= 10:
		target_garrison.garrison_unit(self)


## Idle Functions
func _idling_basic(_delta):
	pass


## Flee from enemies
func _idling_defensive(_delta):
	if(visible_enemies.size() > 0):
		_set_target_position(actor_owner.forts[rng.randi_range(0,actor_owner.forts.size()-1)].position)
		ai_mode = "traveling_basic"


## Fight encountered enemies
func _idling_aggressive(_delta):
	if(visible_enemies.size() > 0):
		declare_enemy(visible_enemies[0])


## Wander randomly
func _wandering_basic(delta):	
	if nav_agent.is_navigation_finished():
		var pos = Vector3(rng.randf_range(-100,100),250,rng.randf_range(-100,100))+position
		pos.y = get_ground_depth(pos)
		_set_target_position(pos)
		return
	travel_function.call(delta)


## Move on process
func _travel(_delta):
	if nav_agent.is_navigation_finished():
		return
	var current_agent_position: Vector3 = global_transform.origin
	var next_path_position: Vector3 = nav_agent.get_next_path_position()
	var new_velocity: Vector3 = next_path_position - current_agent_position
	#Accelerate and decelerrate
	#if nav_agent.distance_to_target() > intial_path_dist*.1 or nav_agent.distance_to_target() > 3:
	#	new_velocity = _lerp_start(new_velocity, delta)
	#else:
	#	new_velocity = _lerp_stop(new_velocity, delta)
	new_velocity = new_velocity.normalized()* target_speed
	# Look in walk direction
	unit_models.face_target(position + new_velocity)
	
	nav_agent.set_velocity(new_velocity)
	set_velocity(new_velocity)
	move_and_slide()


''' AI Processes Methods End '''
'''-------------------------------------------------------------------------------------'''
''' AI Processes Helper Methods Start '''


## Locked targeted attack
## Update navigation target to target enemy
func __find_target(trgt, pos:Vector3, _is_visible:bool):
	if(target_enemy != trgt):
		return
	if(nav_agent.get_target_position().distance_to(pos) > target_atk_rng):
		actor_owner.add_unit_tracking(self,Callable(_set_target_position.bind(pos,true)))


func _on_navigation_agent_3d_navigation_finished():
	unit_models.moving = false
	## Don't stop on other units if not attacking
	if(!ai_mode.contains("attack")):
		var targ = _check_pos(position)
		if(targ != position):
			queue_move(targ)
			return
	
	if ai_mode.contains("travel"):
		if(queued_move_target != Vector3.ZERO and position.distance_to(queued_move_target) > 5):
			queue_move(queued_move_target)
			return
		#nav_agent.set_velocity(Vector3.ZERO)
		#set_velocity(Vector3.ZERO)
		if actor_owner.actor_ID != 0:
			ai_mode = "idle_aggressive"
		else:
			ai_mode = "idle_basic"


func _on_NavigationAgent_velocity_computed(safe_velocity):
	if nav_agent.is_navigation_finished():
		return
	velocity = safe_velocity
	move_and_slide()


## Reaches waypoint
func waypoint(_details):
	pass


## Set locked travel state
func _lock_position(state:= true):
	is_locked_down = state
	if state:
		nav_agent.set_velocity(Vector3.ZERO)
		set_velocity(Vector3.ZERO)
		travel_function = Callable(_idling_basic)
		return
	travel_function = Callable(_travel)
	move_unlocked.emit()


## Set timer then unlock movement
func delayed_unlock():
	is_locked_down = false
	await get_tree().create_timer(unit_lockdown_time).timeout
	if !is_locked_down:
		_lock_position(false)
