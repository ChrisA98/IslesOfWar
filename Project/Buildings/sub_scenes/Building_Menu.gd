extends Panel

signal push_train_queue
signal pop_train_queue
signal research_queue

#Ref vars
var visible_pages = {"units": false,"sec_units": false,"research": false,"page_4": false}
var unit_buttons := {}
var active_train
var active_res
var has_mouse: bool
var show: bool:
	set(value):
		show = value
		visible = value

func _ready():
	# bind page buttons
	for but in $Building_Menu/Page_Buttons.get_children():
		but.pressed.connect(switch_page.bind(but))
	
	$"Always_Buttons/Garrison Button".pressed.connect(get_parent().empty_garrison,CONNECT_DEFERRED)
	
	for i in get_children(true):
		i.mouse_entered.connect(set.bind("has_mouse",true))
		i.mouse_exited.connect(set.bind("has_mouse",false))


## Set menu base visibilities and data
func set_menu_data(bldg_name:String):	
	## hide unused pages
	for pag in visible_pages:
		if (get_parent().menu_pages[pag] != ""):
			visible_pages[pag] = true
		$Building_Menu/Page_Buttons.find_child(pag).visible = visible_pages[pag]
	
	$Building_Menu/Building_Label.text = "[center][b]"+bldg_name+"[/b][/center]"	#set building name


## Setup main units list
func build_unit_list(units: Array, _name: String, pg: int = 0):
	var cnt = 0
	if(pg == 0):
		$Building_Menu/Page_Buttons/units.text = _name
		visible_pages["units"] = true
	for u in units:
		var __t = get_node("Building_Menu/Pages/units_page_0/units_list/unit_box_"+str(cnt))
		var t = get_node("Building_Menu/Pages/units_page_"+str(pg)+"/units_list/unit_box_"+str(cnt))
		var nxt = t.duplicate(true)
		nxt.set_name("unit_box_"+str(cnt+1))
		nxt.visible=false
		t.add_sibling(nxt)	## make duplicate for next unit box
		t.visible = true
		t.get_child(1).get_child(0).text = u	## Set Text
		## Set increase decrease labels
		t.get_child(0).get_child(0).pressed.connect(unit_queue_edit.bind(1,u,true))
		t.get_child(0).get_child(2).pressed.connect(unit_queue_edit.bind(-1,u,true))
		
		unit_buttons[u] = t ## Link button to unit name		
		cnt+=1


func build_sec_unit_list(units: Array, _name: String):
	$Building_Menu/Page_Buttons/sec_units.text = _name
	var t = get_node("Building_Menu/Pages/units_page_0").duplicate(true)
	t.set_name("units_page_1")
	get_node("Building_Menu/Pages").add_child(t)
	visible_pages["sec_units"] = true
	await get_tree().physics_frame
	build_unit_list(units, _name, 1)


## Set menu page
func switch_page(page):	
	var t : int
	match page.name:
		"units":
			t = 0
		"sec_units":
			t = 1
		"research":
			t = 2
		"page_4":
			t = 3
	$Building_Menu/Pages.current_tab = t


## Emit queue changed signal and edit UI view
func unit_queue_edit(amt:int, unit:String, lcl = false):
	var unit_box = unit_buttons[unit]
	var n_amt = int(unit_box.get_child(0).get_child(1).text)+amt
	if(n_amt<0):
		return
	if(n_amt==0):
		unit_buttons[unit].get_child(2).value = 0
	unit_box.get_child(0).get_child(1).text = "[center]"+str(n_amt)+"[/center]"
	if (!lcl):
		return
	if(amt == 1):
		push_train_queue.emit(unit)
	else:
		pop_train_queue.emit(unit)
		

func update_train_prog(unit:String, amt:float):
	unit_buttons[unit].get_child(2).value = 100 - (amt*100)

