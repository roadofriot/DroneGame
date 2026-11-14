extends SceneTree

## Headless Unit and Integration Test Runner for Phase 4: Flight Academy & Stunt Engine
## Tests Aerobatic Stunt Physics, Safety Gating, Cooldowns, Quality Scoring,
## and Training Academy Curriculum Progression.

const FlightWorldScene = preload("res://scenes/flight/FlightWorld.tscn")
const StuntEngine = preload("res://scripts/flight/StuntEngine.gd")
const TrainingAcademy = preload("res://scripts/missions/TrainingAcademy.gd")

func _init() -> void:
	print("==================================================")
	print("Starting MindSparQ Drone Simulator Phase 4 Tests")
	print("Flight Academy Curriculum & Physics Stunt Engine")
	print("==================================================")

	var world = FlightWorldScene.instantiate()
	root.add_child(world)
	if not world.is_node_ready():
		world._ready()

	var tests_passed: int = 0
	var tests_total: int = 6

	if test_sa01_stunt_safety_and_mode_gating(world):
		tests_passed += 1
	if test_sa02_stunt_execution_and_motor_dynamics(world):
		tests_passed += 1
	if test_sa03_stunt_cooldown_and_abort(world):
		tests_passed += 1
	if test_sa04_academy_curriculum_schema(world):
		tests_passed += 1
	if test_sa05_academy_lesson_step_progression(world):
		tests_passed += 1
	if test_sa06_academy_crash_failure(world):
		tests_passed += 1

	print("==================================================")
	print("Phase 4 Test Results: %d / %d Passed" % [tests_passed, tests_total])
	print("==================================================")

	world.queue_free()

	if tests_passed == tests_total:
		print(">> ALL PHASE 4 ACCEPTANCE TESTS PASSED SUCCESSFULLY! <<")
		quit(0)
	else:
		printerr(">> PHASE 4 TESTS FAILED! <<")
		quit(1)

func test_sa01_stunt_safety_and_mode_gating(world: Node3D) -> bool:
	print("[SA-01] Testing Stunt Safety Gating (State, Flight Mode, Altitude, Attitude)...")
	var drone: FlightPhysics = world.get_node("Quadcopter")
	var stunt_eng: StuntEngine = drone.stunt_engine
	if not stunt_eng:
		printerr("FAIL: Drone does not have StuntEngine attached")
		return false

	# 1. Reject when drone is DISARMED
	drone.current_state = FlightPhysics.DroneState.DISARMED
	var chk = stunt_eng.can_perform_stunt(drone)
	if chk.get("allowed", true):
		printerr("FAIL: Stunt allowed while DISARMED")
		return false

	# 2. Reject in Normal / Cinematic flight modes
	drone.current_state = FlightPhysics.DroneState.FLYING
	drone.altitude_agl = 5.0
	drone.set_flight_profile("normal")
	chk = stunt_eng.can_perform_stunt(drone)
	if chk.get("allowed", true):
		printerr("FAIL: Stunt allowed in Normal mode without stunts_enabled")
		return false

	# 3. Reject in Arcade mode when altitude is below 3.0m
	drone.set_flight_profile("arcade")
	drone.altitude_agl = 1.8 # Below 3.0m threshold
	chk = stunt_eng.can_perform_stunt(drone)
	if chk.get("allowed", true):
		printerr("FAIL: Stunt allowed at low altitude (1.8m < 3.0m)")
		return false

	# 4. Reject when attitude is too steep (> 40 deg)
	drone.altitude_agl = 4.0
	drone.pitch_deg = 55.0
	chk = stunt_eng.can_perform_stunt(drone)
	if chk.get("allowed", true):
		printerr("FAIL: Stunt allowed while steeply tilted")
		return false

	# 5. Allow when all criteria met in Arcade mode
	drone.pitch_deg = 0.0
	drone.roll_deg = 0.0
	drone.altitude_agl = 4.5
	chk = stunt_eng.can_perform_stunt(drone)
	if not chk.get("allowed", false):
		printerr("FAIL: Stunt rejected when all conditions satisfied: ", chk.get("reason"))
		return false

	print("  - Stunt safety gating verified across state, flight mode, altitude, and attitude (PASS)")
	return true

