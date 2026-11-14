class_name DroneShowcase
extends Node3D

## DroneShowcase: Interactive 3D Turntable Studio for Visual Drone Inspection.
## Displays the 3 procedural drone presets (Scout, Photo, Racer) on illuminated pedestals
## with rotating turntables, dynamic prop spin, and status LED telemetry.

const DroneSpec = preload("res://scripts/flight/DroneSpec.gd")
const DroneModelBuilder = preload("res://scripts/flight/DroneModelBuilder.gd")

@export var rotation_speed_deg: float = 25.0
@export var auto_rotate: bool = true

var turntable_root: Node3D
var drone_nodes: Array[Dictionary] = []

func _ready() -> void:
	turntable_root = get_node_or_null("TurntableGroup")
	if not turntable_root:
		turntable_root = Node3D.new()
		turntable_root.name = "TurntableGroup"
		add_child(turntable_root)

	_setup_studio_lighting()
	_spawn_preset_drones()

func _setup_studio_lighting() -> void:
	if not get_node_or_null("WorldEnvironment"):
		var env_node = WorldEnvironment.new()
		env_node.name = "WorldEnvironment"
		var env = Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.06, 0.07, 0.09, 1.0)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.2, 0.22, 0.25, 1.0)
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.glow_enabled = true
		env.glow_bloom = 0.15
		env_node.environment = env
		add_child(env_node)

	if not get_node_or_null("KeyLight"):
		var light = DirectionalLight3D.new()
		light.name = "KeyLight"
		light.rotation_degrees = Vector3(-45, 35, 0)
		light.light_color = Color(1.0, 0.98, 0.95)
		light.light_energy = 1.2
		light.shadow_enabled = true
		add_child(light)

func _spawn_preset_drones() -> void:
	var presets = [
		{"path": "res://data/drones/scout.tres", "offset": Vector3(-0.9, 0.15, 0.0), "state": "FLYING"},
		{"path": "res://data/drones/photo.tres", "offset": Vector3(0.0, 0.15, 0.0), "state": "ARMED"},
		{"path": "res://data/drones/racer.tres", "offset": Vector3(0.9, 0.15, 0.0), "state": "FLIPPING"}
	]

	for item in presets:
		var spec: DroneSpec = load(item["path"])
		if not spec:
			continue

		# Pedestal Cylinder
		var pedestal = MeshInstance3D.new()
		pedestal.name = "Pedestal_" + spec.preset_id
		var p_mesh = CylinderMesh.new()
		p_mesh.top_radius = 0.28
		p_mesh.bottom_radius = 0.32
		p_mesh.height = 0.15
		pedestal.mesh = p_mesh
		var p_mat = StandardMaterial3D.new()
		p_mat.albedo_color = Color(0.12, 0.13, 0.15, 1.0)
		p_mat.roughness = 0.4
		p_mat.metallic = 0.8
		pedestal.material_override = p_mat
		pedestal.position = Vector3(item["offset"].x, 0.075, item["offset"].z)
		turntable_root.add_child(pedestal)

		# Drone Mount
		var mount = Node3D.new()
		mount.name = "DroneMount_" + spec.preset_id
		mount.position = item["offset"] + Vector3(0.0, 0.05, 0.0)
		turntable_root.add_child(mount)

		var data = DroneModelBuilder.build_drone(mount, spec)
		drone_nodes.append({"data": data, "state": item["state"]})

func _process(delta: float) -> void:
	if auto_rotate and turntable_root:
		turntable_root.rotate_y(deg_to_rad(rotation_speed_deg) * delta)

	# Animate Showcase Rotors & Lights
	var spin_speed = 18.0 # rad/s idle spin
	for entry in drone_nodes:
		var data = entry.get("data", {})
		var rotors = data.get("rotors", [])
		var dirs = [-1.0, 1.0, 1.0, -1.0]
		for i in range(mini(4, rotors.size())):
			var r: Node3D = rotors[i]
			if r:
				r.rotate_y(dirs[i] * spin_speed * delta)
