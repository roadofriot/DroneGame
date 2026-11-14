class_name SettingsService
extends RefCounted

## SettingsService: Graphics visual scalability presets, per-profile expo/deadzone,
## axis inversion, camera FOV, units, key/gamepad rebinding with conflict detection,
## and persistent configuration in user://settings.cfg.

signal settings_changed(settings_dict: Dictionary)
signal preset_applied(preset_name: String)
signal rebinding_changed(action_name: String, event: InputEvent)
signal trim_reset_requested

const SETTINGS_CONFIG_PATH: String = "user://settings.cfg"

const REBINDABLE_ACTIONS: Array[String] = [
	"throttle_up",
	"throttle_down",
	"yaw_left",
	"yaw_right",
	"pitch_forward",
	"pitch_backward",
	"roll_left",
	"roll_right",
	"takeoff",
	"flight_flip",
	"flight_brake",
	"flight_boost",
	"flight_headless_toggle"
]

const QUALITY_PRESETS = {
	"low": {
		"name": "Performance / Mobile",
		"shadows": false,
		"msaa": Viewport.MSAA_DISABLED,
		"ssao": false,
		"glow": false,
		"render_scale": 0.8,
		"description": "Optimized for high framerates on entry-level mobile and integrated GPUs."
	},
	"medium": {
		"name": "Balanced",
		"shadows": true,
		"msaa": Viewport.MSAA_2X,
		"ssao": false,
		"glow": true,
		"render_scale": 1.0,
		"description": "Recommended balance of crisp visual clarity and smooth 60 FPS performance."
	},
	"high": {
		"name": "High / Forward+",
		"shadows": true,
		"msaa": Viewport.MSAA_4X,
		"ssao": true,
		"glow": true,
		"render_scale": 1.0,
		"description": "Full desktop visual fidelity with directional contact shadows, SSAO, and MSAA 4x."
	}
}

var current_settings: Dictionary = {
	"quality_preset": "medium",
	"master_volume": 1.0,
	"sfx_volume": 0.8,
	"motor_volume": 0.7,
	"wind_volume": 0.5,
	"mute": false,

	# Per-profile Expo & Deadzone
	"expo_cine": 0.35,
	"deadzone_cine": 0.08,
	"expo_normal": 0.25,
	"deadzone_normal": 0.06,
	"expo_sport": 0.15,
	"deadzone_sport": 0.04,
	"expo_acro": 0.10,
	"deadzone_acro": 0.03,

	# Axis Inversion
	"invert_pitch": false,
	"invert_roll": false,
	"invert_yaw": false,
	"invert_throttle": false,

	# Camera & Units
	"camera_fov": 75.0,
	"units": "metric", # "metric" or "imperial"

	# Custom Input Rebinds dictionary: action -> keycode
	"custom_bindings": {}
}

func _init() -> void:
	load_from_config()
	load_settings()

# -----------------------------------------------------------------------------
# Configuration Persistence (user://settings.cfg)
# -----------------------------------------------------------------------------
func save_to_config(path: String = SETTINGS_CONFIG_PATH) -> bool:
	var config = ConfigFile.new()

	# Audio
	config.set_value("audio", "master_volume", current_settings.get("master_volume", 1.0))
	config.set_value("audio", "sfx_volume", current_settings.get("sfx_volume", 0.8))
	config.set_value("audio", "motor_volume", current_settings.get("motor_volume", 0.7))
	config.set_value("audio", "wind_volume", current_settings.get("wind_volume", 0.5))
	config.set_value("audio", "mute", current_settings.get("mute", false))

	# Video
	config.set_value("video", "quality_preset", current_settings.get("quality_preset", "medium"))
	config.set_value("video", "camera_fov", current_settings.get("camera_fov", 75.0))

	# Controls: Expo & Deadzones
	config.set_value("controls", "expo_cine", current_settings.get("expo_cine", 0.35))
	config.set_value("controls", "deadzone_cine", current_settings.get("deadzone_cine", 0.08))
	config.set_value("controls", "expo_normal", current_settings.get("expo_normal", 0.25))
	config.set_value("controls", "deadzone_normal", current_settings.get("deadzone_normal", 0.06))
	config.set_value("controls", "expo_sport", current_settings.get("expo_sport", 0.15))
	config.set_value("controls", "deadzone_sport", current_settings.get("deadzone_sport", 0.04))
	config.set_value("controls", "expo_acro", current_settings.get("expo_acro", 0.10))
	config.set_value("controls", "deadzone_acro", current_settings.get("deadzone_acro", 0.03))

	# Controls: Axis Inverts
	config.set_value("controls", "invert_pitch", current_settings.get("invert_pitch", false))
	config.set_value("controls", "invert_roll", current_settings.get("invert_roll", false))
	config.set_value("controls", "invert_yaw", current_settings.get("invert_yaw", false))
	config.set_value("controls", "invert_throttle", current_settings.get("invert_throttle", false))

	# Gameplay
	config.set_value("gameplay", "units", current_settings.get("units", "metric"))

	# Custom Keybindings
	var binds = current_settings.get("custom_bindings", {})
	for act in binds.keys():
		config.set_value("bindings", act, binds[act])

	var err = config.save(path)
	if err == OK:
		settings_changed.emit(current_settings)
		return true
	return false

