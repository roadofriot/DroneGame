class_name SettingsService
extends RefCounted

## SettingsService: Graphics visual scalability presets (Low/Medium/High),
## audio volume preferences, and persistent configuration management.

signal settings_changed(settings_dict: Dictionary)
signal preset_applied(preset_name: String)

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
	"mute": false
}

func _init() -> void:
	load_settings()

func load_settings() -> void:
	var save_data = SaveService.load_game()
	var saved_settings = save_data.get("settings", {})
	if not saved_settings.is_empty():
		for k in saved_settings.keys():
			current_settings[k] = saved_settings[k]

func save_settings() -> bool:
	var save_data = SaveService.load_game()
	save_data["settings"] = current_settings
	var ok = SaveService.save_game(save_data)
	if ok:
		settings_changed.emit(current_settings)
	return ok

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
