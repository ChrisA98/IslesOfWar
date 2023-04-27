extends game_actor


@onready var cam = get_node("Player_camera")

func _ready():
	super()
	actor_ID = 0


func set_cam_pos(pos: Vector3):
	cam.position = pos
