class_name Unit_Base
extends CharacterBody3D

''' Signals '''
signal selected
signal died
signal update_fog
signal uncovered_area #area enters det area
signal attacked #did an attack

'''Enums'''
enum {GROUND, NAVAL, AERIAL}

'''Consts'''

''' Export Vars '''
## Area this unit reveals fog in
@export var unit_name: String
@export var fog_rev_radius : float = 50

''' Movement '''
@export_group("Travel")
@export var max_speed = 10
## Navigaion layers to enable
## 0 = GROUND
## 1 = NAVAL
## 2 = AERIAL
@export var travel_type := [false, false, false]
@export var accel = 3
@export var deccel = 3

''' Export Combat vars '''
@export_group("Combat")
@export var base_health : float = 1
@export_range(0,.99) var base_armor : float = 0.1
@export var is_ranged : bool = false	## Is a ranged attacker
@export var damage_type : String
@export var base_atk_str : float = 10
@export var base_atk_spd : float = 1
@export var target_atk_rng : int = 5
## added variation to unit attacking
## can be improved by research
## melee numbers should be lower
@export_range(0,.5) var m_attack_damage_variance : float = .25
@export_range(0,.25) var r_attack_attack_spread : float = .125

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
var ai_methods : Dictionary = {
	"idle_basic" : Callable(_idling_basic),
	"idle_aggressive" : Callable(_idling_aggressive),
	"idle_defensive": Callable(_idling_defensive),
	"traveling_basic" : Callable(_traveling_basic),
	"wandering_basic" : Callable(_wandering_basic),
	"attack_commanded" : Callable(_targeted_attack),
	"follow_basic" : Callable(_following),
}
var intial_path_dist := 0.1
var followers: Array
var target_follow: Unit_Base:
	set(value):
		if value == null:
			target_speed = max_speed
		else:
			target_speed = value.max_speed
		target_follow = value

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
		$UnitModels.visible = is_visible
		$Selection.visible = is_selected
		update_fog.emit(self,position, is_visible)

''' Cost Vars '''
var pop_cost := 0
var res_cost := {"wood": 0,
"stone": 0,
"riches": 10,
"crystals": 10,
"food": 0}

''' Derived and assigned Combat vars '''
@onready var max_health : float = base_health ##max health after any modifiers
@onready var health : float = max_health :## active health after any modifiers
	set(value):
		health = clampf(value,-1,max_health)
@onready var armor : float = base_armor ## base armor after modifers
@onready var m_dmg_var : float = m_attack_damage_variance ## base armor after modifers
@onready var r_atk_sprd : float = r_attack_attack_spread ## base armor after modifers
@onready var current_atk_str : float = base_atk_str  #with modifiers
@onready var current_atk_spd : float = base_atk_spd:  #with modifiers
	set(value):
		current_atk_spd = value
		atk_timer.start(current_atk_spd)
var projectile_arc
var attack_method : Callable # method to attack with
var target_enemy:
	set(value):
		target_enemy = value
		if(value != null):
			atk_timer.start(current_atk_spd)
			if(!target_enemy.died.is_connected(target_killed)):
				target_enemy.died.connect(target_killed)
		else:
			atk_timer.stop()
var visible_enemies := []
var visible_allies := []

''' On-Ready Vars '''
@onready var fog_reg = get_node("Fog_Breaker")
@onready var grnd_ping = get_node("Ground_Checker")
@onready var det_area = get_node("Detection_Area")
## Combat vars
@onready var atk_timer := get_node("Attack_Timer")
## Navigation vars
@onready var nav_agent: NavigationAgent3D = get_node("NavigationAgent3D")
@onready var unit_radius = $CollisionShape3D.shape.get_radius()
@onready var target_speed: int = max_speed

'''### Built-In Methods ###'''
func _ready():
	## Set Navigation Layer base don movement type
	for t in range(travel_type.size()):
		if travel_type[t]:
			nav_agent.set_navigation_layers(t+1)
	## Set navigation information
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	## Connect signals
	nav_agent.waypoint_reached.connect(waypoint)
	atk_timer.timeout.connect(_attack)
	
	## Set attack type
	if is_ranged:
		attack_method = Callable(__ranged_attack)
		var proj = load("res://Parent_Scenes/Projectile_Arc.tscn").instantiate()
		add_child(proj)
		projectile_arc = proj
	else:
		attack_method = Callable(__melee_attack)

func _physics_process(delta):
	if(is_queued_for_deletion()):
		return
	ai_methods[ai_mode].call(delta)

'''### Public Methods ###'''
''' Startup Methods Start '''
## Load data from owning building
func load_data(data):	
	pop_cost = data["pop_cost"]
	for r in data["base_cost"]:
		res_cost[r] = data["base_cost"][r]
	
	## set meta data
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
	


''' Startup Methods End '''
'''-------------------------------------------------------------------------------------'''
''' Movement Methods Start '''
## Set target move location
##
## Called by outside functions
func set_mov_target(mov_tar: Vector3):
	_set_target_position(mov_tar)
	ai_mode = "traveling_basic"


## Set folowing units
func set_following(units):
	followers = units
	for i in units:
		if(i != self):
			i.target_follow = self


## Add folowing units
func add_following(unit):
	if(followers.has(unit)):
		return
	followers.push_back(unit)
	## Stop signal connection overloading
	if(!unit.died.is_connected(remove_following)):
		unit.died.connect(remove_following.bind(unit))
	unit.target_follow = self
	unit.ai_mode = "follow_basic"
	if(target_enemy != null):
		unit.target_enemy = target_enemy


## Remove following unit
func remove_following(unit):
	if(followers.has(unit)):
		followers.erase(unit)
		unit.target_follow = null
		unit.ai_mode=ai_mode
	else:
		unit.died.disconnect(remove_following)


