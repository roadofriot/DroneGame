extends SceneTree

## Headless Unit and Integration Test Runner for Phase 5: Real Location Explorer
## Tests Geographical Geocaching, Web Mercator Projection, GPS Privacy Disclosure,
## 2D Map Rendering, and Procedural Training World Generation.

const MapProviderService = preload("res://scripts/maps/MapProviderService.gd")
const GPSPermissionService = preload("res://scripts/maps/GPSPermissionService.gd")
const RealLocationExplorerScene = preload("res://scenes/maps/RealLocationExplorer.tscn")
const ProceduralLocationWorldScene = preload("res://scenes/worlds/ProceduralLocationWorld.tscn")
const FlightWorldScene = preload("res://scenes/flight/FlightWorld.tscn")

func _init() -> void:
	print("==================================================")
	print("Starting MindSparQ Drone Simulator Phase 5 Tests")
	print("Real Location Explorer & Offline Cartographic Engine")
	print("==================================================")

	var tests_passed: int = 0
	var tests_total: int = 6

	if test_le01_geocache_and_provider_attribution():
		tests_passed += 1
	if test_le02_search_query_matching_and_coordinates():
		tests_passed += 1
	if test_le03_mercator_projection_roundtrip():
		tests_passed += 1
	if test_le04_gps_privacy_and_permission_state_machine():
		tests_passed += 1
	if test_le05_explorer_ui_integration():
		tests_passed += 1
	if test_le06_procedural_location_world_generation():
		tests_passed += 1

	print("==================================================")
	print("Phase 5 Test Results: %d / %d Passed" % [tests_passed, tests_total])
	print("==================================================")

	if tests_passed == tests_total:
		print(">> ALL PHASE 5 ACCEPTANCE TESTS PASSED SUCCESSFULLY! <<")
		quit(0)
	else:
		printerr(">> PHASE 5 TESTS FAILED! <<")
		quit(1)

func test_le01_geocache_and_provider_attribution() -> bool:
	print("[LE-01] Testing Offline Geocache Schema & Attribution Requirements...")
	var attr = MapProviderService.get_attribution()
	if not "OpenStreetMap" in attr or not "ODbL" in attr:
		printerr("FAIL: Attribution notice missing mandatory OSM/ODbL disclosure: ", attr)
		return false

	var def_loc = MapProviderService.get_default_location()
	if def_loc.get("name") != "Butwal" or absf(def_loc.get("lat") - 27.7006) > 0.01:
		printerr("FAIL: Default location is not Butwal: ", def_loc)
		return false

	for loc in MapProviderService.OFFLINE_LOCATIONS:
		if not loc.has("id") or not loc.has("lat") or not loc.has("lon") or not loc.has("elevation_m"):
			printerr("FAIL: Malformed offline location entry: ", loc)
			return false

	print("  - Mandatory OSM/ODbL attribution text and offline location database verified (PASS)")
	return true

func test_le02_search_query_matching_and_coordinates() -> bool:
	print("[LE-02] Testing Substring Query Matching & Coordinate Input Parsing...")
	# 1. Exact / Substring search
	var res_butwal = MapProviderService.search_locations("butwal")
	if res_butwal.is_empty() or res_butwal[0].get("name") != "Butwal":
		printerr("FAIL: Search 'butwal' returned no results")
		return false

	if not res_butwal[0].get("has_authored_game_world") or res_butwal[0].get("game_world_id") != "butwal_city":
		printerr("FAIL: Butwal did not link to authored game world 'butwal_city'")
		return false

	# 2. Regional search
	var res_nepal = MapProviderService.search_locations("nepal")
	if res_nepal.size() < 4:
		printerr("FAIL: Expected at least 4 Nepal locations, found %d" % res_nepal.size())
		return false

	# 3. Coordinate parsing
	var res_coords = MapProviderService.search_locations("27.7006, 83.4484")
	if res_coords.is_empty():
		printerr("FAIL: Coordinate search returned no parsed result")
		return false

	var parsed_point = res_coords[0]
	if absf(parsed_point.get("lat") - 27.7006) > 0.001 or absf(parsed_point.get("lon") - 83.4484) > 0.001:
		printerr("FAIL: Coordinate parsing inaccuracy: ", parsed_point)
		return false

	print("  - Search engine correctly matched text queries, region filters, and parsed direct lat/lon (PASS)")
	return true

func test_le03_mercator_projection_roundtrip() -> bool:
	print("[LE-03] Testing Web Mercator Projection & Coordinate Roundtrip Math...")
	var test_lat = 27.7006
	var test_lon = 83.4484

	var merc = MapProviderService.lat_lon_to_mercator(test_lat, test_lon)
	if merc.x < 0.0 or merc.x > 1.0 or merc.y < 0.0 or merc.y > 1.0:
		printerr("FAIL: Mercator coordinates out of [0, 1] range: ", merc)
		return false

	var inverted = MapProviderService.mercator_to_lat_lon(merc)
	var lat_err = absf(inverted.x - test_lat)
	var lon_err = absf(inverted.y - test_lon)

	if lat_err > 0.001 or lon_err > 0.001:
		printerr("FAIL: Mercator inversion error exceeded tolerance: lat_err=%f, lon_err=%f" % [lat_err, lon_err])
		return false

	print("  - Web Mercator projection roundtrip exact within 0.001 degrees (PASS)")
	return true

