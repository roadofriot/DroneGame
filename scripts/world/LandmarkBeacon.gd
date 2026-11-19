class_name LandmarkBeacon
extends Node3D

## LandmarkBeacon: Luminous 1 km navigation waypoint tower (Phase 9).
## Placed deterministically at 1000m grid intervals (e.g. 1km, 2km, 3km)
## with high-visibility vertical beacon light for pilot visual orientation.

var grid_coord: Vector2i = Vector2i.ZERO
var true_world_position: Vector3 = Vector3.ZERO

func _init(p_grid: Vector2i = Vector2i.ZERO, p_true_pos: Vector3 = Vector3.ZERO) -> void:
	grid_coord = p_grid
	true_world_position = p_true_pos

func _ready() -> void:
	_build_beacon()
	_update_local_pos()

func _update_local_pos() -> void:
	if Engine.has_singleton("WorldOrigin"):
		var wo = Engine.get_singleton("WorldOrigin")
		position = wo.to_local(true_world_position)
	else:
		position = true_world_position

func _build_beacon() -> void:
	name = "Beacon_%d_%d" % [grid_coord.x, grid_coord.y]

	# 1. Base Concrete Pylon (4m wide, 6m tall)
	var base_mesh = BoxMesh.new()
	base_mesh.size = Vector3(4.0, 6.0, 4.0)
	var base_mat = StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.25, 0.28, 0.32)
	base_mesh.material = base_mat

	var base_inst = MeshInstance3D.new()
	base_inst.mesh = base_mesh
	base_inst.position = Vector3(0.0, 3.0, 0.0)
	add_child(base_inst)

	# 2. Main Lattice Mast (1.2m wide, 34m tall)
	var mast_mesh = BoxMesh.new()
	mast_mesh.size = Vector3(1.2, 34.0, 1.2)
	var mast_mat = StandardMaterial3D.new()
	mast_mat.albedo_color = Color(0.85, 0.25, 0.15) # Safety orange/white stripes
	mast_mesh.material = mast_mat

	var mast_inst = MeshInstance3D.new()
	mast_inst.mesh = mast_mesh
	mast_inst.position = Vector3(0.0, 23.0, 0.0)
	add_child(mast_inst)

	# 3. Glowing Strobe Lantern Top (40m elevation)
	var lantern_mesh = SphereMesh.new()
	lantern_mesh.radius = 1.6
	lantern_mesh.height = 3.2
	var lantern_mat = StandardMaterial3D.new()
	lantern_mat.albedo_color = Color(0.2, 0.9, 1.0)
	lantern_mat.emission_enabled = true
	lantern_mat.emission = Color(0.2, 0.9, 1.0)
	lantern_mat.emission_energy_multiplier = 4.5
	lantern_mesh.material = lantern_mat

	var lantern_inst = MeshInstance3D.new()
	lantern_inst.mesh = lantern_mesh
	lantern_inst.position = Vector3(0.0, 40.0, 0.0)
	add_child(lantern_inst)

	# 4. Vertical Light Beam (semi-transparent emissive cylinder)
	var beam_mesh = CylinderMesh.new()
	beam_mesh.top_radius = 2.5
	beam_mesh.bottom_radius = 0.8
	beam_mesh.height = 80.0
	var beam_mat = StandardMaterial3D.new()
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.albedo_color = Color(0.2, 0.85, 1.0, 0.25)
	beam_mat.emission_enabled = true
	beam_mat.emission = Color(0.2, 0.85, 1.0)
	beam_mat.emission_energy_multiplier = 2.0
	beam_mesh.material = beam_mat

	var beam_inst = MeshInstance3D.new()
	beam_inst.mesh = beam_mesh
	beam_inst.position = Vector3(0.0, 80.0, 0.0)
	add_child(beam_inst)
