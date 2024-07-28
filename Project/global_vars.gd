extends Node

signal updated_heightmap

#Global Vars
@onready var months = {
	0: "Lidrasin Bor",
	1: "Speran Mal",
	2: "Lidras Veil",
	3: "Sultaran Bor",
	4: "Dariusun Fil",
	5: "Sultas Veil",
	6: "Althuran Bor",
	7: "Corvusan Mal",
	8: "Althurs Veil",
	9: "Arcfeian Bor",
	10: "Nilisin Fil",
	11: "Freias Veil",
	12: "Lidrasin Bor"
}
const YEAR_LENGTH : int = 336
const DAY_LENGTH : int = 74
const NIGHT_LENGTH : int = 46

var navmesh_baking : NavigationRegion3D
var queued_nav_bakes: Array
var nav_map : RID

var load_text = "Loading Something":
	set(value):
		load_text = value
		print(load_text)

var heightmap : Image = Image.new():
	set(value):
		heightmap = value
		updated_heightmap.emit()
var heightmap_size : int = 0
var water_elevation : float = 0

func month_to_string(yr_day: int, yr: int) -> String:
	var out = ""
	var month_day = (yr_day%28)+1
	match month_day:
		1:
			out += str(month_day)+"st, "
		21:
			out += str(month_day)+"st, "
		2:
			out += str(month_day)+"nd, "
		22:
			out += str(month_day)+"nd, "
		3:
			out += str(month_day)+"rd, "
		23:
			out += str(month_day)+"rd, "
		_:
			out += str(month_day)+"th, "
	@warning_ignore("integer_division")out += (months[round(yr_day/28)])
	out += (", "+str(yr)+" E2")
	return out


## Take String month and day of month to return day of year
func get_year_day(month:String, day:int):
	var out_day := 0
	match month:
		"Lidrasin Bor":
			out_day=0
		"Sperran Mal":
			out_day=29
		"Lidras Veil":
			out_day=56
		"Sultaran Bor":
			out_day=84
		"Dariusun Fil":
			out_day=112
		"Sultas Veil":
			out_day=140
		"Althuran Bor":
			out_day=168
		"Corvusan Mal":
			out_day=196
		"Althurs Veil":
			out_day=224
		"Arcfeian Bor":
			out_day=252
		"Nilisin Fil":
			out_day=280
		"Freias Veil":
			out_day=308
		"Lidrasin Bor":
			out_day=336
	out_day += day
	return out_day


func push_nav_queue(nr : NavigationRegion3D):
	navmesh_baking = nr


func pop_nav_queue(nr : NavigationRegion3D):
	navmesh_baking = null
	queued_nav_bakes.erase(nr)


func clear_nav_queue():
	navmesh_baking = null
	queued_nav_bakes.clear()
