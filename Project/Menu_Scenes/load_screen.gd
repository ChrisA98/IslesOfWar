extends Control

var last_frame = 0
var active_quote = 0
var quotes = ["test1","test2","test3","test4"]

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	$load_screen/ColorRect/RichTextLabel.text = Global_Vars.load_text


func fade_in():
	visible = true
	$fade.visible = true
	$load_screen.visible = true
	$fade/AnimationPlayer.play("fade")
	
