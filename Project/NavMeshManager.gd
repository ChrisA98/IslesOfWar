extends NavigationRegion3D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func update_navigation_mesh():
	var on_thread: bool = true
	bake_navigation_mesh(on_thread)
	
	var _navigationmesh: NavigationMesh = navigation_mesh
	NavigationMeshGenerator.bake(_navigationmesh, self)
	navigation_mesh = null
	navigation_mesh = _navigationmesh
	
	var region_rid: RID = get_region_rid()
	NavigationServer3D.region_set_navigation_mesh(region_rid, navigation_mesh)
