extends Node3D


# enemy id (0 for player spawn)
# -1 for generic
@export var actor_id : int

## spawner has been used
var used = false:
	set(value):
		if value:
			free()


# Called when the node enters the scene tree for the first time.
func _ready():
	$debug_mesh.hide()

