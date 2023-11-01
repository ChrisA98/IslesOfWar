extends Node

var thread: Thread
var mutex: Mutex
var exit_thread := false

var chunk_textures : Array

# The thread will start here.
func _ready():
	mutex = Mutex.new()
	thread = Thread.new()
	# You can bind multiple arguments to a function Callable.
	#thread.start(_thread_function.bind("Wafflecopter"))
	
	
# Run here and exit.
# The argument is the bound data passed from start().
func _thread_function(userdata):
	var counter = 0
	while true:
		
		mutex.lock()
		var should_exit = exit_thread # Protect with Mutex.
		mutex.unlock()
		
		if should_exit:
			break


# Thread must be disposed (or "joined"), for portability.
func _exit_tree():
	thread.wait_to_finish()
