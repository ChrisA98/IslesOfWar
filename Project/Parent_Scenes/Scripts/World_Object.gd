extends Node3D

class_name world_object

#REF vars
@onready var area = get_node("Affected_Area")
@onready var area_shape = get_node("Affected_Area/CollisionShape3D")
@onready var editor_display_mesh = get_node("Editor_Mesh")

var radius: float:
	get:
		return radius
	set(value):
		radius = value
		_set_shape_radius(value)
@export var target_meta :StringName = "building_area"

# Called when the node enters the scene tree for the first time.
func _ready():
	#editor_display_mesh.hide()
	#Connect signals
	area.body_entered.connect(body_entered)
	area.area_shape_entered.connect(_area_entered)
	
	if(target_meta == null):
		area.monitoring = false


## Only should be called by radius setter
func _set_shape_radius(value):
	area_shape.shape.radius = value


## Object collides with area, checks for meta and returns if false
func body_entered(body: Node3D):
	if(!body.has_meta(target_meta)):
		return


## To be edited by inheritors, but natively checks if target has necassary meta data
func _area_entered(_area_rid, area, _area_shape_index, _local_shape_index):
	if(!area.has_meta(target_meta)):
		return
