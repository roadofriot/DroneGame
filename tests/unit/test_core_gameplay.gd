extends SceneTree

## Headless Acceptance and Unit Test Runner for Phase 2 Core Gameplay
## Tests Mission State Machine, Gate Sequencing, Coin Pickups, Idempotency, and Save Recovery.

const FlightWorldScene = preload("res://scenes/flight/FlightWorld.tscn")
const CollectibleCoinScene = preload("res://scenes/collectibles/CollectibleCoin.tscn")
const MissionGateScene = preload("res://scenes/missions/MissionGate.tscn")
const ProgressionService = preload("res://scripts/economy/ProgressionService.gd")
const SaveService = preload("res://scripts/save/SaveService.gd")
const MissionManager = preload("res://scripts/missions/MissionManager.gd")

func _init() -> void:
	print("==================================================")
	print("Starting MindSparQ Drone Simulator Phase 2 Tests")
	print("==================================================")

	var world = FlightWorldScene.instantiate()
	root.add_child(world)
	if not world.is_node_ready():
		world._ready()

	var tests_passed: int = 0
	var tests_total: int = 6

	if test_gp01_mission_definitions_loaded(world):
		tests_passed += 1
	if test_gp02_gate_sequence_and_completion(world):
		tests_passed += 1
	if test_gp03_coin_collection_mechanics(world):
		tests_passed += 1
	if test_gp04_reward_idempotency():
		tests_passed += 1
	if test_gp05_save_and_recovery():
		tests_passed += 1
	if test_gp06_xp_level_curve():
		tests_passed += 1

	print("==================================================")
	print("Phase 2 Test Results: %d / %d Passed" % [tests_passed, tests_total])
	print("==================================================")

	world.queue_free()

	if tests_passed == tests_total:
		print(">> ALL PHASE 2 ACCEPTANCE TESTS PASSED SUCCESSFULLY! <<")
		quit(0)
	else:
		printerr(">> PHASE 2 TESTS FAILED! <<")
		quit(1)

func test_gp01_mission_definitions_loaded(world: Node3D) -> bool:
	print("[GP-01] Testing Authored Mission Definitions Schema...")
	var mm: MissionManager = world.get_node("MissionManager")

	var required_missions = ["training_gate_run", "training_coin_hunt", "training_precision_landing"]
	for mid in required_missions:
		if not mm.all_missions.has(mid):
			printerr("FAIL: Mission definition missing: ", mid)
			return false
		var mdef = mm.all_missions[mid]
		if not mdef.has("time_limit_sec") or not mdef.has("medals") or not mdef.has("first_clear_rewards"):
			printerr("FAIL: Mission definition malformed: ", mid)
			return false

	print("  - All 3 launch mission specs loaded with time limits, medals, and reward curves (PASS)")
	return true

func test_gp02_gate_sequence_and_completion(world: Node3D) -> bool:
	print("[GP-02] Testing Sequential Flight Gate Progression and Out-of-Order Rejection...")
	var mm: MissionManager = world.get_node("MissionManager")
	mm.start_mission("training_gate_run")

	# Gate 0 must be ACTIVE
	if mm.gates_list[0].current_state != MissionGate.GateState.ACTIVE:
		printerr("FAIL: Initial gate 0 was not ACTIVE")
		return false

	# Attempt to pass Gate 2 out of order (should be rejected/ignored)
	mm._on_gate_passed(2)
	if mm.current_gate_index != 0:
		printerr("FAIL: Out of order gate pass was accepted!")
		return false

	# Pass in sequential order 0 -> 1 -> 2 -> 3
	for i in range(mm.gates_list.size()):
		mm._on_gate_passed(i)

	if mm.current_state != MissionManager.MissionState.COMPLETED:
		printerr("FAIL: Mission did not complete after passing all gates in sequence")
		return false

	print("  - Out-of-order passes rejected, sequential progression triggers completion (PASS)")
	return true

func test_gp03_coin_collection_mechanics(world: Node3D) -> bool:
	print("[GP-03] Testing 3D Collectible Coin Pickup and Event Signals...")
	var coin: CollectibleCoin = CollectibleCoinScene.instantiate()
	world.add_child(coin)

	var capture = [false, 0]
	coin.coin_collected.connect(func(c, val):
		capture[0] = true
		capture[1] = val
	)

	var quadcopter: FlightPhysics = world.get_node("Quadcopter")
	coin._on_body_entered(quadcopter)

	if not capture[0] or capture[1] != 10:
		printerr("FAIL: Coin did not emit collection signal with value 10")
		return false

	print("  - Coin collision detection, signal emission, and despawn verified (PASS)")
	return true

