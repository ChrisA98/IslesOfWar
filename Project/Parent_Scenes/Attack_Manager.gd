extends Node

enum attack_type{MELEE, RANGE_PROJ, RANGE_AREA, RANGE_BEAM, LOCKED_RANGE_PROJ, LOCKED_RANGE_AREA }

@export var vertical_fire_offset := 3
@export var forward_fire_offset := 2

var main_attack_type : attack_type	## Is a ranged attacker
var attack_method : Callable # method to attack with
var projectile_manager
var ranged_atk_sprd
var melee_dmg_var
var damage_type

var collision_exceptions := []


## Pepepare with data from initializing node node
func init(_attack_type, _ranged_atk_sprd, _melee_dmg_var, _damage_type, proj_data = null):
	if !is_node_ready():
		await ready
	ranged_atk_sprd = _ranged_atk_sprd
	damage_type = _damage_type
	melee_dmg_var = _melee_dmg_var
	## Set attack type
	match _attack_type:
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
		attack_type.LOCKED_RANGE_AREA:
			## Attack targets area and deals damage directly to target enemy from range
			attack_method = Callable(__ranged_area_attack)
		attack_type.LOCKED_RANGE_PROJ:
			## Preprocessed arc projectile is used
			attack_method = Callable(__ranged_proj_attack)
			projectile_manager = load("res://Parent_Scenes/Projectile_Arc.tscn")
	


## Call attack method
func attack(position, target_enemy, current_atk_str):
	attack_method.call(position, target_enemy, current_atk_str)


func set_collision_exception(arr: Array):
	collision_exceptions = arr.duplicate()


func add_collision_exception(ex):
	collision_exceptions.push_back(ex)
'''-------------------------------------------------------------------------------------'''
''' Combat Methods Start '''
## Ranged projectile attack callable
func __ranged_proj_attack(position, target_enemy, current_atk_str):
	var dis = position.distance_to(target_enemy.position)
	var shot = projectile_manager.instantiate()
	shot.collision_exceptions = collision_exceptions
	var variance = Vector3(randf_range(-ranged_atk_sprd,ranged_atk_sprd),0,randf_range(-ranged_atk_sprd,ranged_atk_sprd))
	add_child(shot)
	shot.fire(position+Vector3.UP*vertical_fire_offset, target_enemy.position+variance, dis, current_atk_str, damage_type)


func __ranged_beam_attack(position, target_enemy, current_atk_str):
	var beam = projectile_manager.instantiate()
	if get_parent().has_user_signal("move_unlocked"):
		get_parent().move_unlocked.connect(beam.end_beam)
	target_enemy.died.connect(beam.end_beam)
	add_child(beam)
	beam.begin_firing(Vector3.UP - Vector3.MODEL_FRONT*forward_fire_offset, current_atk_str, damage_type, target_enemy.position - position)


## Ranged area attack callable
func __ranged_area_attack(_position, target_enemy, current_atk_str):
	if randf_range(0,.25) < ranged_atk_sprd:
		## Target missed with shot
		return
	## Do animation later
	target_enemy.damage(current_atk_str,damage_type)


## Melee attack callable
func __melee_attack(_position, target_enemy, current_atk_str):
	var variance = randf_range(-current_atk_str*melee_dmg_var,current_atk_str*melee_dmg_var)
	## Do animation later
	target_enemy.damage(current_atk_str+variance,damage_type)


''' Combat Methods End '''
'''-------------------------------------------------------------------------------------'''
