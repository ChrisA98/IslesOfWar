extends Building

@onready var valid_radius = $Valid_Region
@onready var radius = 30

func _ready():
	super()
	hide_radius()
	type = "Main"


func preview_radius():
	valid_radius.visible = false

func hide_radius():
	valid_radius.visible = false
