extends Node3D

@onready var world = get_parent().get_parent()
@onready var building = $Building_Base
@onready var rally = $Building_Base/RallyPoint
@onready var spawn = $Building_Base/SpawnPoint
var units = [preload("res://Units/Infantry.tscn")]

# Called when the node enters the scene tree for the first time.
func _ready():
	building.type = "Barracks"


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func use(unit):
	var new_unit = units[0].instantiate()
	world.spawn_unit(new_unit)
	new_unit.position = spawn.global_position
	new_unit.get_children()[0].set_mov_target(rally.global_position)
