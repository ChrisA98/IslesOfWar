extends ColorRect

var units
signal pressed

func _ready():
	gui_input.connect(clicked)


func init(_units):
	units = _units


func clicked():
	pressed.emit(self,units)
	
