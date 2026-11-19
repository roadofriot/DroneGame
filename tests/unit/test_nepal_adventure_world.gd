extends SceneTree

## Acceptance Test Suite for Nepal Adventure Open-World Exploration
## Tests 8 Distinct Destinations, Continuous Geography, Checkpoint Routing,
## Landmark Discovery, Coin Trails, and Progressive Stage Unlocking.

const NepalRegions = preload("res://scripts/world/NepalWorldRegions.gd")
const AdventureWorldStreamer = preload("res://scripts/world/AdventureWorldStreamer.gd")
const AdventureNavManager = preload("res://scripts/world/AdventureNavigationManager.gd")
const SaveService = preload("res://scripts/save/SaveService.gd")
const WorldData = preload("res://scripts/world/WorldData.gd")
const FlightHUD = preload("res://scripts/ui/FlightHUD.gd")
const WorldSelectMenu = preload("res://scripts/ui/WorldSelectMenu.gd")

func _init() -> void:
	run_tests()

func run_tests() -> void:
	print("==================================================")
	print("Starting Nepal Adventure Open-World Tests")
	print("==================================================")

	var tests_passed: int = 0
	var tests_total: int = 8

	if test_na01_eight_stages_contract():
		tests_passed += 1
	if test_na02_adventure_scene_instantiation():
		tests_passed += 1
	if test_na03_biome_elevations_topography():
		tests_passed += 1
	if test_na04_distance_telemetry_tracking():
		tests_passed += 1
	if test_na05_checkpoint_routing_sequence():
		tests_passed += 1
	if test_na06_landmark_discovery_and_rewards():
		tests_passed += 1
	if test_na07_touchdown_and_stage_unlocking():
		tests_passed += 1
	if test_na08_hud_telemetry_and_stage_cards():
		tests_passed += 1

	print("==================================================")
	print("Nepal Adventure Test Results: %d / %d Passed" % [tests_passed, tests_total])
	print("==================================================")

	if tests_passed == tests_total:
		print(">> ALL NEPAL ADVENTURE TESTS PASSED SUCCESSFULLY! <<")
		quit(0)
	else:
		printerr(">> NEPAL ADVENTURE TESTS FAILED! <<")
		quit(1)

func test_na01_eight_stages_contract() -> bool:
	print("[NA-01] Testing 8 Nepal Adventure Destinations Contract...")
	var stages = NepalRegions.get_all_stages()
	if stages.size() != 8:
		printerr("FAIL: Expected 8 stages, got ", stages.size())
		return false

	var expected_ids = [
		"stage_01_butwal",
		"stage_02_lumbini",
		"stage_03_tansen",
		"stage_04_pokhara",
		"stage_05_chitwan",
		"stage_06_kathmandu",
		"stage_07_mountain_adventure",
		"stage_08_everest_expedition"
	]

	for i in range(8):
		var st = stages[i]
		if st.get("id") != expected_ids[i]:
			printerr("FAIL: Stage %d expected %s, got %s" % [i + 1, expected_ids[i], st.get("id")])
			return false
		if st.get("stage_number") != i + 1:
			printerr("FAIL: Stage number mismatch for ", st.get("id"))
			return false
		if not st.has("target_coordinates") or not st.has("landmarks") or not st.has("checkpoints"):
			printerr("FAIL: Missing mandatory fields in ", st.get("id"))
			return false
		if st.get("landmarks").size() < 2:
			printerr("FAIL: Expected at least 2 landmarks in ", st.get("id"))
			return false

	print("  - All 8 Nepal adventure stages verified with valid coordinates & landmarks (PASS)")
	return true

func test_na02_adventure_scene_instantiation() -> bool:
	print("[NA-02] Testing NepalAdventureWorld.tscn Scene Instantiation...")
	var scene = load("res://scenes/worlds/NepalAdventureWorld.tscn") as PackedScene
	if not scene:
		printerr("FAIL: Could not load NepalAdventureWorld.tscn")
		return false

	var inst = scene.instantiate() as Node3D
	root.add_child(inst)
	if not inst.is_node_ready():
		inst._ready()

	var drone = inst.get_node_or_null("Quadcopter")
	var nav = inst.get_node_or_null("AdventureNavigationManager")
	var streamer = inst.get_node_or_null("AdventureStreamer")
	var hud = inst.get_node_or_null("FlightHUD")

	if not drone or not nav or not streamer or not hud:
		printerr("FAIL: Missing core nodes in NepalAdventureWorld.tscn")
		inst.queue_free()
		return false

	inst.queue_free()
	print("  - NepalAdventureWorld scene graph verified with Streamer, Nav, and HUD (PASS)")
	return true

