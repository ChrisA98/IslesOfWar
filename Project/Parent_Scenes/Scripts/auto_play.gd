extends AnimationPlayer
## Simple script to make animation players start loop

@export var default_anim : String
@export var loop : bool

func _ready():
	play(default_anim)
	if loop:
		animation_finished.connect(loop_anim)

func loop_anim(anim_name):
	play(anim_name)
