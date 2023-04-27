extends Building

@onready var valid_radius = $Valid_Region
@onready var radius = 30

func _ready():
	super()
	type = "Base"
	pop_mod = 5


func set_pos(pos):
	super(pos)
	get_node("Valid_Region/GPUParticles3D").restart()
	if near_base(actor_owner.bases):
		make_invalid()


func place():
	super()
	hide_radius()


func near_base(buildings) -> bool:
	if buildings == null:
		return false
	for b in buildings:
		if b == self:
			break
		if b.position.distance_to(position) < b.radius + radius:
			return true
	return false


func preview_radius():
	valid_radius.visible = true

func hide_radius():
	valid_radius.visible = false
