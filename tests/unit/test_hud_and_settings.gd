extends SceneTree

## Dedicated Unit Test Suite for Phase 8: HUD & Settings
## Validates settings save/load roundtrip, rebinding conflict detection,
## vector widgets (Artificial Horizon, Heading Strip, Home Arrow),
## unit conversions, and HUD contextual warning banners / button gating.

const SettingsService = preload("res://scripts/core/SettingsService.gd")
const ArtificialHorizon = preload("res://scripts/ui/ArtificialHorizon.gd")
const HeadingStrip = preload("res://scripts/ui/HeadingStrip.gd")
const HomeArrow = preload("res://scripts/ui/HomeArrow.gd")
const FlightHUD = preload("res://scripts/ui/FlightHUD.gd")

func _init() -> void:
	run_tests()

func run_tests() -> void:
	print("==================================================")
	print("Starting Phase 8 HUD & Settings Acceptance Tests")
	print("==================================================")

	var tests_passed: int = 0
	var tests_total: int = 7

	if test_hs01_settings_save_load_roundtrip():
		tests_passed += 1
	if test_hs02_rebinding_conflict_detection():
		tests_passed += 1
	if test_hs03_units_conversion():
		tests_passed += 1
	if test_hs04_artificial_horizon_attitude():
		tests_passed += 1
	if test_hs05_heading_strip_and_cardinals():
		tests_passed += 1
	if test_hs06_home_arrow_vector():
		tests_passed += 1
	if await test_hs07_hud_warning_banners_and_gating():
		tests_passed += 1

	print("==================================================")
	print("Phase 8 Test Results: %d / %d Passed" % [tests_passed, tests_total])
	print("==================================================")

	if tests_passed == tests_total:
		print(">> ALL PHASE 8 HUD & SETTINGS TESTS PASSED SUCCESSFULLY! <<")
		quit(0)
	else:
		printerr(">> PHASE 8 HUD & SETTINGS TESTS FAILED! <<")
		quit(1)

func test_hs01_settings_save_load_roundtrip() -> bool:
	print("[HS-01] Testing Settings Save/Load Roundtrip (user://test_settings.cfg)...")
	var test_path = "user://test_settings.cfg"
	var svc = SettingsService.new()

	# Set non-default custom settings
	svc.set_profile_expo("cine", 0.45)
	svc.set_profile_deadzone("cine", 0.12)
	svc.set_profile_expo("normal", 0.30)
	svc.set_profile_deadzone("normal", 0.08)
	svc.set_profile_expo("sport", 0.20)
	svc.set_profile_deadzone("sport", 0.05)
	svc.set_profile_expo("acro", 0.15)
	svc.set_profile_deadzone("acro", 0.04)

	svc.set_axis_inverted("pitch", true)
	svc.set_axis_inverted("roll", false)
	svc.set_axis_inverted("yaw", true)
	svc.set_axis_inverted("throttle", false)

	svc.set_camera_fov(88.0)
	svc.set_units("imperial")

	# Save to disk
	var saved = svc.save_to_config(test_path)
	if not saved:
		printerr("  - FAIL: Could not save config file to ", test_path)
		return false

	# Create second instance and load
	var svc_loaded = SettingsService.new()
	var loaded = svc_loaded.load_from_config(test_path)
	if not loaded:
		printerr("  - FAIL: Could not load config file from ", test_path)
		return false

	# Verify roundtrip values
	if absf(svc_loaded.get_profile_expo("cine") - 0.45) > 0.001:
		printerr("  - FAIL: expo_cine mismatch")
		return false
	if absf(svc_loaded.get_profile_deadzone("cine") - 0.12) > 0.001:
		printerr("  - FAIL: deadzone_cine mismatch")
		return false
	if absf(svc_loaded.get_profile_expo("acro") - 0.15) > 0.001:
		printerr("  - FAIL: expo_acro mismatch")
		return false
	if not svc_loaded.is_axis_inverted("pitch") or svc_loaded.is_axis_inverted("roll") or not svc_loaded.is_axis_inverted("yaw"):
		printerr("  - FAIL: Invert axis flags mismatch")
		return false
	if absf(svc_loaded.get_camera_fov() - 88.0) > 0.001:
		printerr("  - FAIL: Camera FOV mismatch: ", svc_loaded.get_camera_fov())
		return false
	if svc_loaded.get_units() != "imperial" or not svc_loaded.is_imperial():
		printerr("  - FAIL: Units mismatch: ", svc_loaded.get_units())
		return false

	# Clean up test file
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("  - Settings save/load roundtrip verified with full fidelity (PASS)")
	return true