func test_sa02_stunt_execution_and_motor_dynamics(world: Node3D) -> bool:
	print("[SA-02] Testing Physics-Driven Aerobatic Execution & Motor Differential...")
	var drone: FlightPhysics = world.get_node("Quadcopter")
	var stunt_eng: StuntEngine = drone.stunt_engine

	drone.current_state = FlightPhysics.DroneState.FLYING
	drone.set_flight_profile("arcade")
	drone.altitude_agl = 5.0
	drone.pitch_deg = 0.0
	drone.roll_deg = 0.0
	stunt_eng.cooldown_timer = 0.0

	var stunt_started_called: Array = [false, ""]
	var stunt_completed_called: Array = [false, "", 0, ""]

	stunt_eng.stunt_started.connect(func(stype):
		stunt_started_called[0] = true
		stunt_started_called[1] = stype
	)
	stunt_eng.stunt_completed.connect(func(stype, score, quality):
		stunt_completed_called[0] = true
		stunt_completed_called[1] = stype
		stunt_completed_called[2] = score
		stunt_completed_called[3] = quality
	)

	var ok = stunt_eng.trigger_stunt("front_flip", drone)
	if not ok or not stunt_eng.is_performing_stunt():
		printerr("FAIL: trigger_stunt returned false")
		return false

	if not stunt_started_called[0] or stunt_started_called[1] != "front_flip":
		printerr("FAIL: stunt_started signal not emitted correctly")
		return false

	# Test Phase 0: Pre-Boost (0.05s)
	stunt_eng.process_stunt_physics(0.05, drone)
	if drone.target_motor_rpms[0] < 0.6:
		printerr("FAIL: Pre-boost did not increase upward motor RPMs")
		return false

	# Test Phase 1: High Differential Rotation (0.25s)
	stunt_eng.process_stunt_physics(0.20, drone) # Total 0.25s
	# For front flip: front motors cut, rear motors boosted
	if drone.target_motor_rpms[0] >= drone.target_motor_rpms[2]:
		printerr("FAIL: Front flip motor differential inverted: FL=%f RR=%f" % [drone.target_motor_rpms[0], drone.target_motor_rpms[2]])
		return false

	# Advance to Recovery Phase and Completion (total >= 0.65s)
	drone.pitch_deg = 5.0
	drone.roll_deg = -2.0
	drone.angular_velocity = Vector3.ZERO
	stunt_eng.process_stunt_physics(0.45, drone) # Total 0.70s

	if not stunt_completed_called[0]:
		printerr("FAIL: stunt_completed signal was not emitted at maneuver finish")
		return false

	if stunt_completed_called[2] < 500:
		printerr("FAIL: Stunt score too low: %d" % stunt_completed_called[2])
		return false

	if stunt_eng.is_performing_stunt():
		printerr("FAIL: is_stunting remained true after completion")
		return false

	print("  - Front flip executed with pre-boost, differential torque, and auto-level recovery: Score = %d (%s) (PASS)" % [stunt_completed_called[2], stunt_completed_called[3]])
	return true

func test_sa03_stunt_cooldown_and_abort(world: Node3D) -> bool:
	print("[SA-03] Testing Stunt Cooldown Enforcement & Ground Proximity Abort...")
	var drone: FlightPhysics = world.get_node("Quadcopter")
	var stunt_eng: StuntEngine = drone.stunt_engine

	# 1. Immediately after stunt, cooldown should prevent retrigger
	if stunt_eng.cooldown_timer <= 0.0:
		printerr("FAIL: Cooldown timer not set after stunt completion")
		return false

	var chk = stunt_eng.can_perform_stunt(drone)
	if chk.get("allowed", true):
		printerr("FAIL: Stunt allowed during active cooldown")
		return false

	# Clear cooldown
	stunt_eng.cooldown_timer = 0.0
	drone.altitude_agl = 4.0
	drone.pitch_deg = 0.0
	drone.roll_deg = 0.0

	# 2. Trigger stunt, then drop altitude to test emergency abort
	var stunt_failed_called: Array = [false, ""]
	stunt_eng.stunt_failed.connect(func(reason):
		stunt_failed_called[0] = true
		stunt_failed_called[1] = reason
	)

	stunt_eng.trigger_stunt("roll_right", drone)
	# Simulate low altitude drop during maneuver
	drone.altitude_agl = 0.4
	stunt_eng.process_stunt_physics(0.1, drone)

	if not stunt_failed_called[0]:
		printerr("FAIL: stunt_failed signal not emitted on low altitude abort")
		return false

	if stunt_eng.is_performing_stunt():
		printerr("FAIL: is_stunting remained active after abort")
		return false

	print("  - Cooldown timer strictly enforced and emergency ground abort functioning (PASS)")
	return true

