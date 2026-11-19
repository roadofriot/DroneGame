class_name SaveService
extends RefCounted

## SaveService: Versioned, corruption-safe player persistence.
## Supports atomic writes, schema migrations, and backup recovery.

const CURRENT_SCHEMA_VERSION: int = 1
const PRIMARY_SAVE_PATH: String = "user://mindsparq_savedata.json"
const BACKUP_SAVE_PATH: String = "user://mindsparq_savedata.bak"

static func get_default_save_data() -> Dictionary:
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"player_profile": {
			"name": "Pilot",
			"level": 1,
			"current_xp": 0,
			"coins_banked": 0,
			"equipped_drone": "scout",
			"unlocked_drones": ["scout"]
		},
		"mission_records": {},
		"claimed_run_hashes": [],
		"settings": {
			"flight_mode": "normal",
			"audio_master": 1.0,
			"audio_music": 0.8,
			"audio_sfx": 0.9,
			"graphics_preset": "high",
			"invert_pitch": false
		}
	}

static func save_game(data: Dictionary) -> bool:
	data["schema_version"] = CURRENT_SCHEMA_VERSION

	var json_string = JSON.stringify(data, "  ")
	var temp_path = PRIMARY_SAVE_PATH + ".tmp"

	# Write to temp file first
	var temp_file = FileAccess.open(temp_path, FileAccess.WRITE)
	if not temp_file:
		printerr("SaveService: Failed to open temp save file for writing: ", temp_path)
		return false

	temp_file.store_string(json_string)
	temp_file.close()

	# Verify written temp file can be parsed
	var check_file = FileAccess.open(temp_path, FileAccess.READ)
	if not check_file:
		printerr("SaveService: Verification read failed on temp file")
		return false

	var test_json = JSON.new()
	var parse_err = test_json.parse(check_file.get_as_text())
	check_file.close()

	if parse_err != OK:
		printerr("SaveService: Temp save file verification failed with parse error: ", parse_err)
		DirAccess.remove_absolute(temp_path)
		return false

	# If primary save exists, rotate it to backup
	if FileAccess.file_exists(PRIMARY_SAVE_PATH):
		if FileAccess.file_exists(BACKUP_SAVE_PATH):
			DirAccess.remove_absolute(BACKUP_SAVE_PATH)
		DirAccess.copy_absolute(PRIMARY_SAVE_PATH, BACKUP_SAVE_PATH)
		DirAccess.remove_absolute(PRIMARY_SAVE_PATH)

	# Promote temp to primary
	var rename_err = DirAccess.rename_absolute(temp_path, PRIMARY_SAVE_PATH)
	if rename_err != OK:
		# Fallback: copy and remove
		DirAccess.copy_absolute(temp_path, PRIMARY_SAVE_PATH)
		DirAccess.remove_absolute(temp_path)

	return true

static func load_game() -> Dictionary:
	var loaded_data = _try_read_save(PRIMARY_SAVE_PATH)
	if loaded_data.is_empty():
		# Try loading from backup
		if FileAccess.file_exists(BACKUP_SAVE_PATH):
			print("SaveService: Primary save missing or corrupt. Attempting recovery from backup...")
			loaded_data = _try_read_save(BACKUP_SAVE_PATH)

	if loaded_data.is_empty():
		print("SaveService: No existing save file found. Initializing default profile.")
		var fresh_data = get_default_save_data()
		save_game(fresh_data)
		return fresh_data

	# Perform schema migrations if needed
	var migrated_data = _migrate_schema_if_needed(loaded_data)
	return migrated_data

static func _try_read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(content) != OK:
		printerr("SaveService: Corrupted JSON at path: ", path)
		return {}

	if json.data is Dictionary:
		return json.data
	return {}

static func _migrate_schema_if_needed(data: Dictionary) -> Dictionary:
	var version = data.get("schema_version", 0)

	if version < 1:
		print("SaveService: Migrating save from v0 to v1...")
		if not data.has("claimed_run_hashes"):
			data["claimed_run_hashes"] = []
		if not data.has("mission_records"):
			data["mission_records"] = {}
		data["schema_version"] = 1

	return data