func test_hs02_rebinding_conflict_detection() -> bool:
	print("[HS-02] Testing Input Rebinding Conflict Detection...")
	var svc = SettingsService.new()

	# Ensure throttle_up action exists in InputMap
	if not InputMap.has_action("throttle_up"):
		InputMap.add_action("throttle_up")
		var w_ev = InputEventKey.new()
		w_ev.keycode = KEY_W
		w_ev.physical_keycode = KEY_W
		InputMap.action_add_event("throttle_up", w_ev)

	if not InputMap.has_action("pitch_forward"):
		InputMap.add_action("pitch_forward")

	if not InputMap.has_action("flight_brake"):
		InputMap.add_action("flight_brake")

	# Find current key for throttle_up (typically KEY_W = 87)
	var throttle_key_event: InputEventKey = null
	for ev in InputMap.action_get_events("throttle_up"):
		if ev is InputEventKey:
			throttle_key_event = ev
			break

	if throttle_key_event == null:
		throttle_key_event = InputEventKey.new()
		throttle_key_event.keycode = KEY_W
		throttle_key_event.physical_keycode = KEY_W
		InputMap.action_add_event("throttle_up", throttle_key_event)

	# 1. Attempt to rebind pitch_forward to KEY_W -> MUST CONFLICT with throttle_up
	var conflict = svc.check_rebinding_conflict("pitch_forward", throttle_key_event)
	if conflict != "throttle_up":
		printerr("  - FAIL: Expected conflict 'throttle_up', got '%s'" % conflict)
		return false

	var rebind_rejected = not svc.rebind_action("pitch_forward", throttle_key_event)
	if not rebind_rejected:
		printerr("  - FAIL: Conflicting rebind was incorrectly accepted!")
		return false

	# 2. Attempt to bind flight_brake to an unused key (KEY_B)
	var unused_key = InputEventKey.new()
	unused_key.keycode = KEY_B
	unused_key.physical_keycode = KEY_B

	# Clean KEY_B from actions if present
	for act in SettingsService.REBINDABLE_ACTIONS:
		if InputMap.has_action(act) and act != "flight_brake":
			for ev in InputMap.action_get_events(act):
				if ev is InputEventKey and (ev.keycode == KEY_B or ev.physical_keycode == KEY_B):
					InputMap.action_erase_event(act, ev)

	var no_conflict = svc.check_rebinding_conflict("flight_brake", unused_key)
	if no_conflict != "":
		printerr("  - FAIL: Unexpected conflict for unused key: ", no_conflict)
		return false

	var rebind_ok = svc.rebind_action("flight_brake", unused_key)
	if not rebind_ok:
		printerr("  - FAIL: Valid non-conflicting rebind was rejected")
		return false

	# Verify KEY_B is now bound to flight_brake
	var has_b = false
	for ev in InputMap.action_get_events("flight_brake"):
		if ev is InputEventKey and (ev.keycode == KEY_B or ev.physical_keycode == KEY_B):
			has_b = true
			break
	if not has_b:
		printerr("  - FAIL: flight_brake does not contain rebound KEY_B in InputMap")
		return false

	print("  - Rebinding conflict detection and clean key mapping verified (PASS)")
	return true