func load_from_config(path: String = SETTINGS_CONFIG_PATH) -> bool:
	var config = ConfigFile.new()
	var err = config.load(path)
	if err != OK:
		return false

	# Audio
	current_settings["master_volume"] = config.get_value("audio", "master_volume", current_settings["master_volume"])
	current_settings["sfx_volume"] = config.get_value("audio", "sfx_volume", current_settings["sfx_volume"])
	current_settings["motor_volume"] = config.get_value("audio", "motor_volume", current_settings["motor_volume"])
	current_settings["wind_volume"] = config.get_value("audio", "wind_volume", current_settings["wind_volume"])
	current_settings["mute"] = config.get_value("audio", "mute", current_settings["mute"])

	# Video
	current_settings["quality_preset"] = config.get_value("video", "quality_preset", current_settings["quality_preset"])
	current_settings["camera_fov"] = config.get_value("video", "camera_fov", current_settings["camera_fov"])

	# Controls
	for prof in ["cine", "normal", "sport", "acro"]:
		current_settings["expo_" + prof] = config.get_value("controls", "expo_" + prof, current_settings["expo_" + prof])
		current_settings["deadzone_" + prof] = config.get_value("controls", "deadzone_" + prof, current_settings["deadzone_" + prof])

	current_settings["invert_pitch"] = config.get_value("controls", "invert_pitch", current_settings["invert_pitch"])
	current_settings["invert_roll"] = config.get_value("controls", "invert_roll", current_settings["invert_roll"])
	current_settings["invert_yaw"] = config.get_value("controls", "invert_yaw", current_settings["invert_yaw"])
	current_settings["invert_throttle"] = config.get_value("controls", "invert_throttle", current_settings["invert_throttle"])

	# Gameplay
	current_settings["units"] = config.get_value("gameplay", "units", current_settings["units"])

	# Custom Keybindings
	if config.has_section("bindings"):
		var binds: Dictionary = {}
		for act in config.get_section_keys("bindings"):
			var keycode = config.get_value("bindings", act)
			binds[act] = keycode
			_apply_rebind_to_input_map(act, keycode)
		current_settings["custom_bindings"] = binds

	return true

func load_settings() -> void:
	var save_data = SaveService.load_game()
	var saved_settings = save_data.get("settings", {})
	if not saved_settings.is_empty():
		for k in saved_settings.keys():
			current_settings[k] = saved_settings[k]

func save_settings() -> bool:
	save_to_config(SETTINGS_CONFIG_PATH)
	var save_data = SaveService.load_game()
	save_data["settings"] = current_settings
	var ok = SaveService.save_game(save_data)
	if ok:
		settings_changed.emit(current_settings)
	return ok

# -----------------------------------------------------------------------------
# Expo, Deadzone & Tuning Getters / Setters
# -----------------------------------------------------------------------------
func get_profile_expo(profile: String) -> float:
	var key = "expo_" + profile.to_lower()
	return current_settings.get(key, 0.25)

func set_profile_expo(profile: String, val: float) -> void:
	var key = "expo_" + profile.to_lower()
	current_settings[key] = clampf(val, 0.0, 0.95)

func get_profile_deadzone(profile: String) -> float:
	var key = "deadzone_" + profile.to_lower()
	return current_settings.get(key, 0.06)

func set_profile_deadzone(profile: String, val: float) -> void:
	var key = "deadzone_" + profile.to_lower()
	current_settings[key] = clampf(val, 0.0, 0.4)

func is_axis_inverted(axis_name: String) -> bool:
	var key = "invert_" + axis_name.to_lower()
	return current_settings.get(key, false)

func set_axis_inverted(axis_name: String, inverted: bool) -> void:
	var key = "invert_" + axis_name.to_lower()
	current_settings[key] = inverted

