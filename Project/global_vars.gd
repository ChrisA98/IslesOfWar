extends Node

signal updated_heightmap

#Global Vars
@onready var months = {
	0: "Lidrasin Bor",
	1: "Sperran Mal",
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

var load_text = "Loading Something"

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


func push_nav_queue(nr : NavigationRegion3D):
	navmesh_baking = nr


func pop_nav_queue(nr : NavigationRegion3D):
	navmesh_baking = null
	queued_nav_bakes.erase(nr)
