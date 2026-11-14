extends SceneTree

## Dedicated Unit Test Suite for FlightStateMachine (Phase 4)
## Validates state progression, landing abort, touchdown disarm, 0.7s emergency stop,
## removal of overloaded space recovery, and tilt inversion crash detection.

const FlightStateMachine = preload("res://scripts/flight/FlightStateMachine.gd")

func _init() -> void:
	print("==================================================")
	print("Starting Phase 4 Flight State Machine Tests")
	print("==================================================")

	var tests_passed: int = 0
	var tests_total: int = 8

	if test_fsm01_initial_state():
		tests_passed += 1
	if test_fsm02_takeoff_progression():
		tests_passed += 1
	if test_fsm03_landing_and_abort():
		tests_passed += 1
	if test_fsm04_touchdown_disarm():
		tests_passed += 1
	if test_fsm05_emergency_stop_1tick():
		tests_passed += 1
	if test_fsm06_overloaded_recover_removed():
		tests_passed += 1
	if test_fsm07_tilt_inversion_crash():
		tests_passed += 1
	if test_fsm08_impact_force_crash():
		tests_passed += 1

	print("==================================================")
	print("Phase 4 Test Results: %d / %d Passed" % [tests_passed, tests_total])
	print("==================================================")

	if tests_passed == tests_total:
		print(">> ALL PHASE 4 STATE MACHINE TESTS PASSED SUCCESSFULLY! <<")
		quit(0)
	else:
		printerr(">> PHASE 4 STATE MACHINE TESTS FAILED! <<")
		quit(1)

func test_fsm01_initial_state() -> bool:
	print("[FSM-01] Testing Initial State & Arming Flag...")
	var fsm = FlightStateMachine.new()
	var ok = (fsm.state == FlightStateMachine.State.DISARMED) and not fsm.is_armed
	if not ok:
		printerr("FAIL: FSM not initialized to DISARMED unarmed.")
		return false
	print("  - State is DISARMED, is_armed is false (PASS)")
	return true

func test_fsm02_takeoff_progression() -> bool:
	print("[FSM-02] Testing Takeoff Progression (DISARMED -> TAKEOFF -> FLYING)...")
	var fsm = FlightStateMachine.new()
	var takeoff_ok = fsm.handle_takeoff_land(100.0, true)
	if not takeoff_ok or fsm.state != FlightStateMachine.State.TAKEOFF or not fsm.is_armed:
		printerr("FAIL: Takeoff command rejected from grounded DISARMED state.")
		return false

	# Step spin-up period (0.5s) on ground
	for _i in range(30):
		fsm.update(1.0 / 60.0, 0.05, 0.0, 0.0, 0.0)
	if fsm.state != FlightStateMachine.State.TAKEOFF:
		printerr("FAIL: FSM left TAKEOFF before reaching target clearance altitude.")
		return false

	# Drone climbs to 1.5m target clearance
	fsm.update(1.0 / 60.0, 1.50, 0.1, 0.5, 0.0)
	if fsm.state != FlightStateMachine.State.FLYING:
		printerr("FAIL: FSM did not transition to FLYING at 1.5m AGL. Current: ", fsm.get_state_name())
		return false

	print("  - Progression DISARMED -> TAKEOFF (0.5s spin-up) -> FLYING (1.5m AGL) verified (PASS)")
	return true

func test_fsm03_landing_and_abort() -> bool:
	print("[FSM-03] Testing Landing Command & Mid-Air Abort...")
	var fsm = FlightStateMachine.new()
	fsm.transition_to(FlightStateMachine.State.FLYING)

	# Trigger Landing
	var land_ok = fsm.handle_takeoff_land()
	if not land_ok or fsm.state != FlightStateMachine.State.LANDING:
		printerr("FAIL: Did not enter LANDING state from FLYING.")
		return false

	# Pilot changes mind and presses takeoff_land again to abort landing
	var abort_ok = fsm.handle_takeoff_land()
	if not abort_ok or fsm.state != FlightStateMachine.State.FLYING:
		printerr("FAIL: Landing abort did not return to FLYING. Current: ", fsm.get_state_name())
		return false

	print("  - FLYING -> LANDING -> FLYING (abort) verified (PASS)")
	return true

