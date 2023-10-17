extends Control

var last_frame = 0
var active_quote = 0
var quotes = ["test1","test2","test3","test4"]
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	var nf = Time.get_ticks_msec()
	if nf - last_frame > 5000:
		if active_quote == quotes.size()-1:
			active_quote = 0
		else:
			active_quote += 1
		$load_screen/ColorRect/RichTextLabel.text = quotes[active_quote]
		last_frame = nf
		


func fade_in():
	visible = true
	$fade.visible = true
	$load_screen.visible = true
	$fade/AnimationPlayer.play("fade")
	