func clear_following():	
	if followers.size() > 0:
		for i in followers:
			remove_following(i)
			i._set_target_position(position)
	followers.clear()


# Get gound depth at certain point
func get_ground_depth(pos = null):
	grnd_ping.enabled = true
	if(pos !=null):
		grnd_ping.position = Vector3(pos.x+position.x,250,pos.z+position.z)
	grnd_ping.force_raycast_update()
	var out =  grnd_ping.get_collision_point().y
	grnd_ping.position = Vector3(0,250,0)	## Reset to on unit
	update_fog.emit(self,position, is_visible)
	grnd_ping.enabled = false
	return out


''' Movement Methods End '''
## Check target position for other units
func check_pos(pos):
	var new_pos = pos
	for i in unit_list:
		if i == self:
			pass
		elif (i.position.distance_to(new_pos) <= unit_radius):
			new_pos = check_pos(new_pos + Vector3(rng.randf_range(-1.25,1.25),0,rng.randf_range(-1.25,1.25)))
	return new_pos


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
		clear_following()
		died.emit()
		delayed_delete()
		return true
	return false


## Declares enemy
func declare_enemy(unit):
	ai_mode = "attack_commanded"
	target_enemy = unit
	if(target_follow == null):
		_set_target_position(unit.position)


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
	actor_owner.units.erase(self)
	actor_owner.update_pop()
	unit_list.erase(self)
	await get_tree().physics_frame
	queue_free()


''' Destroy Unit Methods End '''
'''-------------------------------------------------------------------------------------'''
'''### Private Methods ###'''
''' Movement Methods Start '''
## set target move location 
func _set_target_position(mov_tar: Vector3):
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
	if(area.has_meta("fog_owner_id") and area.get_meta("fog_owner_id") == 0):
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
	if area.has_meta("building_area") and area.get_parent().actor_owner.actor_ID == actor_owner.actor_ID:
		visible_enemies.push_back(area.get_parent())


## Remove buildings from  sight array
func _vision_area_exited(area):
	if area.has_meta("building_area") and area.get_parent().actor_owner.actor_ID == actor_owner.actor_ID:
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
	if (position.distance_to(target_enemy.position) > target_atk_rng):
		return
	
	## Temporasry Code for attack visualization
	$UnitModels/attack_indicator_temp.visible = true
	
	atk_timer.start(base_atk_spd + rng.randf_range(-.15,.15))
	attack_method.call()
	attacked.emit()
	await get_tree().create_timer(.25).timeout
	$UnitModels/attack_indicator_temp.visible = false

## ranged attack callable
func __ranged_attack():
	var dis = position.distance_to(target_enemy.position)
	projectile_arc.fire(position+Vector3.UP*3, target_enemy.position, dis, current_atk_str, "physical")

## melee attack callable
func __melee_attack():
	var variance = rng.randf_range(-current_atk_str*m_dmg_var,current_atk_str*m_dmg_var)
	target_enemy.damage(current_atk_str+variance,"physical")


''' Combat Methods End '''
'''-------------------------------------------------------------------------------------'''
''' AI Processes  Methods Start '''
## Has a target set by player
func _targeted_attack(delta):
	# Attack targeting
	if !is_instance_valid(target_enemy):
		return
	
	## Handle tracking target
	if(position.distance_to(target_enemy.position) <= target_atk_rng):
		if nav_agent.is_navigation_finished():
			var trgt = position.direction_to(target_enemy.position)
			var lookdir = atan2(-trgt.x, -trgt.z)
			$UnitModels.rotation.y = lerp($UnitModels.rotation.y, lookdir, 0.1)
			return
		_set_target_position(position)
	else:
		_set_target_position(target_enemy.position)
	_travel(delta)
	

## Travel to target location
func _traveling_basic(delta):
	_travel(delta)


## follow friendly unit
func _following(delta):
	_set_target_position(target_follow.position)
	_travel(delta)
	
	if(target_enemy !=null and visible_enemies.has(target_enemy)):
		ai_mode = "attack_commanded"
		


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
	_travel(delta)


## Move on process
func _travel(delta):
	if nav_agent.is_navigation_finished():
		return
	
	update_fog.emit(self,position, is_visible)
	var current_agent_position: Vector3 = global_transform.origin
	var next_path_position: Vector3 = nav_agent.get_next_path_position()
	var new_velocity: Vector3 = next_path_position - current_agent_position
	#Accelerate and decelerrate
	if nav_agent.distance_to_target() > intial_path_dist*.1 or nav_agent.distance_to_target() > 3:
		new_velocity = _lerp_start(new_velocity, delta)
	else:
		new_velocity = _lerp_stop(new_velocity, delta)
	
	# Look in walk direction
	var lookdir = atan2(-new_velocity.x, -new_velocity.z)
	$UnitModels.rotation.y = lerp($UnitModels.rotation.y, lookdir, 0.25)
	
	set_velocity(new_velocity)	
	move_and_slide()


func _on_navigation_agent_3d_navigation_finished():
	## Don't stop on other units
	var targ = check_pos(position)
	if(targ.is_equal_approx(position) == false):
		_set_target_position(targ)
	elif(ai_mode.contains("travel")):
		ai_mode = "idle_aggressive"
	clear_following()


func _on_NavigationAgent_velocity_computed(_safe_velocity):
	#velocity = safe_velocity
	move_and_slide()


## Reaches waypoint
func waypoint(_details):
	if followers.size() > 0:
		for i in followers:
			if(!is_instance_valid(i)):
				followers.erase(i)
				continue
			i._set_target_position(nav_agent.get_next_path_position())


''' AI Processes Methods End '''
