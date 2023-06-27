@tool
extends Path3D

signal arc_changed

@export_range(0.001,10) var travel_speed : float
@export var _range : float:
	set(value):
		_range = value
		arc_changed.emit()
@export var arc_height: float:
	set(value):
		arc_height = value
		arc_changed.emit()
@export var play: bool
@export var direction : Vector3

@onready var speed = travel_speed
@onready var prog = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Engine.is_editor_hint() and play:
		$PathFollow3D.progress_ratio += (travel_speed/10*delta)
		if($PathFollow3D.progress_ratio >= .95):
			$PathFollow3D/GPUParticles3D.emitting = true
		else:
			$PathFollow3D/GPUParticles3D.emitting = false
			

func generate_arc():
	var lookdir = atan2(-direction.x, -direction.z)
	rotation.y = lookdir
	curve.clear_points()
	for i in range(5):
		var _in = Vector3(_range*((i-1)/PI),sin(i)*arc_height,0)
		var pos = Vector3(_range*((i)/PI),sin(i)*arc_height,0)
		var _out = Vector3(_range*((i+1)/PI),sin(i)*arc_height,0)
		curve.add_point(pos,_in,_out)