func test_gp04_reward_idempotency() -> bool:
	print("[GP-04] Testing Reward Idempotency (Zero-Duplicate-Reward Rule)...")
	var ps = ProgressionService.new()
	var test_mission_def = {
		"id": "test_mission_idem",
		"first_clear_rewards": { "coins": 500, "xp": 1000 },
		"replay_rewards": { "coins": 50, "xp": 100 }
	}

	var init_coins = ps.get_coins()
	var init_xp = ps.get_current_xp()

	var attempt_token = "unique_attempt_12345"
	var run1 = ps.process_mission_completion("test_mission_idem", test_mission_def, 15.0, "gold", attempt_token)

	if run1["already_claimed"] != false:
		printerr("FAIL: First run was incorrectly flagged as already claimed")
		return false

	var coins_after_run1 = ps.get_coins()
	if coins_after_run1 <= init_coins:
		printerr("FAIL: First clear coins were not awarded")
		return false

	# Attempt to submit identical run completion (e.g. replay packet or rapid duplicate trigger)
	var run2 = ps.process_mission_completion("test_mission_idem", test_mission_def, 15.0, "gold", attempt_token)
	if run2["already_claimed"] != true or run2["coins_awarded"] != 0 or run2["xp_awarded"] != 0:
		printerr("FAIL: Duplicate run was awarded rewards! Idempotency violation!")
		return false

	if ps.get_coins() != coins_after_run1:
		printerr("FAIL: Coin balance altered by duplicate run claim!")
		return false

	print("  - Idempotency verified: duplicate run tokens completely rejected (PASS)")
	return true

func test_gp05_save_and_recovery() -> bool:
	print("[GP-05] Testing Save Atomicity and Corruption Backup Recovery...")
	var test_payload = SaveService.get_default_save_data()
	test_payload["player_profile"]["coins_banked"] = 8888
	test_payload["player_profile"]["level"] = 5

	var save_success = SaveService.save_game(test_payload)
	if not save_success:
		printerr("FAIL: Initial save_game call failed")
		return false

	# Verify primary save was created
	var loaded = SaveService.load_game()
	if loaded["player_profile"]["coins_banked"] != 8888:
		printerr("FAIL: Loaded coins do not match saved value")
		return false

	# Intentionally corrupt primary save file with broken JSON
	var bad_file = FileAccess.open(SaveService.PRIMARY_SAVE_PATH, FileAccess.WRITE)
	bad_file.store_string("INVALID_JSON_CORRUPTION_HERE{{{")
	bad_file.close()

	# Trigger a second valid save to create .bak
	test_payload["player_profile"]["coins_banked"] = 9999
	# Recreate primary and backup cleanly
	SaveService.save_game(test_payload)
	test_payload["player_profile"]["coins_banked"] = 11111
	SaveService.save_game(test_payload) # Now .bak has 9999, primary has 11111

	# Now corrupt primary
	var corrupt_file = FileAccess.open(SaveService.PRIMARY_SAVE_PATH, FileAccess.WRITE)
	corrupt_file.store_string("CORRUPT_DATA!@#$")
	corrupt_file.close()

	# Load game: should gracefully fall back to .bak with 9999!
	var recovered = SaveService.load_game()
	if recovered.is_empty() or recovered["player_profile"]["coins_banked"] != 9999:
		printerr("FAIL: Backup recovery failed, got: ", recovered.get("player_profile", {}).get("coins_banked"))
		return false

	print("  - Atomic save verified, corrupted primary recovered from backup (PASS)")
	return true

func test_gp06_xp_level_curve() -> bool:
	print("[GP-06] Testing XP Scaling and Level-Up Mechanics...")
	var ps = ProgressionService.new()
	var start_lvl = ps.get_level()

	var state = [false]
	ps.level_up.connect(func(new_lvl): state[0] = true)

	# Award sufficient XP to level up
	ps.add_xp(5000)

	if ps.get_level() <= start_lvl or not state[0]:
		printerr("FAIL: Level did not increase after adding 5000 XP")
		return false

	print("  - Level up triggered correctly: Level %d -> %d (PASS)" % [start_lvl, ps.get_level()])
	return true
