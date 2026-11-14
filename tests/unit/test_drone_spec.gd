extends SceneTree

## Dedicated Unit Test Suite for DroneSpec, DroneModelBuilder & Procedural Presets (Phase 6)
## Validates derived physical metrics (inertia, arm_d, TWR), FlightController hover & sign checks,
## procedural mesh construction, prop blur disc toggling, and clean memory cleanup.

const DroneSpec = preload("res://scripts/flight/DroneSpec.gd")
const DroneModelBuilder = preload("res://scripts/flight/DroneModelBuilder.gd")
const FlightController = preload("res://scripts/flight/FlightController.gd")
const DroneRig = preload("res://scripts/flight/DroneRig.gd")
const ControlFrame = preload("res://scripts/input/ControlFrame.gd")

func _init() -> void:
	print("==================================================")
	print("Starting Phase 6 Drone Redesign & Spec Tests")
	print("==================================================")

	var tests_passed: int = 0
	var tests_total: int = 5

	if test_ds01_preset_physical_derivations():
		tests_passed += 1
	if test_ds02_flight_controller_hover_all_presets():
		tests_passed += 1
	if test_ds03_flight_controller_sign_tests_all_presets():
		tests_passed += 1
	if test_ds04_model_builder_hierarchy():
		tests_passed += 1
	if test_ds05_drone_rig_procedural_integration():
		tests_passed += 1

	print("==================================================")
	print("Phase 6 Test Results: %d / %d Passed" % [tests_passed, tests_total])
	print("==================================================")

	if tests_passed == tests_total:
		print(">> ALL PHASE 6 DRONE SPEC TESTS PASSED SUCCESSFULLY! <<")
		quit(0)
	else:
		printerr(">> PHASE 6 DRONE SPEC TESTS FAILED! <<")
		quit(1)

func test_ds01_preset_physical_derivations() -> bool:
	print("[DS-01] Testing DroneSpec Physical Derivations for Scout, Photo, Racer...")

	var presets = [
		{"path": "res://data/drones/scout.tres", "expected_twr_min": 2.4, "expected_twr_max": 2.9},
		{"path": "res://data/drones/photo.tres", "expected_twr_min": 2.0, "expected_twr_max": 2.4},
		{"path": "res://data/drones/racer.tres", "expected_twr_min": 3.0, "expected_twr_max": 3.8}
	]

	for item in presets:
		var spec: DroneSpec = load(item["path"])
		if not spec:
			printerr("FAIL: Could not load %s" % item["path"])
			return false

		# Verify derived arm_d
		var expected_arm_d = spec.arm_length * 0.70710678
		if absf(spec.arm_d - expected_arm_d) > 0.001:
			printerr("FAIL: %s arm_d mismatch: %f vs %f" % [spec.name, spec.arm_d, expected_arm_d])
			return false

		# Verify TWR
		if spec.twr < item["expected_twr_min"] or spec.twr > item["expected_twr_max"]:
			printerr("FAIL: %s TWR unexpected: %f (expected %f..%f)" % [spec.name, spec.twr, item["expected_twr_min"], item["expected_twr_max"]])
			return false

		# Verify Inertia Tensor
		var inert = spec.inertia
		if inert.x <= 0.0 or inert.y <= 0.0 or inert.z <= 0.0:
			printerr("FAIL: %s non-positive inertia tensor: %s" % [spec.name, str(inert)])
			return false

		if inert.y <= inert.x or inert.y <= inert.z:
			printerr("FAIL: %s yaw inertia should be greater than pitch/roll: %s" % [spec.name, str(inert)])
			return false

		print("  - %s: Mass=%.2fkg, Arm_d=%.3fm, TWR=%.2f, Inertia=%s (PASS)" % [
			spec.name, spec.mass, spec.arm_d, spec.twr, str(inert)
		])

	return true

func test_ds02_flight_controller_hover_all_presets() -> bool:
	print("[DS-02] Testing FlightController Hover Equilibrium across All Presets...")

	var paths = [
		"res://data/drones/scout.tres",
		"res://data/drones/photo.tres",
		"res://data/drones/racer.tres"
	]

	for path in paths:
		var spec: DroneSpec = load(path)
		var fc = FlightController.new()
		var phys = spec.get_physical_dict()
		var profile = {"name": "Normal", "auto_level_strength": 8.0, "kp_rate": 35.0, "kp_climb": 4.0, "altitude_hold": true}
		fc.configure(profile, phys)

		# Settle motor lag with neutral command at zero vertical speed
		var cmd = ControlFrame.new(0.0, 0.0, 0.0, 0.0)
		var out = {}
		for _step in range(15):
			out = fc.step(Basis.IDENTITY, Vector3.ZERO, Vector3.ZERO, cmd, {}, 0.02)

		var total_force_y = out.force_local.y
		var expected_weight = spec.mass * 9.81
		var force_error = absf(total_force_y - expected_weight)

		if force_error > 0.15:
			printerr("FAIL: %s hover force error too high: Force=%.2f N, Weight=%.2f N (Err=%.2f N)" % [
				spec.name, total_force_y, expected_weight, force_error
			])
			return false

		print("  - %s: Mass=%.2fkg, Gravity=%.2fN, HoverForce=%.2fN (Equilibrium error < 0.15N) (PASS)" % [
			spec.name, spec.mass, expected_weight, total_force_y
		])

	return true

