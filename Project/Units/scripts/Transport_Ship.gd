extends Unit_Base


func _ready():
	super()
	ai_methods = {
	"idle_basic" : Callable(_idling_basic),
	"idle_aggressive" : Callable(_idling_defensive),
	"idle_defensive": Callable(_idling_defensive),
	"traveling_basic" : Callable(_traveling_basic),
	"wandering_basic" : Callable(_wandering_basic),
	"attack_commanded" : Callable(_traveling_basic),
	"garrison" : Callable(_garrisoning)
	}
