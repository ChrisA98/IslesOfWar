extends Building

@onready var valid_radius = $Valid_Region
@onready var radius = 30

func _ready():
	super()
	type = "Main"
	pop_mod = 5

func place():
	super()
	hide_radius()


func preview_radius():
	valid_radius.visible = true

func hide_radius():
	valid_radius.visible = false
