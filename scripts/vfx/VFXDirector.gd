class_name VFXDirector
extends Node3D

## VFXDirector: Particle effects manager for Quadcopter rotor wash ground dust,
## coin collection sparkles, gate pass ring flares, and crash debris puffs.

@export var target_drone: FlightPhysics

var rotor_wash_particles: CPUParticles3D
var ground_wash_active: bool = false

func _ready() -> void:
	_setup_rotor_wash()

func _setup_rotor_wash() -> void:
	rotor_wash_particles = CPUParticles3D.new()
	rotor_wash_particles.name = "RotorWashParticles"
	rotor_wash_particles.emitting = false
	rotor_wash_particles.amount = 32
	rotor_wash_particles.lifetime = 0.6
	rotor_wash_particles.explosiveness = 0.0
	rotor_wash_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	rotor_wash_particles.emission_ring_radius = 0.6
	rotor_wash_particles.emission_ring_inner_radius = 0.3
	rotor_wash_particles.direction = Vector3(0, 0.1, 0)
	rotor_wash_particles.spread = 180.0
	rotor_wash_particles.initial_velocity_min = 1.5
	rotor_wash_particles.initial_velocity_max = 3.2
	rotor_wash_particles.gravity = Vector3(0, -1.0, 0)
	rotor_wash_particles.scale_amount_min = 0.08
	rotor_wash_particles.scale_amount_max = 0.22
	rotor_wash_particles.color = Color(0.7, 0.65, 0.55, 0.4)

	var mesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	rotor_wash_particles.mesh = mesh

	add_child(rotor_wash_particles)

func _process(_delta: float) -> void:
	if not target_drone:
		return

	var alt = target_drone.altitude_agl
	var is_flying = (target_drone.current_state == FlightPhysics.DroneState.FLYING or target_drone.current_state == FlightPhysics.DroneState.TAKING_OFF)

	# Rotor wash ground effect active under 2.5 meters AGL
	if is_flying and alt < 2.5 and alt > 0.1:
		rotor_wash_particles.emitting = true
		var wash_intensity = 1.0 - (alt / 2.5)
		rotor_wash_particles.amount = int(12 + (wash_intensity * 28))
		rotor_wash_particles.initial_velocity_max = 2.0 + (wash_intensity * 3.0)

		# Position on ground directly under drone
		if is_inside_tree() and target_drone.is_inside_tree():
			var drone_pos = target_drone.global_position
			rotor_wash_particles.global_position = Vector3(drone_pos.x, drone_pos.y - alt + 0.05, drone_pos.z)
	else:
		rotor_wash_particles.emitting = false

func spawn_coin_pickup_vfx(world_pos: Vector3) -> void:
	var p = CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 20
	p.lifetime = 0.6
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.15
	p.color = Color(1.0, 0.85, 0.2, 0.9)

	var mesh = SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	p.mesh = mesh

	add_child(p)
	if is_inside_tree():
		p.global_position = world_pos
	else:
		p.position = world_pos
	p.emitting = true

	if is_inside_tree() and get_tree():
		get_tree().create_timer(1.0).timeout.connect(p.queue_free)

func spawn_gate_pass_vfx(gate_pos: Vector3, _gate_basis: Basis) -> void:
	var p = CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 35
	p.lifetime = 0.75
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_radius = 1.8
	p.emission_ring_inner_radius = 1.5
	p.spread = 45.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -2.0, 0)
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.2
	p.color = Color(0.1, 0.85, 1.0, 0.9)

	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	p.mesh = mesh

	add_child(p)
	if is_inside_tree():
		p.global_position = gate_pos
	else:
		p.position = gate_pos
	p.emitting = true

	if is_inside_tree() and get_tree():
		get_tree().create_timer(1.2).timeout.connect(p.queue_free)

func spawn_crash_vfx(impact_pos: Vector3, impact_force: float) -> void:
	var p = CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.98
	var count = int(clampf(impact_force * 6.0, 15, 60))
	p.amount = count
	p.lifetime = 0.8
	p.direction = Vector3(0, 1, 0)
	p.spread = 160.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = clampf(impact_force * 1.2, 3.0, 9.0)
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.25
	p.color = Color(0.4, 0.42, 0.45, 0.85)

	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, 0.08)
	p.mesh = mesh

	add_child(p)
	if is_inside_tree():
		p.global_position = impact_pos
	else:
		p.position = impact_pos
	p.emitting = true

	if is_inside_tree() and get_tree():
		get_tree().create_timer(1.5).timeout.connect(p.queue_free)
