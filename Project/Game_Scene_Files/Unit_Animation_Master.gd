extends Node

var animation_trees : Array[AnimationTree]
var max_update_batch_size = 60

func _physics_process(delta):
	pass


## Add an array to end of trees array
func append_trees(trees: Array[AnimationTree]):
	for tre in trees:
		add_tree(tre)


## Remove an array of trees from list
func remove_array_of_trees(trees: Array[AnimationTree]):
	for tre in trees:
		remove_tree(tre)


## Add tree to be animated
func add_tree(tree: AnimationTree):
	if animation_trees.has(tree):
		return false
	animation_trees.push_back(tree)
	return true


## Remove tree from animation list
func remove_tree(tree: AnimationTree):
	animation_trees.erase(tree)