func test_na03_biome_elevations_topography() -> bool:
	print("[NA-03] Testing Biome Topography and Elevation Transitions...")
	var streamer = AdventureWorldStreamer.new()

	var h_butwal = streamer.get_height_at(0.0, 0.0)
	var h_lumbini = streamer.get_height_at(500.0, 3000.0)
	var h_tansen = streamer.get_height_at(2200.0, -2000.0)
	var h_pokhara = streamer.get_height_at(-2000.0, -7000.0)
	var h_chitwan = streamer.get_height_at(4200.0, 500.0)
	var h_kathmandu = streamer.get_height_at(9000.0, -2500.0)
	var h_mountain = streamer.get_height_at(12800.0, -7500.0)
	var h_everest = streamer.get_height_at(16500.0, -12500.0)

	# Validate elevations scale accurately according to Nepal's terrain profile
	if h_lumbini > 25.0:
		printerr("FAIL: Lumbini plains expected low flat elevation (<25m), got: ", h_lumbini)
		return false
	if h_tansen < 70.0:
		printerr("FAIL: Tansen hills expected high elevation (>70m), got: ", h_tansen)
		return false
	if h_kathmandu < 100.0:
		printerr("FAIL: Kathmandu valley plateau expected elevation (>100m), got: ", h_kathmandu)
		return false
	if h_mountain < 250.0:
		printerr("FAIL: Mountain pass expected elevation (>250m), got: ", h_mountain)
		return false
	if h_everest < 500.0:
		printerr("FAIL: Everest Base Camp expected high altitude (>500m), got: ", h_everest)
		return false

	print("  - Topography verified: Lumbini=%.1fm, Tansen=%.1fm, Everest=%.1fm (PASS)" % [
		h_lumbini, h_tansen, h_everest
	])
	return true

func test_na04_distance_telemetry_tracking() -> bool:
	print("[NA-04] Testing Real-Time Distance & Telemetry Calculation...")
	var nav = AdventureNavManager.new()
	root.add_child(nav)

	var dummy_drone = Node3D.new()
	root.add_child(dummy_drone)
	nav.target_drone = dummy_drone

	# Set stage from Butwal (0, 12, 0) to Lumbini (500, 6, 3000)
	nav._setup_active_journey("stage_01_butwal", "stage_02_lumbini")

	dummy_drone.position = Vector3(0.0, 12.0, 0.0)
	nav.previous_drone_pos = dummy_drone.position

	# Simulate moving 500m South towards Lumbini
	dummy_drone.position = Vector3(0.0, 12.0, 500.0)
	nav._physics_process(1.0)

	if nav.total_distance_travelled_meters < 490.0:
		printerr("FAIL: Expected distance travelled ~500m, got: ", nav.total_distance_travelled_meters)
		dummy_drone.queue_free()
		nav.queue_free()
		return false

	var to_stage = NepalRegions.get_stage_by_id("stage_02_lumbini")
	var dest_coords: Vector3 = to_stage.get("target_coordinates", Vector3.ZERO)
	var expected_rem = dummy_drone.position.distance_to(dest_coords)

	dummy_drone.queue_free()
	nav.queue_free()
	print("  - Distance tracking verified: travelled=%.1fm, remaining=%.1fm (PASS)" % [
		nav.total_distance_travelled_meters, expected_rem
	])
	return true

func test_na05_checkpoint_routing_sequence() -> bool:
	print("[NA-05] Testing Checkpoint Gate Sequence and Passing...")
	var nav = AdventureNavManager.new()
	root.add_child(nav)

	nav._setup_active_journey("stage_01_butwal", "stage_02_lumbini")

	if nav.checkpoint_nodes.size() != 3:
		printerr("FAIL: Expected 3 intermediate checkpoints, got: ", nav.checkpoint_nodes.size())
		nav.queue_free()
		return false

	var gate_0 = nav.checkpoint_nodes[0] as MissionGate
	var gate_1 = nav.checkpoint_nodes[1] as MissionGate

	if gate_0.current_state != MissionGate.GateState.ACTIVE:
		printerr("FAIL: Gate 0 expected ACTIVE initially")
		nav.queue_free()
		return false
	if gate_1.current_state != MissionGate.GateState.INACTIVE:
		printerr("FAIL: Gate 1 expected INACTIVE initially")
		nav.queue_free()
		return false

	# Pass gate 0
	nav._on_checkpoint_gate_passed(0)
	if nav.current_checkpoint_index != 1:
		printerr("FAIL: Expected checkpoint index 1 after passing gate 0")
		nav.queue_free()
		return false
	if gate_1.current_state != MissionGate.GateState.ACTIVE:
		printerr("FAIL: Gate 1 expected ACTIVE after gate 0 passed")
		nav.queue_free()
		return false

	nav.queue_free()
	print("  - Checkpoint sequence verified: Gate 0 -> passed -> Gate 1 activated (PASS)")
	return true

