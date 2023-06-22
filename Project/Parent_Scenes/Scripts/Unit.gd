class_name Unit_Base
extends CharacterBody3D

''' Signals '''
signal selected
signal died
signal update_fog
signal uncovered_area #area enters det area

'''Enums'''
enum {GROUND, NAVAL, AERIAL}

'''Consts'''

''' Export Vars '''
## Area this unit reveals fog in
@export var fog_rev_radius : float = 50

## Navigaion layers to enable
## 0 = GROUND
## 1 = NAVAL
## 2 = AERIAL
@export var travel_type := [false, false, false]
@export var unit_name: String

''' Movement '''
@export var max_speed = 10
@export var accel = 3
@export var deccel = 3

''' Export Combat vars '''
@export var health : float = 1
@export var base_atk_str : float = 10
@export var base_atk_spd : float = 1
@export var target_atk_rng : int = 5

var rng = RandomNumberGenerator.new()

''' Ai Controls '''
var ai_mode :StringName = "idle_basic"
var ai_methods : Dictionary = {
	"idle_basic" : Callable(_idling_basic),
	"traveling_basic" : Callable(_traveling_basic),
	"wandering_basic" : Callable(_wandering_basic),
	"attack_commanded" : Callable(_targeted_attack),
}
var intial_path_dist := 0.1
var followers: Array
var target_follow: Unit_Base:
	get:
		return target_follow
	set(value):
		if value == null:
			target_speed = max_speed
		else:
			target_speed = value.max_speed
		target_follow = value

''' Identifying Vars '''
var actor_owner
var unit_list

var is_selected: bool
var is_visible: bool:
	set(value):
		is_visible = value
		$CollisionShape3D.visible = is_visible
		$Selection.visible = is_visible
		update_fog.emit(self,position, is_visible)

''' Cost Vars '''
var pop_cost := 0
var res_cost := {"wood": 0,
"stone": 0,
"riches": 10,
"crystals": 10,
"food": 0}

''' Derived and assigned Combat vars '''
var current_atk_str : float #with modifiers
var current_atk_spd : float #with modifiers
var target_enemy:
	get:
		return target_enemy
	set(value):
		target_enemy = value
		if(value != null):
			if(!target_enemy.died.is_connected(target_killed)):
				target_enemy.died.connect(target_killed)
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
	for t in range(travel_type.size()):
		if travel_type[t]:
			nav_agent.set_navigation_layers(t+1)
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	
	nav_agent.waypoint_reached.connect(waypoint)
	atk_timer.timeout.connect(attack)
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
		is_visible = false
		det_area.area_entered.connect(_det_area_entered)
		det_area.area_exited.connect(_det_area_exited)

func _physics_process(delta):
	ai_methods[ai_mode].call(delta)

'''### Public Methods ###'''
''' Startup Methods Start '''
## Load data from owning building
func load_data(data):	
	pop_cost = data["pop_cost"]
	for r in data["base_cost"]:
		res_cost[r] = data["base_cost"][r]


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
	followers.push_back(unit)
	unit.target_follow = self
	unit.ai_mode = ai_mode
	if(target_enemy != null):
		unit.target_enemy = target_enemy


func clear_following():	
	if followers.size() > 0:
		for i in followers:
			i._set_target_position(position)
			i.target_follow = null
	followers.clear()


# Get gound depth at certain point
func get_ground_depth(pos = null):
	if(pos !=null):
		grnd_ping.position = Vector3(pos.x+position.x,250,pos.z+position.z)
	grnd_ping.force_raycast_update()
	var out =  grnd_ping.get_collision_point().y
	grnd_ping.position = Vector3(0,250,0)	## Reset to on unit
	update_fog.emit(self,position, is_visible)
	return out

''' Movement Methods End '''
## Check target position for other units
func check_pos(pos):
	var new_pos = pos
	for i in unit_list:
		if i == self:
			pass
		elif (i.position.distance_to(new_pos) <= unit_radius):
			new_pos = check_pos(new_pos + Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1)))
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
	$Selection.visible = state


#signal being selected on click
func _on_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and Input.is_action_just_released("lmb"):
		selected.emit(self, event)
		ai_mode = "wandering_basic"

''' Player Input Methods End '''
'''-------------------------------------------------------------------------------------'''
''' Combat Methods Start '''
## Damage dealt
##
## returns true if killed or false if survived
## type is for later implementation
func damage(amt: float, _type: String):
	health -= amt
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
	if(target_follow == null):
		_set_target_position(unit.position)


## Attack function
func attack():
	if is_instance_valid(target_enemy) == false:
		return
	atk_timer.start(base_atk_spd)
	target_enemy.damage(base_atk_str,"physical")

''' Combat Methods End '''
'''-------------------------------------------------------------------------------------'''
''' Destroy Unit Methods Start '''
## Signal from target dying
func target_killed():
	target_enemy = null
	atk_timer.stop()


## Delay delete and remove from lists
func delayed_delete():
	await get_tree().physics_frame
	actor_owner.units.erase(self)
	actor_owner.update_pop()
	unit_list.erase(self)
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


func _det_area_entered(area):
	uncovered_area.emit(self, area)
	if(area.has_meta("fog_owner_id")):
		if (area.get_meta("fog_owner_id") == 0):
			is_visible = true

func _det_area_exited(area):
	if(area.has_meta("fog_owner_id")):
		if (area.get_meta("fog_owner_id") == 0):
			is_visible = false
		for ar in area.get_overlapping_areas():
			if(ar.has_meta("fog_owner_id")):
				if (ar.get_meta("fog_owner_id") == 0):
					is_visible = true
			


''' Movement Methods end '''
'''-------------------------------------------------------------------------------------'''
''' AI Processes  Methods Start '''
## Has a target set by player
func _targeted_attack(delta):
	# Attack targeting
	if !is_instance_valid(target_enemy):
		return
	
	if(position.distance_to(target_enemy.position) <= target_atk_rng):
		if(nav_agent.is_navigation_finished() == false):
			_set_target_position(position)
			attack()
			_travel(delta)
			return
	else:
		_travel(delta)
		atk_timer.stop()
		return


func _traveling_basic(delta):
	_travel(delta)


func _idling_basic(_delta):
	pass


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
	$UnitModels.rotation.y = lookdir
	
	set_velocity(new_velocity)	
	move_and_slide()


func _on_navigation_agent_3d_navigation_finished():
	var targ = check_pos(position)
	if(targ.is_equal_approx(position) == false):
		_set_target_position(targ)
	elif(ai_mode.contains("travel") and target_follow==null):
		ai_mode = "idle_basic"
	clear_following()
	if target_follow != null:
		_set_target_position(target_follow.position)
		return


func _on_NavigationAgent_velocity_computed(_safe_velocity):
	#velocity = safe_velocity
	move_and_slide()


## Reaches waypoint
func waypoint(_details):
	if followers.size() > 0:
		for i in followers:
			i._set_target_position(nav_agent.get_next_path_position())

''' AI Processes Methods End '''
