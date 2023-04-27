extends Node3D

@export var group : String
# enemy id (0 for player spawn)
@export var actor_id : int


# Called when the node enters the scene tree for the first time.
func _ready():
	$MeshInstance3D.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
