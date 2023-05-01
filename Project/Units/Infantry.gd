extends Unit_Base

func _ready():
	super()
	pop_cost = 1
	unit_name = "Infantry"
	res_cost["crystal"] = 5
	res_cost["riches"] = 10