func test_fsm04_touchdown_disarm() -> bool:
	print("[FSM-04] Testing Touchdown Ground Detection & Disarm...")
	var fsm = FlightStateMachine.new()
	fsm.transition_to(FlightStateMachine.State.LANDING)

	# In air: AGL 0.8m, speed 0.8 m/s -> still landing
	fsm.update(0.1, 0.8, 0.8, -0.8, 0.0)
	if fsm.state != FlightStateMachine.State.LANDING:
		printerr("FAIL: Premature touchdown at 0.8m AGL.")
		return false

	# Touchdown: AGL 0.10m (< 0.15m), speed 0.1 m/s (< 0.2 m/s)
	fsm.update(0.1, 0.10, 0.1, -0.1, 0.0)
	if fsm.state != FlightStateMachine.State.DISARMED or fsm.is_armed:
		printerr("FAIL: Touchdown did not transition to DISARMED. Current: ", fsm.get_state_name())
		return false

	print("  - Touchdown at AGL < 0.15m disarms motors cleanly to DISARMED (PASS)")
	return true

func test_fsm05_emergency_stop_1tick() -> bool:
	print("[FSM-05] Testing Emergency Stop Zero-Latency Disarm...")
	var fsm = FlightStateMachine.new()
	fsm.transition_to(FlightStateMachine.State.FLYING)

	fsm.handle_emergency_stop()
	if fsm.state != FlightStateMachine.State.CRASHED or fsm.is_armed:
		printerr("FAIL: Emergency stop did not instantly transition to CRASHED disarmed state.")
		return false

	print("  - Emergency stop transitions to CRASHED and zeroes arm flag within 1 tick (PASS)")
	return true

func test_fsm06_overloaded_recover_removed() -> bool:
	print("[FSM-06] Testing Overloaded Space Recovery Removal...")
	var fsm = FlightStateMachine.new()
	fsm.transition_to(FlightStateMachine.State.CRASHED)

	# Space / takeoff_land MUST be rejected while crashed
	var space_result = fsm.handle_takeoff_land()
	if space_result or fsm.state != FlightStateMachine.State.CRASHED:
		printerr("FAIL: Space / takeoff_land still recovers drone from CRASHED state.")
		return false

	# Reset (R / Gamepad Y) is required to restore to DISARMED
	fsm.handle_reset()
	if fsm.state != FlightStateMachine.State.DISARMED:
		printerr("FAIL: Reset did not restore DISARMED pad state.")
		return false

	print("  - Takeoff/land rejected during CRASHED; recovery strictly requires Reset (PASS)")
	return true

func test_fsm07_tilt_inversion_crash() -> bool:
	print("[FSM-07] Testing Tilt Inversion Crash Detection (> 100° for 0.5s)...")
	var fsm = FlightStateMachine.new()
	fsm.transition_to(FlightStateMachine.State.FLYING)

	# Low altitude (2.0m), inverted at 110° for 0.3s -> should not crash yet
	for _i in range(18):
		fsm.update(1.0 / 60.0, 2.0, 1.0, 0.0, 110.0)
	if fsm.state != FlightStateMachine.State.FLYING:
		printerr("FAIL: Tilt crash triggered before 0.5s timeout.")
		return false

	# Continue inversion past 0.5s threshold
	for _i in range(20):
		fsm.update(1.0 / 60.0, 2.0, 1.0, 0.0, 110.0)
	if fsm.state != FlightStateMachine.State.CRASHED:
		printerr("FAIL: Sustained inversion > 100° did not trigger CRASHED. State: ", fsm.get_state_name())
		return false

	print("  - Tilt inversion (> 100° for > 0.5s at low altitude) triggers CRASHED (PASS)")
	return true

func test_fsm08_impact_force_crash() -> bool:
	print("[FSM-08] Testing High-Energy Collision Impact Crash...")
	var fsm = FlightStateMachine.new()
	fsm.transition_to(FlightStateMachine.State.FLYING)

	# Small bump (5.0 N/kg) does not crash
	fsm.update(0.016, 3.0, 2.0, 0.0, 5.0, 5.0)
	if fsm.state != FlightStateMachine.State.FLYING:
		printerr("FAIL: Minor bump triggered crash.")
		return false

	# Violent collision (18.0 N/kg >= 12.0)
	fsm.update(0.016, 3.0, 5.0, 0.0, 15.0, 18.0)
	if fsm.state != FlightStateMachine.State.CRASHED:
		printerr("FAIL: Severe collision did not trigger CRASHED.")
		return false

	print("  - Collision impulse above threshold transitions to CRASHED (PASS)")
	return true