func test_le04_gps_privacy_and_permission_state_machine() -> bool:
	print("[LE-04] Testing GPS Permission State Machine & Privacy Disclosure...")
	var gps = GPSPermissionService.new()

	# 1. Verification of disclosure
	var disclosure = gps.get_disclosure_text()
	if not "GPS location is used solely" in disclosure:
		printerr("FAIL: Privacy disclosure missing required rationale: ", disclosure)
		return false

	# 2. Permission Denied flow
	var denied_called = [false, ""]
	gps.permission_denied.connect(func(expl):
		denied_called[0] = true
		denied_called[1] = expl
	)
	gps.simulate_permission_response(false)
	if gps.current_status != GPSPermissionService.PermissionStatus.DENIED or not denied_called[0]:
		printerr("FAIL: Permission denial state not handled properly")
		return false

	# 3. Permission Granted flow
	var acquired_called = [false, 0.0, 0.0]
	gps.location_acquired.connect(func(lat, lon, _acc, _ts):
		acquired_called[0] = true
		acquired_called[1] = lat
		acquired_called[2] = lon
	)
	gps.simulate_permission_response(true, 28.2096, 83.9856, 12.0)
	if gps.current_status != GPSPermissionService.PermissionStatus.GRANTED or not acquired_called[0]:
		printerr("FAIL: Permission grant state not handled properly")
		return false

	var pos = gps.get_last_known_position()
	if absf(pos.get("lat") - 28.2096) > 0.001:
		printerr("FAIL: Acquired position incorrect: ", pos)
		return false

	# 4. Clear data
	gps.clear_location_data()
	if gps.current_status != GPSPermissionService.PermissionStatus.NOT_REQUESTED or gps.last_latitude != 0.0:
		printerr("FAIL: Clear location data did not purge memory")
		return false

	print("  - GPS privacy state machine, permission gating, and data purge verified (PASS)")
	return true

func test_le05_explorer_ui_integration() -> bool:
	print("[LE-05] Testing RealLocationExplorer UI Interaction & Location Selection...")
	var explorer: RealLocationExplorer = RealLocationExplorerScene.instantiate()
	root.add_child(explorer)
	if not explorer.is_node_ready():
		explorer._ready()

	# 1. Initial State
	if explorer.selected_location.get("name") != "Butwal":
		printerr("FAIL: Initial selected location is not Butwal")
		explorer.queue_free()
		return false

	if not explorer.btn_fly_authored.visible:
		printerr("FAIL: Butwal has authored world but BtnFlyAuthored is hidden")
		explorer.queue_free()
		return false

	# 2. Select a location without an authored world (e.g. Tilottama)
	var tilottama = MapProviderService.search_locations("tilottama")[0]
	explorer.select_location(tilottama)

	if explorer.selected_location.get("name") != "Tilottama":
		printerr("FAIL: select_location failed for Tilottama")
		explorer.queue_free()
		return false

	# BtnFlyAuthored should be hidden for procedural-only location
	if explorer.btn_fly_authored.visible:
		printerr("FAIL: BtnFlyAuthored is visible for location without authored world")
		explorer.queue_free()
		return false

	# BtnFlyApproximate should always remain visible
	if not explorer.btn_fly_approximate.visible:
		printerr("FAIL: BtnFlyApproximate is hidden")
		explorer.queue_free()
		return false

	# 3. Canvas updated
	if explorer.map_canvas.location_title != "Tilottama":
		printerr("FAIL: MapCanvas2D title not updated: ", explorer.map_canvas.location_title)
		explorer.queue_free()
		return false

	explorer.queue_free()
	print("  - RealLocationExplorer UI cards, map canvas sync, and authored vs approximate gating verified (PASS)")
	return true

func test_le06_procedural_location_world_generation() -> bool:
	print("[LE-06] Testing Procedural Location World Seeded Terrain Generation...")
	var proc_world: ProceduralLocationWorld = ProceduralLocationWorldScene.instantiate()
	root.add_child(proc_world)
	if not proc_world.is_node_ready():
		proc_world._ready()

	# Test custom Everest coordinates (high alpine elevation)
	proc_world._configure_location(27.9881, 86.9250, "Mount Everest", 8848.0)

	if proc_world.latitude != 27.9881 or proc_world.longitude != 86.9250:
		printerr("FAIL: Coordinates not set on ProceduralLocationWorld")
		proc_world.queue_free()
		return false

	if not proc_world.terrain_mesh_inst or not proc_world.terrain_mesh_inst.mesh:
		printerr("FAIL: Procedural terrain mesh not generated")
		proc_world.queue_free()
		return false

	# Verify banner labeling adheres to Definition of Done ("APPROXIMATE WORLD ... PROCEDURAL TRAINING")
	var banner_text = proc_world.location_banner_text
	if not "APPROXIMATE WORLD" in banner_text or not "PROCEDURAL TRAINING" in banner_text:
		printerr("FAIL: Approximate training world not clearly labeled: ", banner_text)
		proc_world.queue_free()
		return false

	proc_world.queue_free()
	print("  - Procedural training world seeded from real coordinates with explicit approximation labeling (PASS)")
	return true
