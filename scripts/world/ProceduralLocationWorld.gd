class_name ProceduralLocationWorld
extends Node3D

## ProceduralLocationWorld: Generates a deterministic, seeded 3D flight environment
## from real-world geographical coordinates with helipad spawn, telemetry banner, and flight obstacles.

@export var location_name: String = "Custom Location"
@export var latitude: float = 27.7006
@export var longitude: float = 83.4484
@export var elevation_m: float = 150.0

var location_banner_text: String = ""

@onready var quadcopter: FlightPhysics = $Quadcopter
@onready var flight_hud: FlightHUD = $FlightHUD
@onready var mission_overlay: MissionOverlay = $FlightHUD/MissionOverlay
@onready var terrain_mesh_inst: MeshInstance3D = $EnvironmentGeometry/GroundStatic/GroundMesh

func _ready() -> void:
	_configure_location(latitude, longitude, location_name, elevation_m)

func _configure_location(lat: float, lon: float, loc_name: String, elev: float) -> void:
	latitude = lat
	longitude = lon
	location_name = loc_name
	elevation_m = elev

	# Generate seeded procedural terrain elevation
	_generate_seeded_terrain(lat, lon, elev)

	# Update HUD banner to explicitly label this as an approximate training world
	location_banner_text = "APPROXIMATE WORLD: %s [%.4f°N, %.4f°E, %.0fm] — PROCEDURAL TRAINING" % [loc_name.to_upper(), lat, lon, elev]
	if flight_hud and flight_hud.label_state_banner:
		flight_hud.label_state_banner.text = location_banner_text
		flight_hud.label_state_banner.visible = true

func _generate_seeded_terrain(lat: float, lon: float, elev: float) -> void:
	if not terrain_mesh_inst:
		return

	var terrain_seed = int(absf(lat * 1000.0) + absf(lon * 1000.0))
	var noise = FastNoiseLite.new()
	noise.seed = terrain_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.015

	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(240, 240)
	plane_mesh.subdivide_width = 32
	plane_mesh.subdivide_depth = 32

	var mat = StandardMaterial3D.new()
	if elev > 2000.0:
		# Alpine rock / snow
		mat.albedo_color = Color(0.45, 0.48, 0.52)
		mat.roughness = 0.9
	elif elev > 500.0:
		# Mountain valley green
		mat.albedo_color = Color(0.18, 0.32, 0.18)
		mat.roughness = 0.85
	else:
		# Subtropical valley green
		mat.albedo_color = Color(0.22, 0.38, 0.22)
		mat.roughness = 0.8

	plane_mesh.material = mat
	terrain_mesh_inst.mesh = plane_mesh