func test_ds03_flight_controller_sign_tests_all_presets() -> bool:
	print("[DS-03] Testing 4-Axis Sign Tests across All Presets...")

	var paths = [
		"res://data/drones/scout.tres",
		"res://data/drones/photo.tres",
		"res://data/drones/racer.tres"
	]

	for path in paths:
		var spec: DroneSpec = load(path)
		var fc = FlightController.new()
		fc.configure({"name": "Normal", "auto_level_strength": 8.0, "kp_rate": 35.0}, spec.get_physical_dict())

		# Pitch Forward (pitch = 1.0) -> Nose down = Negative torque about +X
		var out_pitch = fc.step(Basis.IDENTITY, Vector3.ZERO, Vector3.ZERO, ControlFrame.new(0.0, 0.0, 1.0, 0.0), {}, 0.01)
		if out_pitch.torque_local.x >= 0.0:
			printerr("FAIL: %s Pitch forward expected negative torque about X, got %f" % [spec.name, out_pitch.torque_local.x])
			return false

		# Roll Right (roll = 1.0) -> Bank right = Negative torque about +Z
		var out_roll = fc.step(Basis.IDENTITY, Vector3.ZERO, Vector3.ZERO, ControlFrame.new(0.0, 0.0, 0.0, 1.0), {}, 0.01)
		if out_roll.torque_local.z >= 0.0:
			printerr("FAIL: %s Roll right expected negative torque about Z, got %f" % [spec.name, out_roll.torque_local.z])
			return false

		# Yaw Right (yaw = 1.0) -> Clockwise rotation = Negative torque about +Y
		var out_yaw = fc.step(Basis.IDENTITY, Vector3.ZERO, Vector3.ZERO, ControlFrame.new(0.0, 1.0, 0.0, 0.0), {}, 0.01)
		if out_yaw.torque_local.y >= 0.0:
			printerr("FAIL: %s Yaw right expected negative torque about Y, got %f" % [spec.name, out_yaw.torque_local.y])
			return false

		print("  - %s: Pitch Forward (-Tx), Roll Right (-Tz), Yaw Right (-Ty) sign validated (PASS)" % spec.name)

	return true

func test_ds04_model_builder_hierarchy() -> bool:
	print("[DS-04] Testing DroneModelBuilder Runtime Procedural Construction...")

	var root = Node3D.new()
	var spec: DroneSpec = load("res://data/drones/scout.tres")

	var data = DroneModelBuilder.build_drone(root, spec)
	if data.is_empty():
		printerr("FAIL: build_drone returned empty dictionary.")
		root.free()
		return false

	var rotors = data.get("rotors", [])
	var blur_discs = data.get("blur_discs", [])
	var blades = data.get("blades", [])

	if rotors.size() != 4 or blur_discs.size() != 4 or blades.size() != 4:
		printerr("FAIL: Incorrect rotor component counts (rotors=%d, blurs=%d, blades=%d)" % [rotors.size(), blur_discs.size(), blades.size()])
		root.free()
		return false

	if not data.get("gimbal", null):
		printerr("FAIL: Camera gimbal node not constructed.")
		root.free()
		return false

	if not data.get("state_led", null):
		printerr("FAIL: State beacon LED not constructed.")
		root.free()
		return false

	if not data.get("contact_shadow", null):
		printerr("FAIL: Contact shadow mesh not constructed.")
		root.free()
		return false

	# Test rebuilding replaces old model cleanly without leaking duplicates
	var data2 = DroneModelBuilder.build_drone(root, spec)
	var child_count = 0
	for c in root.get_children():
		if c.name == "ProceduralDroneModel":
			child_count += 1

	if child_count != 1:
		printerr("FAIL: Duplicate model instances found after rebuild: %d" % child_count)
		root.free()
		return false

	root.free()
	print("  - Procedural node hierarchy, 4 rotors, blur discs, gimbal, LEDs verified (PASS)")
	return true

func test_ds05_drone_rig_procedural_integration() -> bool:
	print("[DS-05] Testing DroneRig Procedural Spec Integration & Blur Disc Swapping...")

	var rig = DroneRig.new()
	rig.use_procedural_model = true
	var spec: DroneSpec = load("res://data/drones/scout.tres")
	rig.apply_drone_spec(spec)

	var blur_discs = rig.procedural_data.get("blur_discs", [])
	var blades = rig.procedural_data.get("blades", [])

	# Simulate Low RPM (< 0.38)
	rig._animate_procedural_drone([0.1, 0.1, 0.1, 0.1], 0.016, "FLYING", 1.0, 0.0, 100.0)
	for i in range(4):
		if blur_discs[i].visible or not blades[i].visible:
			printerr("FAIL: Low RPM expected blades visible and blur disc hidden for motor %d" % i)
			rig.free()
			return false

	# Simulate High RPM (>= 0.38)
	rig._animate_procedural_drone([0.75, 0.75, 0.75, 0.75], 0.016, "FLYING", 1.0, 0.0, 100.0)
	for i in range(4):
		if not blur_discs[i].visible or blades[i].visible:
			printerr("FAIL: High RPM expected blur disc visible and blades hidden for motor %d" % i)
			rig.free()
			return false

	rig.free()
	print("  - DroneRig correctly swaps sharp blades to blur discs at high RPM (PASS)")
	return true