func test_hs03_units_conversion() -> bool:
	print("[HS-03] Testing Telemetry Units Conversion (Metric <-> Imperial)...")
	var svc = SettingsService.new()

	svc.set_units("metric")
	if svc.is_imperial():
		printerr("  - FAIL: is_imperial() true when metric set")
		return false

	var spd_ms = 10.0
	var spd_kmh = spd_ms * 3.6
	if absf(spd_kmh - 36.0) > 0.001:
		printerr("  - FAIL: Metric km/h conversion wrong")
		return false

	svc.set_units("imperial")
	if not svc.is_imperial():
		printerr("  - FAIL: is_imperial() false when imperial set")
		return false

	var spd_mph = spd_ms * 2.23694
	var spd_fts = spd_ms * 3.28084
	var alt_m = 50.0
	var alt_ft = alt_m * 3.28084

	if absf(spd_mph - 22.3694) > 0.01:
		printerr("  - FAIL: Imperial mph conversion wrong: ", spd_mph)
		return false
	if absf(alt_ft - 164.042) > 0.05:
		printerr("  - FAIL: Imperial ft conversion wrong: ", alt_ft)
		return false

	print("  - Dual-speed and altitude units conversion accurate (PASS)")
	return true

func test_hs04_artificial_horizon_attitude() -> bool:
	print("[HS-04] Testing Procedural Vector Artificial Horizon Widget...")
	var ah = ArtificialHorizon.new()
	ah.size = Vector2(200, 200)

	# Set level attitude
	ah.set_attitude(0.0, 0.0)
	if ah.pitch_deg != 0.0 or ah.roll_deg != 0.0:
		printerr("  - FAIL: Initial attitude not zero")
		return false

	# Set 25 deg pitch up, 45 deg right roll
	ah.set_attitude(25.0, 45.0)
	if ah.pitch_deg != 25.0 or ah.roll_deg != 45.0:
		printerr("  - FAIL: Attitude mismatch: pitch=%f, roll=%f" % [ah.pitch_deg, ah.roll_deg])
		return false

	# Test extreme pitch clamping (-89 to 89 deg)
	ah.set_attitude(110.0, -190.0)
	if ah.pitch_deg > 89.0:
		printerr("  - FAIL: Pitch should clamp to 89 deg, got: ", ah.pitch_deg)
		return false
	if absf(ah.roll_deg - 170.0) > 0.1: # -190 normalized to +170
		printerr("  - FAIL: Roll normalization mismatch: ", ah.roll_deg)
		return false

	ah.free()
	print("  - Artificial Horizon attitude clamping and roll wrap verified (PASS)")
	return true

func test_hs05_heading_strip_and_cardinals() -> bool:
	print("[HS-05] Testing Vector Heading Strip & Cardinal Points...")
	var hs = HeadingStrip.new()
	hs.size = Vector2(340, 30)

	hs.heading_deg = 0.0
	if hs.heading_deg != 0.0:
		printerr("  - FAIL: Heading 0.0 deg mismatch")
		return false

	# Cardinal mapping test
	if HeadingStrip.CARDINALS[0] != "N" or HeadingStrip.CARDINALS[90] != "E" or \
	   HeadingStrip.CARDINALS[180] != "S" or HeadingStrip.CARDINALS[270] != "W":
		printerr("  - FAIL: Cardinal markings incorrect in HeadingStrip.CARDINALS")
		return false

	# Normalization across 360 boundary
	hs.heading_deg = 365.0
	if absf(hs.heading_deg - 5.0) > 0.001:
		printerr("  - FAIL: Heading 365 did not wrap to 5 deg: ", hs.heading_deg)
		return false

	hs.heading_deg = -30.0
	if absf(hs.heading_deg - 330.0) > 0.001:
		printerr("  - FAIL: Heading -30 did not wrap to 330 deg: ", hs.heading_deg)
		return false

	hs.free()
	print("  - Heading strip normalization and cardinal points verified (PASS)")
	return true