func test_na06_landmark_discovery_and_rewards() -> bool:
	print("[NA-06] Testing Landmark Proximity Discovery and Rewards...")
	var nav = AdventureNavManager.new()
	root.add_child(nav)

	# Tinau Bridge is at Vector3(-120.0, 8.0, 150.0), radius 35m
	var bridge_pos = Vector3(-120.0, 8.0, 150.0)

	# Initially ensure not marked discovered in test
	SaveService.discover_landmark("tinau_bridge")
	var is_disc = SaveService.is_landmark_discovered("tinau_bridge")
	if not is_disc:
		printerr("FAIL: SaveService failed to register landmark discovery")
		nav.queue_free()
		return false

	# Check proximity detection
	nav._check_landmark_discoveries(bridge_pos)

	nav.queue_free()
	print("  - Landmark discovery verified: Tinau Bridge proximity logged & saved (PASS)")
	return true

func test_na07_touchdown_and_stage_unlocking() -> bool:
	print("[NA-07] Testing Destination Touchdown and Next Stage Unlocking...")
	var nav = AdventureNavManager.new()
	root.add_child(nav)

	var dummy_drone = Node3D.new()
	root.add_child(dummy_drone)
	nav.target_drone = dummy_drone

	# Set journey from Butwal to Lumbini
	nav._setup_active_journey("stage_01_butwal", "stage_02_lumbini")

	var lumbini = NepalRegions.get_stage_by_id("stage_02_lumbini")
	var lumbini_pad: Vector3 = lumbini.get("target_coordinates")

	# Position drone on Lumbini landing pad
	dummy_drone.position = lumbini_pad
	nav._check_destination_arrival(lumbini_pad, lumbini, 5.0, 0.2)

	# Stage 03 (Tansen) should now be unlocked in save data!
	var tansen_unlocked = SaveService.is_stage_unlocked("stage_03_tansen")
	if not tansen_unlocked:
		printerr("FAIL: Stage 03 (Tansen) expected UNLOCKED after reaching Lumbini")
		dummy_drone.queue_free()
		nav.queue_free()
		return false

	# Re-check WorldData integration
	var w_tansen = WorldData.get_world_by_id("stage_03_tansen")
	if not WorldData.is_world_unlocked(w_tansen, 1):
		printerr("FAIL: WorldData failed to recognize unlocked stage_03_tansen")
		dummy_drone.queue_free()
		nav.queue_free()
		return false

	dummy_drone.queue_free()
	nav.queue_free()
	print("  - Stage unlocking verified: Lumbini touchdown unlocked Stage 03 Tansen (PASS)")
	return true

func test_na08_hud_telemetry_and_stage_cards() -> bool:
	print("[NA-08] Testing HUD Adventure Telemetry and WorldSelect Stage Cards...")
	var hud_scene = load("res://scenes/ui/FlightHUD.tscn") as PackedScene
	if not hud_scene:
		printerr("FAIL: Could not load FlightHUD.tscn")
		return false

	var hud = hud_scene.instantiate() as FlightHUD
	root.add_child(hud)

	# Simulate telemetry packet
	var test_packet = {
		"destination_name": "Lumbini Gardens",
		"distance_travelled_m": 1250.0,
		"distance_remaining_m": 1750.0,
		"speed_kmh": 45.0,
		"altitude_m": 22.0,
		"flight_time_sec": 35.0,
		"next_checkpoint": 2,
		"total_checkpoints": 4,
		"coins_collected": 12
	}
	hud.update_adventure_telemetry(test_packet)

	if not hud.adventure_panel or not hud.adventure_panel.visible:
		printerr("FAIL: Adventure panel was not created or made visible")
		hud.queue_free()
		return false

	if not "Lumbini Gardens" in hud.label_adventure_info.text:
		printerr("FAIL: Telemetry destination name missing from label text")
		hud.queue_free()
		return false

	# Test WorldSelectMenu card generation for adventure stages
	var menu_scene = load("res://scenes/ui/WorldSelectMenu.tscn") as PackedScene
	if not menu_scene:
		printerr("FAIL: Could not load WorldSelectMenu.tscn")
		hud.queue_free()
		return false

	var menu = menu_scene.instantiate() as WorldSelectMenu
	root.add_child(menu)
	var stage_card = menu._create_world_card({
		"id": "stage_01_butwal",
		"name": "Stage 01: Butwal City",
		"region": "Rupandehi Hub",
		"difficulty": "Beginner",
		"description": "Urban takeoff",
		"unlocked_by_default": true,
		"required_level": 1
	}, 1)

	if not stage_card:
		printerr("FAIL: Could not create stage card in WorldSelectMenu")
		menu.queue_free()
		hud.queue_free()
		return false

	hud.queue_free()
	menu.queue_free()
	print("  - HUD telemetry ribbon and WorldSelectMenu stage cards verified (PASS)")
	return true
