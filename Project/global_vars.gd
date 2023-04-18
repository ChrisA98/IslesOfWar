extends Node

#Global Vars
@onready var months = {
	0: "Lidrasin Bor",
	1: "Spereran Mal",
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
const DAY_LENGTH : int = 300
const NIGHT_LENGTH : int = 240

func month_to_string(yr_day: int, yr: int) -> String:
	var out = ""
	var month_day = (yr_day%28)+1
	match month_day:
		1:
			out += str(month_day)+"st, "
		2:
			out += str(month_day)+"nd, "
		3:
			out += str(month_day)+"rd, "
		_:
			out += str(month_day)+"th, "
	out += (months[yr_day/28])
	out += (", "+str(yr)+" E2")
	return out