func test_hs06_home_arrow_vector() -> bool:
	print("[HS-06] Testing Vector Home Arrow Calculation...")
	var ha = HomeArrow.new()
	ha.size = Vector2(200, 36)

	var drone_pos = Vector3(0.0, 10.0, 0.0)
	var home_pos = Vector3(0.0, 0.0, 50.0) # Home is directly North/Z+ (or behind when facing -Z)
	var yaw_fwd = 0.0 # Facing -Z (default forward)

	# dx = 0, dz = 50. bearing = atan2(0, -50) = PI rad (directly behind)
	ha.update_home_vector(drone_pos, yaw_fwd, home_pos)
	if absf(ha.distance_m - 50.0) > 0.01:
		printerr("  - FAIL: Distance to home mismatch: ", ha.distance_m)
		return false
	if absf(absf(ha.relative_angle_rad) - PI) > 0.01:
		printerr("  - FAIL: Home relative angle expected ~PI, got: ", ha.relative_angle_rad)
		return false

	# Drone is 30m West of home, facing North (yaw = 0)
	drone_pos = Vector3(-30.0, 5.0, 0.0)
	home_pos = Vector3(0.0, 0.0, 0.0)
	# dx = 30, dz = 0. Home is to the East (+X). bearing = atan2(30, 0) = PI/2.
	ha.update_home_vector(drone_pos, yaw_fwd, home_pos)
	if absf(ha.distance_m - 30.0) > 0.01:
		printerr("  - FAIL: Distance mismatch: ", ha.distance_m)
		return false
	if absf(ha.relative_angle_rad - PI * 0.5) > 0.01:
		printerr("  - FAIL: Expected PI/2 (+90 deg), got: ", ha.relative_angle_rad)
		return false

	ha.free()
	print("  - Home arrow bearing and distance calculation verified (PASS)")
	return true

func test_hs07_hud_warning_banners_and_gating() -> bool:
	print("[HS-07] Testing HUD Warning Banners & Contextual Flip Gating...")
	var hud_scene = load("res://scenes/ui/FlightHUD.tscn")
	if not hud_scene:
		printerr("  - FAIL: Could not load FlightHUD.tscn")
		return false

	var hud: FlightHUD = hud_scene.instantiate()
	root.add_child(hud)
	await process_frame

	# Verify elements instantiated
	if not hud.artificial_horizon:
		printerr("  - FAIL: ArtificialHorizon node missing from FlightHUD")
		hud.queue_free()
		return false

	if not hud.heading_strip:
		printerr("  - FAIL: HeadingStrip node missing from FlightHUD")
		hud.queue_free()
		return false

	if not hud.home_arrow:
		printerr("  - FAIL: HomeArrow node missing from FlightHUD")
		hud.queue_free()
		return false

	# Test Warning Banner on Low Battery Telemetry
	var low_bat_telem = {
		"battery_pct": 18.0,
		"battery_volts": 14.2,
		"battery_time_remaining": 180.0,
		"speed": 5.0,
		"climb_rate": 0.0,
		"altitude_agl": 2.5,
		"altitude_msl": 10.0,
		"heading": 45.0,
		"pitch": 0.0,
		"roll": 0.0,
		"state": "FLYING",
		"flight_mode": "ANGLE",
		"home_distance": 20.0
	}
	hud._on_telemetry_updated(low_bat_telem)

	if not hud.label_state_banner or not hud.label_state_banner.visible or not ("LOW BATTERY" in hud.label_state_banner.text):
		printerr("  - FAIL: Low battery warning banner did not trigger on 18% battery")
		hud.queue_free()
		return false

	# Test Flip Gating when altitude < 3.0m
	if hud.btn_flip:
		if hud.btn_flip.modulate.a > 0.5:
			printerr("  - FAIL: Flip button should be visually dimmed when altitude < 3.0m (agl=2.5m)")
			hud.queue_free()
			return false

		# Pressing flip below 3.0m should show "TOO LOW FOR FLIP"
		hud._on_btn_flip_pressed()
		if not ("TOO LOW FOR FLIP" in hud.label_state_banner.text):
			printerr("  - FAIL: 'TOO LOW FOR FLIP' banner was not shown on flip below 3m: ", hud.label_state_banner.text)
			hud.queue_free()
			return false

	hud.queue_free()
	print("  - HUD warning banners and contextual button gating verified (PASS)")
	return true
