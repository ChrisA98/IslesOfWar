extends Control


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	RenderingServer.global_shader_parameter_set("game_time",Time.get_ticks_msec())


func fade_in():
	visible = true
	$fade.visible = true
	$load_screen.visible = true
	$fade/AnimationPlayer.play("fade")
	
