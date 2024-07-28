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
	var ext : String	
	## Account for remap extension
	if OS.has_feature("editor"):
		ext = ".tscn"
	else:
		ext = ".tscn.remap"
	match declared_faction:
		factions.AMERULF:
			if !FileAccess.file_exists("res://Assets/Models/Amerulf/scene_files/"+get_parent().type.to_lower()+"_am"+ext):
				push_error("no model file for Amerulf for building: "+get_parent().type)
				building_model_scn = load("res://Parent_Scenes/Building_Model.tscn")
			else:
				building_model_scn = load("res://Assets/Models/Amerulf/scene_files/"+get_parent().type.to_lower()+"_am.tscn")
		factions.TYRGWIS:
			if !FileAccess.file_exists("res://Assets/Models/Tyrgwis/scene_files/"+get_parent().type.to_lower()+"_ty"+ext):
				push_error("no model file for Tyrgwis for building: "+get_parent().type)
				building_model_scn = load("res://Parent_Scenes/Building_Model.tscn")
			else:
				building_model_scn = load("res://Assets/Models/Tyrgwis/scene_files/"+get_parent().type.to_lower()+"_ty.tscn")
		factions.CRIMELORD:
			if !FileAccess.file_exists("res://Assets/Models/CrimeLord/scene_files/"+get_parent().type.to_lower()+"_cl"+ext):
				push_error("no model file for Crimelords for building: "+get_parent().type)
				building_model_scn = load("res://Parent_Scenes/Building_Model.tscn")
			else:
				building_model_scn = load("res://Assets/Models/CrimeLord/scene_files/"+get_parent().type.to_lower()+"_cl.tscn")
	if building_model != null:
		building_model.free()
	building_model = building_model_scn.instantiate(0)
	add_child(building_model)
	return building_model