func get_camera_fov() -> float:
	return current_settings.get("camera_fov", 75.0)

func set_camera_fov(fov: float) -> void:
	current_settings["camera_fov"] = clampf(fov, 60.0, 105.0)

func get_units() -> String:
	return current_settings.get("units", "metric")

func set_units(unit_type: String) -> void:
	if unit_type.to_lower() in ["metric", "imperial"]:
		current_settings["units"] = unit_type.to_lower()

func is_imperial() -> bool:
	return get_units() == "imperial"

func request_trim_reset() -> void:
	trim_reset_requested.emit()

# -----------------------------------------------------------------------------
# Input Rebinding & Conflict Detection
# -----------------------------------------------------------------------------
func check_rebinding_conflict(target_action: String, new_event: InputEvent) -> String:
	## Returns the name of any other action that already uses new_event, or "" if none.
	if not new_event is InputEventKey and not new_event is InputEventJoypadButton:
		return ""

	for action in REBINDABLE_ACTIONS:
		if action == target_action:
			continue
		if not InputMap.has_action(action):
			continue

		for event in InputMap.action_get_events(action):
			if events_match(event, new_event):
				return action
	return ""

func events_match(e1: InputEvent, e2: InputEvent) -> bool:
	if e1 is InputEventKey and e2 is InputEventKey:
		var k1 = e1.physical_keycode if e1.physical_keycode != 0 else e1.keycode
		var k2 = e2.physical_keycode if e2.physical_keycode != 0 else e2.keycode
		return k1 == k2
	elif e1 is InputEventJoypadButton and e2 is InputEventJoypadButton:
		return e1.button_index == e2.button_index
	return false

func rebind_action(action_name: String, new_event: InputEvent) -> bool:
	if not InputMap.has_action(action_name):
		return false

	var conflict = check_rebinding_conflict(action_name, new_event)
	if conflict != "":
		return false # Conflict detected, reject rebind

	# Remove existing events of same type (Key vs Joypad)
	var existing = InputMap.action_get_events(action_name)
	for ev in existing:
		if (new_event is InputEventKey and ev is InputEventKey) or \
		   (new_event is InputEventJoypadButton and ev is InputEventJoypadButton):
			InputMap.action_erase_event(action_name, ev)

	InputMap.action_add_event(action_name, new_event)

	# Store in settings dict
	var binds = current_settings.get("custom_bindings", {})
	if new_event is InputEventKey:
		var kcode = new_event.physical_keycode if new_event.physical_keycode != 0 else new_event.keycode
		binds[action_name] = kcode
	current_settings["custom_bindings"] = binds

	rebinding_changed.emit(action_name, new_event)
	save_to_config()
	return true

func _apply_rebind_to_input_map(action_name: String, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		return
	var new_ev = InputEventKey.new()
	new_ev.physical_keycode = keycode as Key
	new_ev.keycode = keycode as Key

	var existing = InputMap.action_get_events(action_name)
	for ev in existing:
		if ev is InputEventKey:
			InputMap.action_erase_event(action_name, ev)
	InputMap.action_add_event(action_name, new_ev)

func get_action_binding_text(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "NONE"
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventKey:
			var kcode = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			return OS.get_keycode_string(kcode)
		elif ev is InputEventJoypadButton:
			return "Joypad %d" % ev.button_index
	return "DEFAULT"

# -----------------------------------------------------------------------------
# Quality Presets
# -----------------------------------------------------------------------------
func get_current_preset_key() -> String:
	return current_settings.get("quality_preset", "medium")

func get_preset_def(preset_key: String) -> Dictionary:
	return QUALITY_PRESETS.get(preset_key.to_lower(), QUALITY_PRESETS["medium"])

func apply_quality_preset(preset_key: String, viewport: Viewport = null, env: Environment = null) -> bool:
	var key = preset_key.to_lower()
	if not QUALITY_PRESETS.has(key):
		push_error("SettingsService: Unknown quality preset '%s'" % preset_key)
		return false

	var cfg = QUALITY_PRESETS[key]
	current_settings["quality_preset"] = key

	if viewport:
		viewport.msaa_3d = cfg.get("msaa", Viewport.MSAA_2X)
		viewport.scaling_3d_scale = cfg.get("render_scale", 1.0)

	if env:
		if OS.get_name() != "Android" and OS.get_name() != "iOS":
			env.ssao_enabled = cfg.get("ssao", false)
		else:
			env.ssao_enabled = false
		env.glow_enabled = cfg.get("glow", true)

	preset_applied.emit(key)
	save_settings()
	return true
