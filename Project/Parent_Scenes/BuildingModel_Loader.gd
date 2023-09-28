@tool
extends Node3D


enum factions{AMERULF,TYRGWIS,CRIMELORD}

@export var declared_faction : factions:
	set(value):
		declared_faction = value
		if Engine.is_editor_hint():
			load_model()

var building_model:BuildingModel



##Load model scene
func load_model() -> BuildingModel:
	var building_model_scn
	match declared_faction:
		factions.AMERULF:
			if !FileAccess.file_exists("res://Assets/Models/Amerulf/scene_files/"+get_parent().type.to_lower()+"_am.tscn"):
				push_error("no model file for Amerulf for building: "+get_parent().type)
				building_model_scn = load("res://Parent_Scenes/Building_Model.tscn")
			else:
				building_model_scn = load("res://Assets/Models/Amerulf/scene_files/"+get_parent().type.to_lower()+"_am.tscn")
		factions.TYRGWIS:
			if !FileAccess.file_exists("res://Assets/Models/Tyrgwis/scene_files/"+get_parent().type.to_lower()+"_ty.tscn"):
				push_error("no model file for Tyrgwis for building: "+get_parent().type)
				building_model_scn = load("res://Parent_Scenes/Building_Model.tscn")
			else:
				building_model_scn = load("res://Assets/Models/Tyrgwis/scene_files/"+get_parent().type.to_lower()+"_ty.tscn")
		factions.CRIMELORD:
			if !FileAccess.file_exists("res://Assets/Models/CrimeLord/scene_files/"+get_parent().type.to_lower()+"_cl.tscn"):
				push_error("no model file for Crimelords for building: "+get_parent().type)
				building_model_scn = load("res://Parent_Scenes/Building_Model.tscn")
			else:
				building_model_scn = load("res://Assets/Models/CrimeLord/scene_files/"+get_parent().type.to_lower()+"_cl.tscn")
	if building_model != null:
		building_model.free()
	building_model = building_model_scn.instantiate(1)
	add_child(building_model)
	return building_model
