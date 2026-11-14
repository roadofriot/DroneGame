class_name ProgressionService
extends RefCounted

## ProgressionService: Player XP, Level Progression, Coins Economy, and Idempotent Reward Distribution.

signal level_up(new_level: int)
signal coins_changed(new_balance: int, delta: int)
signal xp_earned(amount: int, current_xp: int, next_level_xp: int)
signal drone_unlocked(drone_id: String)

var profile: Dictionary = {}
var mission_records: Dictionary = {}
var claimed_run_hashes: Array = []
var settings: Dictionary = {}

func _init() -> void:
	load_data()

func load_data() -> void:
	var save_data = SaveService.load_game()
	profile = save_data.get("player_profile", SaveService.get_default_save_data()["player_profile"])
	mission_records = save_data.get("mission_records", {})
	claimed_run_hashes = save_data.get("claimed_run_hashes", [])
	settings = save_data.get("settings", {})

func save_data() -> bool:
	var full_payload = {
		"schema_version": SaveService.CURRENT_SCHEMA_VERSION,
		"player_profile": profile,
		"mission_records": mission_records,
		"claimed_run_hashes": claimed_run_hashes,
		"settings": settings
	}
	return SaveService.save_game(full_payload)

func get_coins() -> int:
	return profile.get("coins_banked", 0)

func get_level() -> int:
	return profile.get("level", 1)

func get_current_xp() -> int:
	return profile.get("current_xp", 0)

func get_xp_for_next_level(lvl: int) -> int:
	# Formula: Level 1 -> 150 XP, Level 2 -> 350 XP, Level 3 -> 600 XP ...
	return int(round(150.0 * pow(float(lvl), 1.35)))

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	var cur_xp = profile.get("current_xp", 0) + amount
	var cur_lvl = profile.get("level", 1)
	var needed_xp = get_xp_for_next_level(cur_lvl)

	while cur_xp >= needed_xp:
		cur_xp -= needed_xp
		cur_lvl += 1
		profile["level"] = cur_lvl
		level_up.emit(cur_lvl)
		needed_xp = get_xp_for_next_level(cur_lvl)

	profile["current_xp"] = cur_xp
	xp_earned.emit(amount, cur_xp, needed_xp)
	save_data()

func add_coins(amount: int) -> void:
	if amount == 0:
		return
	var current = profile.get("coins_banked", 0)
	var new_bal = max(0, current + amount)
	profile["coins_banked"] = new_bal
	coins_changed.emit(new_bal, amount)
	save_data()

func spend_coins(amount: int) -> bool:
	if amount <= 0:
		return true
	var cur = get_coins()
	if cur < amount:
		return false
	add_coins(-amount)
	return true

func is_run_already_claimed(run_hash: String) -> bool:
	return claimed_run_hashes.has(run_hash)

func process_mission_completion(mission_id: String, mission_def: Dictionary, completion_time: float, medal: String, attempt_token: String) -> Dictionary:
	# Build unique deterministic run hash to guarantee idempotency
	var run_hash = "%s_%s_%d_%s" % [mission_id, medal, int(completion_time * 100), attempt_token]

	if is_run_already_claimed(run_hash):
		print("ProgressionService: Run hash %s already processed. Skipping duplicate rewards." % run_hash)
		return {
			"already_claimed": true,
			"coins_awarded": 0,
			"xp_awarded": 0,
			"medal": medal,
			"is_first_clear": false
		}

	var is_first_clear: bool = false
	var existing_rec: Dictionary = mission_records.get(mission_id, {})

	if existing_rec.is_empty() or not existing_rec.get("completed", false):
		is_first_clear = true

	# Calculate reward
	var coins_to_give: int = 0
	var xp_to_give: int = 0

	if is_first_clear:
		var first_rewards = mission_def.get("first_clear_rewards", {"coins": 200, "xp": 400})
		coins_to_give = first_rewards.get("coins", 200)
		xp_to_give = first_rewards.get("xp", 400)
	else:
		var replay_rewards = mission_def.get("replay_rewards", {"coins": 25, "xp": 50})
		coins_to_give = replay_rewards.get("coins", 25)
		xp_to_give = replay_rewards.get("xp", 50)

	# Medal bonus
	match medal:
		"gold":
			coins_to_give += 100
			xp_to_give += 200
		"silver":
			coins_to_give += 50
			xp_to_give += 100
		"bronze":
			coins_to_give += 20
			xp_to_give += 50

	# Mark run as claimed
	claimed_run_hashes.append(run_hash)

	# Update mission records
	var best_time = completion_time
	if not existing_rec.is_empty():
		best_time = minf(completion_time, existing_rec.get("best_time_sec", completion_time))

	var best_medal = _best_medal(existing_rec.get("best_medal", "none"), medal)
	var play_count = existing_rec.get("play_count", 0) + 1

	mission_records[mission_id] = {
		"completed": true,
		"best_time_sec": best_time,
		"best_medal": best_medal,
		"cleared_at_timestamp": Time.get_unix_time_from_system(),
		"play_count": play_count
	}

	# Distribute resources and persist
	add_coins(coins_to_give)
	add_xp(xp_to_give)
	save_data()

	return {
		"already_claimed": false,
		"coins_awarded": coins_to_give,
		"xp_awarded": xp_to_give,
		"medal": medal,
		"is_first_clear": is_first_clear
	}

func _best_medal(m1: String, m2: String) -> String:
	var ranks = {"none": 0, "bronze": 1, "silver": 2, "gold": 3}
	var r1 = ranks.get(m1, 0)
	var r2 = ranks.get(m2, 0)
	return m2 if r2 >= r1 else m1
