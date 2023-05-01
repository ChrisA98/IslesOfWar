extends MeshInstance3D


# Called when the node enters the scene tree for the first time.
func _ready():
	var b_mesh = load("res://Models/Amerulf/Barracks_Am.obj")
	if(b_mesh != null):
		set_mesh(b_mesh)

