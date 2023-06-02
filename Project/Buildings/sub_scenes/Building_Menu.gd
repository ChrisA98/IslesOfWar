extends Panel

@export var visible_pages = {"units_page": true,"research_page": true,"page_3": false,"page_4": false}

signal destory_building
signal upgrade_building
signal free_units

#Ref vars
@onready var unit_buttons = get_node("Building_Menu/Pages/ScrollContainer/VBoxContainer").get_children()

