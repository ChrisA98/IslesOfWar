extends Node3D

enum Node_type {NONE,FOREST,STONE,CRYSTAL}

var current_node : Node_type = Node_type.NONE
var spawn_function : Callable = Callable(_spawn_default)
var preview_node

func spawn_node():
	if preview_node != null:
		preview_node.queue_free()
		preview_node = null
	spawn_function.call()



""" Spawn node functions"""



## virtual spawn function
func _spawn_default():
	pass
	
	
## virtual spawn function
func _spawn_forest():
	preview_node = load("res://World_Objects/Forest.tscn").instantiate()
	add_child(preview_node)
