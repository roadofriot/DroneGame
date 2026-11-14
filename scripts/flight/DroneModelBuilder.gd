class_name DroneModelBuilder
extends RefCounted

## DroneModelBuilder: Procedural 3D Quadcopter Generator.
## Synthesizes complete high-fidelity drone visual hierarchies at runtime from a DroneSpec.
## Uses strictly Godot built-in primitives (BoxMesh, CylinderMesh, SphereMesh) and
## StandardMaterial3D shaders with ZERO external binary assets.

const DroneSpec = preload("res://scripts/flight/DroneSpec.gd")

## Builds the visual node tree under target_parent from spec.
## Returns a Dictionary with references to animatable sub-nodes.
static func build_drone(target_parent: Node3D, spec: DroneSpec) -> Dictionary:
	if not target_parent or not spec:
		return {}

	# Remove any existing visual nodes with name "ProceduralDroneModel"
	var existing = target_parent.get_node_or_null("ProceduralDroneModel")
	if existing:
		existing.queue_free()
		target_parent.remove_child(existing)

	var root = Node3D.new()
	root.name = "ProceduralDroneModel"
	target_parent.add_child(root)

	# Shared Materials
	var mat_body = _create_material(spec.body_color, 0.35, 0.65) # Matte carbon look
	var mat_front_arm = _create_material(spec.front_accent_color, 0.4, 0.5) # Front accent
	var mat_rear_arm = _create_material(spec.rear_color, 0.35, 0.65) # Rear carbon
	var mat_motor = _create_material(Color(0.25, 0.26, 0.28, 1.0), 0.85, 0.25) # Metallic gunmetal
	var mat_prop = _create_material(spec.prop_color, 0.2, 0.3)
	var mat_lens = _create_material(Color(0.05, 0.08, 0.15, 1.0), 0.95, 0.05) # Glossy camera glass
	var mat_battery = _create_material(Color(0.18, 0.18, 0.20, 1.0), 0.2, 0.7)

	# Emissive LED Materials
	var mat_led_front = _create_emissive_material(spec.led_front_color, 3.0)
	var mat_led_port = _create_emissive_material(spec.led_port_color, 2.5)
	var mat_led_starboard = _create_emissive_material(spec.led_starboard_color, 2.5)
	var mat_status_led = _create_emissive_material(Color(0.2, 0.9, 0.3, 1.0), 3.5) # Default armed green
	var mat_bat_strip = _create_emissive_material(Color(0.1, 0.7, 1.0, 1.0), 2.0)

	# 1. Main Fuselage / Chassis
	var chassis_box = MeshInstance3D.new()
	chassis_box.name = "ChassisMain"
	var c_mesh = BoxMesh.new()
	c_mesh.size = spec.body_size
	chassis_box.mesh = c_mesh
	chassis_box.material_override = mat_body
	root.add_child(chassis_box)

	# Top Carbon Plate
	var top_plate = MeshInstance3D.new()
	top_plate.name = "TopPlate"
	var tp_mesh = BoxMesh.new()
	tp_mesh.size = Vector3(spec.body_size.x * 0.85, 0.004, spec.body_size.z * 1.05)
	top_plate.mesh = tp_mesh
	top_plate.position = Vector3(0.0, spec.body_size.y * 0.5 + 0.002, 0.0)
	top_plate.material_override = mat_body
	root.add_child(top_plate)

	# Battery Pack on Top
	var battery_box = MeshInstance3D.new()
	battery_box.name = "BatteryPack"
	var b_mesh = BoxMesh.new()
	b_mesh.size = Vector3(spec.body_size.x * 0.65, spec.body_size.y * 0.55, spec.body_size.z * 0.55)
	battery_box.mesh = b_mesh
	battery_box.position = Vector3(0.0, spec.body_size.y * 0.5 + b_mesh.size.y * 0.5 + 0.004, -spec.body_size.z * 0.05)
	battery_box.material_override = mat_battery
	root.add_child(battery_box)

	# Battery LED Level Strip
	var bat_strip = MeshInstance3D.new()
	bat_strip.name = "BatteryLEDStrip"
	var bs_mesh = BoxMesh.new()
	bs_mesh.size = Vector3(b_mesh.size.x * 0.8, 0.003, 0.008)
	bat_strip.mesh = bs_mesh
	bat_strip.position = Vector3(0.0, b_mesh.size.y * 0.5 + 0.001, 0.0)
	bat_strip.material_override = mat_bat_strip
	battery_box.add_child(bat_strip)

	# 2. Four Angled Carbon Arms with Motor Bells
	var d = spec.arm_d
	var arm_coords = [
		Vector3(-d, 0.0, -d), # 0: FL (Front Left)
		Vector3(d, 0.0, -d),  # 1: FR (Front Right)
		Vector3(-d, 0.0, d),  # 2: RL (Rear Left)
		Vector3(d, 0.0, d)    # 3: RR (Rear Right)
	]

	var rotor_nodes: Array[Node3D] = []
	var blur_discs: Array[MeshInstance3D] = []
	var blade_meshes: Array[Node3D] = []

	var arm_thickness = maxf(0.012, spec.arm_length * 0.065)

	for i in range(4):
		var motor_pos = arm_coords[i]
		var is_front = (motor_pos.z < 0.0)

		# Arm Tube / Strut
		var arm = MeshInstance3D.new()
		arm.name = "Arm_%d" % i
		var a_mesh = BoxMesh.new()
		var arm_vec = motor_pos - Vector3.ZERO
		var arm_len = arm_vec.length()
		a_mesh.size = Vector3(arm_thickness, arm_thickness * 0.6, arm_len)
		arm.mesh = a_mesh
		arm.material_override = mat_front_arm if is_front else mat_rear_arm
		arm.position = motor_pos * 0.5
		arm.look_at_from_position(arm.position, motor_pos, Vector3.UP)
		root.add_child(arm)

		# Motor Mount Base & Bell
		var motor_bell = MeshInstance3D.new()
		motor_bell.name = "Motor_%d" % i
		var mb_mesh = CylinderMesh.new()
		mb_mesh.top_radius = arm_thickness * 0.95
		mb_mesh.bottom_radius = arm_thickness * 0.95
		mb_mesh.height = 0.02
		motor_bell.mesh = mb_mesh
		motor_bell.position = motor_pos + Vector3(0.0, 0.01, 0.0)
		motor_bell.material_override = mat_motor
		root.add_child(motor_bell)

		# Rotor Pivot (Rotates dynamically around Y)
		var rotor_pivot = Node3D.new()
		rotor_pivot.name = "RotorPivot_%d" % i
		rotor_pivot.position = motor_pos + Vector3(0.0, 0.022, 0.0)
		root.add_child(rotor_pivot)
		rotor_nodes.append(rotor_pivot)

		# Propeller Blades (2-Blade Aerodynamic Design)
		var blades_group = Node3D.new()
		blades_group.name = "Blades"
		var prop_rad = spec.prop_diameter * 0.5
		var blade_w = prop_rad * 0.18

		var b1 = MeshInstance3D.new()
		var b1_mesh = BoxMesh.new()
		b1_mesh.size = Vector3(blade_w, 0.002, prop_rad * 0.95)
		b1.mesh = b1_mesh
		b1.position = Vector3(0.0, 0.0, prop_rad * 0.45)
		b1.rotation.y = deg_to_rad(8.0)
		b1.material_override = mat_prop
		blades_group.add_child(b1)

		var b2 = MeshInstance3D.new()
		var b2_mesh = BoxMesh.new()
		b2_mesh.size = Vector3(blade_w, 0.002, prop_rad * 0.95)
		b2.mesh = b2_mesh
		b2.position = Vector3(0.0, 0.0, -prop_rad * 0.45)
		b2.rotation.y = deg_to_rad(-8.0)
		b2.material_override = mat_prop
		blades_group.add_child(b2)

		# Center Prop Nut
		var nut = MeshInstance3D.new()
		var nut_mesh = CylinderMesh.new()
		nut_mesh.top_radius = 0.005
		nut_mesh.bottom_radius = 0.007
		nut_mesh.height = 0.008
		nut.mesh = nut_mesh
		nut.material_override = mat_motor
		blades_group.add_child(nut)

		rotor_pivot.add_child(blades_group)
		blade_meshes.append(blades_group)

		# Propeller High-RPM Blur Disc (Translucent Spinning Disc)
		var blur_disc = MeshInstance3D.new()
		blur_disc.name = "BlurDisc"
		var bd_mesh = CylinderMesh.new()
		bd_mesh.top_radius = prop_rad
		bd_mesh.bottom_radius = prop_rad
		bd_mesh.height = 0.001
		blur_disc.mesh = bd_mesh
		var mat_blur = StandardMaterial3D.new()
		mat_blur.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_blur.albedo_color = Color(spec.prop_color.r, spec.prop_color.g, spec.prop_color.b, 0.35)
		mat_blur.roughness = 0.5
		blur_disc.material_override = mat_blur
		blur_disc.visible = false # Hidden until high RPM
		rotor_pivot.add_child(blur_disc)
		blur_discs.append(blur_disc)

		# Landing Leg / Foot under each motor
		var leg = MeshInstance3D.new()
		leg.name = "Leg_%d" % i
		var l_mesh = CylinderMesh.new()
		l_mesh.top_radius = 0.004
		l_mesh.bottom_radius = 0.005
		l_mesh.height = 0.035
		leg.mesh = l_mesh
		leg.position = motor_pos + Vector3(0.0, -0.02, 0.0)
		leg.material_override = mat_body
		root.add_child(leg)

	# 3. Camera Pod & Gimbal Mount
	var gimbal_node: Node3D = null
	if spec.has_camera_pod:
		gimbal_node = Node3D.new()
		gimbal_node.name = "CameraGimbal"
		gimbal_node.position = Vector3(0.0, -0.005, -spec.body_size.z * 0.52)
		root.add_child(gimbal_node)

		var cam_body = MeshInstance3D.new()
		cam_body.name = "CameraHousing"
		var cb_mesh = BoxMesh.new()
		cb_mesh.size = Vector3(0.032, 0.028, 0.032)
		cam_body.mesh = cb_mesh
		cam_body.material_override = mat_body
		gimbal_node.add_child(cam_body)

		var cam_lens = MeshInstance3D.new()
		cam_lens.name = "CameraLens"
		var cl_mesh = CylinderMesh.new()
		cl_mesh.top_radius = 0.011
		cl_mesh.bottom_radius = 0.011
		cl_mesh.height = 0.01
		cam_lens.mesh = cl_mesh
		cam_lens.rotation.x = deg_to_rad(90.0)
		cam_lens.position = Vector3(0.0, 0.0, -0.016)
		cam_lens.material_override = mat_lens
		gimbal_node.add_child(cam_lens)

	# 4. Navigation & State LEDs
	# Front Headlights (White)
	var led_fl = _create_led_sphere("NavLED_Front_L", mat_led_front, Vector3(-spec.body_size.x * 0.45, 0.0, -spec.body_size.z * 0.52))
	var led_fr = _create_led_sphere("NavLED_Front_R", mat_led_front, Vector3(spec.body_size.x * 0.45, 0.0, -spec.body_size.z * 0.52))
	root.add_child(led_fl)
	root.add_child(led_fr)

	# Rear Position Lights (Port Red, Starboard Green)
	var led_rl = _create_led_sphere("NavLED_Rear_Port", mat_led_port, Vector3(-spec.body_size.x * 0.45, 0.0, spec.body_size.z * 0.52))
	var led_rr = _create_led_sphere("NavLED_Rear_Starboard", mat_led_starboard, Vector3(spec.body_size.x * 0.45, 0.0, spec.body_size.z * 0.52))
	root.add_child(led_rl)
	root.add_child(led_rr)

	# Center/Rear Flight State Beacon LED
	var state_led = _create_led_sphere("StateBeaconLED", mat_status_led, Vector3(0.0, spec.body_size.y * 0.5 + 0.015, spec.body_size.z * 0.45), 0.012)
	root.add_child(state_led)

	# 5. Dynamic Ground Contact Shadow (Soft Decal-style Mesh)
	var shadow_disc = MeshInstance3D.new()
	shadow_disc.name = "ContactShadow"
	var sd_mesh = CylinderMesh.new()
	sd_mesh.top_radius = spec.arm_length * 0.95
	sd_mesh.bottom_radius = spec.arm_length * 0.95
	sd_mesh.height = 0.002
	shadow_disc.mesh = sd_mesh
	var mat_shadow = StandardMaterial3D.new()
	mat_shadow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_shadow.albedo_color = Color(0.0, 0.0, 0.0, 0.65)
	mat_shadow.roughness = 1.0
	shadow_disc.material_override = mat_shadow
	shadow_disc.position = Vector3(0.0, -0.045, 0.0)
	root.add_child(shadow_disc)

	return {
		"root": root,
		"rotors": rotor_nodes,
		"blur_discs": blur_discs,
		"blades": blade_meshes,
		"gimbal": gimbal_node,
		"state_led": state_led,
		"mat_state_led": mat_status_led,
		"contact_shadow": shadow_disc,
		"spec": spec
	}

static func _create_material(col: Color, rough: float, metal: float) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = rough
	mat.metallic = metal
	return mat

static func _create_emissive_material(col: Color, energy: float) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = energy
	return mat

static func _create_led_sphere(node_name: String, mat: StandardMaterial3D, pos: Vector3, radius: float = 0.008) -> MeshInstance3D:
	var led = MeshInstance3D.new()
	led.name = node_name
	var s_mesh = SphereMesh.new()
	s_mesh.radius = radius
	s_mesh.height = radius * 2.0
	led.mesh = s_mesh
	led.position = pos
	led.material_override = mat
	return led