func test_sa04_academy_curriculum_schema(world: Node3D) -> bool:
	print("[SA-04] Testing Training Academy Curriculum Catalogue...")
	var academy: TrainingAcademy = world.training_academy
	if not academy:
		printerr("FAIL: TrainingAcademy not found in FlightWorld")
		return false

	var expected_lessons = [
		"academy_01_takeoff",
		"academy_02_yaw",
		"academy_03_pitch_roll",
		"academy_04_slalom",
		"academy_05_landing"
	]

	if academy.lessons_catalogue.size() < 5:
		printerr("FAIL: Expected 5 academy lessons, found %d" % academy.lessons_catalogue.size())
		return false

	for lid in expected_lessons:
		var ldef = academy.get_lesson_def(lid)
		if ldef.is_empty():
			printerr("FAIL: Missing lesson definition for: ", lid)
			return false
		if not ldef.has("title") or not ldef.has("steps") or not ldef.has("medal_times") or not ldef.has("rewards"):
			printerr("FAIL: Lesson %s missing required contract fields" % lid)
			return false

	print("  - All 5 Training Academy curriculum lessons verified with full pedagogical schemas (PASS)")
	return true

func test_sa05_academy_lesson_step_progression(world: Node3D) -> bool:
	print("[SA-05] Testing Academy Guided Step Progression & Reward Crediting...")
	var academy: TrainingAcademy = world.training_academy
	var drone: FlightPhysics = world.get_node("Quadcopter")
	academy.target_drone = drone

	var lesson_completed_called: Array = [false, "", "", 0]
	academy.lesson_completed.connect(func(lid, medal, score, _rewards):
		lesson_completed_called[0] = true
		lesson_completed_called[1] = lid
		lesson_completed_called[2] = medal
		lesson_completed_called[3] = score
	)

	var ok = academy.start_lesson("academy_01_takeoff")
	if not ok or not academy.is_active:
		printerr("FAIL: Failed to start academy_01_takeoff")
		return false

	if academy.active_step_index != 0:
		printerr("FAIL: Starting step index is not 0")
		return false

	# Step 0: Takeoff condition
	drone.current_state = FlightPhysics.DroneState.FLYING
	drone.altitude_agl = 1.6
	academy._physics_process(0.016)

	if academy.active_step_index != 1:
		printerr("FAIL: Did not advance to Step 1 after takeoff: curr=%d" % academy.active_step_index)
		return false

	# Step 1: Reach Altitude (1.7m - 2.5m)
	drone.altitude_agl = 2.1
	academy._physics_process(0.016)

	if academy.active_step_index != 2:
		printerr("FAIL: Did not advance to Step 2 after reaching 2.1m: curr=%d" % academy.active_step_index)
		return false

	# Step 2: Maintain Hover for 3.0 seconds
	drone.altitude_agl = 2.0
	drone.ground_speed = 0.2
	# Simulate 3.2 seconds at 60Hz
	for _i in range(195):
		academy._physics_process(0.0166)

	if not lesson_completed_called[0]:
		printerr("FAIL: Lesson 1 was not completed after 3.2s of stable hover")
		return false

	if lesson_completed_called[2] != "GOLD":
		printerr("FAIL: Expected GOLD medal for fast completion, got %s" % lesson_completed_called[2])
		return false

	# Verify ProgressionService received the reward
	if academy.progression_service.get_coins() < 50:
		printerr("FAIL: ProgressionService did not credit lesson coins: %d" % academy.progression_service.get_coins())
		return false

	print("  - Lesson 1 completed with GOLD medal, step sequencing verified, 50 coins awarded (PASS)")
	return true

func test_sa06_academy_crash_failure(world: Node3D) -> bool:
	print("[SA-06] Testing Academy Crash & Abort Handling...")
	var academy: TrainingAcademy = world.training_academy
	var drone: FlightPhysics = world.get_node("Quadcopter")
	academy.target_drone = drone

	var failed_called: Array = [false, ""]
	academy.lesson_failed.connect(func(_lid, reason):
		failed_called[0] = true
		failed_called[1] = reason
	)

	academy.start_lesson("academy_02_yaw")
	if not academy.is_active:
		printerr("FAIL: Could not start academy_02_yaw")
		return false

	# Drone crashes
	drone.current_state = FlightPhysics.DroneState.CRASHED
	academy._physics_process(0.016)

	if not failed_called[0]:
		printerr("FAIL: lesson_failed signal not emitted on drone crash")
		return false

	if academy.is_active:
		printerr("FAIL: academy remains active after crash abort")
		return false

	print("  - Academy immediately caught crash state and aborted lesson safely (PASS)")
	return true
