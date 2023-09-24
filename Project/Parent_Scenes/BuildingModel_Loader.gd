@tool
extends Node3D


enum factions{AMERULF,TYRGWIS,CRIMELORD}

@export var declared_faction : factions:
	set(value):
		declared_faction = value
		_load_model()

var building_model:BuildingModel

func _ready():
	call_deferred("_load_model")


func _load_model():
	var building_model_scn
	match declared_faction:
		factions.AMERULF:
			building_model_scn = load("res://Models/Amerulf/scene_files/"+get_parent().type.to_lower()+"_am.tscn")
		factions.TYRGWIS:
			building_model_scn = load("res://Models/Tyrgwis/scene_files/"+get_parent().type.to_lower()+"_ty.tscn")
		factions.CRIMELORD:
			building_model_scn = load("res://Models/CrimeLord/scene_files/"+get_parent().type.to_lower()+"_cl.tscn")
	if building_model != null:
		building_model.free()
	building_model = building_model_scn.instantiate()
	add_child(building_model)
