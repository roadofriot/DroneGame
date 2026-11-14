class_name MissionManager
extends Node

## MissionManager: Mission lifecycle state machine, objectives, and scoring.

signal mission_started(mission_def: Dictionary)
signal mission_progress_updated(objective_text: String, current_val: int, target_val: int, time_left_sec: float)
signal mission_completed(results: Dictionary)
signal mission_failed(reason: String)

enum MissionState { INACTIVE, ACTIVE, COMPLETED, FAILED }

@export var target_drone: FlightPhysics

var progression_service: ProgressionService

var all_missions: Dictionary = {}
var active_mission_id: String = ""
var active_mission_def: Dictionary = {}
var current_state: MissionState = MissionState.INACTIVE

# Active Mission Tracking
var time_elapsed_sec: float = 0.0
var time_limit_sec: float = 60.0
var current_gate_index: int = 0
var total_gates: int = 0
var coins_collected: int = 0
var total_coins_target: int = 0
var gates_list: Array[MissionGate] = []
var attempt_token: String = ""

func _init() -> void:
	_load_mission_definitions()
	if not progression_service:
		progression_service = ProgressionService.new()

func _ready() -> void:
	if all_missions.is_empty():
		_load_mission_definitions()

func _load_mission_definitions() -> void:
	# Built-in baseline for missions
	all_missions = {
		"training_gate_run": {
			"id": "training_gate_run",
			"title": "Flight Gate Trial",
			"description": "Fly through all 4 test course gates in sequential order before time expires.",
			"type": "ring_race",
			"world": "training_valley",
			"time_limit_sec": 60.0,
			"medals": {
				"gold_time_sec": 22.0,
				"silver_time_sec": 35.0,
				"bronze_time_sec": 50.0
			},
			"first_clear_rewards": {
				"coins": 250,
				"xp": 500
			},
			"replay_rewards": {
				"coins": 25,
				"xp": 50
			},
			"objectives": [
				{ "type": "pass_gates", "target_count": 4 }
			]
		},
		"training_coin_hunt": {
			"id": "training_coin_hunt",
			"title": "Launch Pad Coin Hunt",
			"description": "Collect all 6 floating coins scattered along the flight perimeter.",
			"type": "coin_hunt",
			"world": "training_valley",
			"time_limit_sec": 75.0,
			"medals": {
				"gold_time_sec": 28.0,
				"silver_time_sec": 45.0,
				"bronze_time_sec": 65.0
			},
			"first_clear_rewards": {
				"coins": 300,
				"xp": 600
			},
			"replay_rewards": {
				"coins": 30,
				"xp": 60
			},
			"objectives": [
				{ "type": "collect_coins", "target_count": 6 }
			]
		},
		"training_precision_landing": {
			"id": "training_precision_landing",
			"title": "Precision Touchdown",
			"description": "Take off, fly around the perimeter pylon, and land smoothly inside the helipad target.",
			"type": "precision_landing",
			"world": "training_valley",
			"time_limit_sec": 45.0,
			"medals": {
				"gold_time_sec": 18.0,
				"silver_time_sec": 28.0,
				"bronze_time_sec": 40.0
			},
			"first_clear_rewards": {
				"coins": 200,
				"xp": 450
			},
			"replay_rewards": {
				"coins": 20,
				"xp": 40
			},
			"objectives": [
				{ "type": "reach_altitude", "min_altitude_m": 4.0 },
				{ "type": "precision_land", "max_touchdown_speed": 1.2, "max_pad_offset_m": 1.8 }
			]
		}
	}

	var path = "res://data/missions/missions.json"
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			var list = json.data.get("missions", [])
			for m in list:
				all_missions[m["id"]] = m

func register_gates(gates: Array[MissionGate]) -> void:
	gates_list = gates
	total_gates = gates.size()
	for i in range(gates.size()):
		gates[i].gate_index = i
		if not gates[i].gate_passed.is_connected(_on_gate_passed):
			gates[i].gate_passed.connect(_on_gate_passed)

func start_mission(mission_id: String) -> bool:
	if not all_missions.has(mission_id):
		printerr("MissionManager: Unknown mission ID: ", mission_id)
		return false

	active_mission_id = mission_id
	active_mission_def = all_missions[mission_id]
	current_state = MissionState.ACTIVE
	time_elapsed_sec = 0.0
	time_limit_sec = active_mission_def.get("time_limit_sec", 60.0)
	coins_collected = 0
	current_gate_index = 0
	attempt_token = str(Time.get_ticks_msec())

	# Initialize gates if mission is a ring race
	if active_mission_def.get("type") == "ring_race":
		total_gates = gates_list.size()
		for i in range(gates_list.size()):
			if i == 0:
				gates_list[i].set_state(MissionGate.GateState.ACTIVE)
			else:
				gates_list[i].set_state(MissionGate.GateState.INACTIVE)

	# Initialize target coin count
	for obj in active_mission_def.get("objectives", []):
		if obj.get("type") == "collect_coins":
			total_coins_target = obj.get("target_count", 6)

	mission_started.emit(active_mission_def)
	_emit_progress()
	return true

func _process(delta: float) -> void:
	if current_state != MissionState.ACTIVE:
		return

	time_elapsed_sec += delta
	var time_left = maxf(0.0, time_limit_sec - time_elapsed_sec)

	if time_left <= 0.0:
		fail_mission("TIME EXPIRED")
		return

	_emit_progress()

func _emit_progress() -> void:
	var obj_type = active_mission_def.get("type", "")
	var obj_text = "Mission in progress"
	var cur_val = 0
	var target_val = 0
	var time_left = maxf(0.0, time_limit_sec - time_elapsed_sec)

	match obj_type:
		"ring_race":
			obj_text = "Pass Gates in Sequence"
			cur_val = current_gate_index
			target_val = total_gates
		"coin_hunt":
			obj_text = "Collect Floating Coins"
			cur_val = coins_collected
			target_val = total_coins_target
		"precision_landing":
			obj_text = "Touchdown on Helipad"
			cur_val = 1 if (target_drone and target_drone.altitude_agl < 0.2) else 0
			target_val = 1

	mission_progress_updated.emit(obj_text, cur_val, target_val, time_left)

func _on_gate_passed(passed_index: int) -> void:
	if current_state != MissionState.ACTIVE:
		return
	if passed_index == current_gate_index:
		current_gate_index += 1
		# Activate next gate
		if current_gate_index < gates_list.size():
			gates_list[current_gate_index].set_state(MissionGate.GateState.ACTIVE)
		else:
			# All gates cleared!
			complete_mission()

func record_coin_pickup(value: int) -> void:
	if current_state != MissionState.ACTIVE:
		# Still award coin to bank even in free flight
		if progression_service:
			progression_service.add_coins(value)
		return

	coins_collected += 1
	if progression_service:
		progression_service.add_coins(value)

	if active_mission_def.get("type") == "coin_hunt":
		if coins_collected >= total_coins_target:
			complete_mission()

func check_precision_landing() -> void:
	if current_state != MissionState.ACTIVE or active_mission_def.get("type") != "precision_landing":
		return
	if not target_drone:
		return

	var spd = target_drone.linear_velocity.length()
	var offset = target_drone.global_position.distance_to(target_drone.spawn_transform.origin)

	if spd < 1.4 and offset < 2.2:
		complete_mission()
	else:
		fail_mission("ROUGH OR OFF-CENTER LANDING")

func complete_mission() -> void:
	current_state = MissionState.COMPLETED

	var medal = _calculate_medal(time_elapsed_sec)
	var reward_result = {}

	if progression_service:
		reward_result = progression_service.process_mission_completion(
			active_mission_id,
			active_mission_def,
			time_elapsed_sec,
			medal,
			attempt_token
		)

	var results_summary = {
		"mission_id": active_mission_id,
		"title": active_mission_def.get("title", "Mission"),
		"time_elapsed_sec": time_elapsed_sec,
		"medal": medal,
		"coins_earned": reward_result.get("coins_awarded", 0),
		"xp_earned": reward_result.get("xp_awarded", 0),
		"is_first_clear": reward_result.get("is_first_clear", false),
		"already_claimed": reward_result.get("already_claimed", false)
	}

	mission_completed.emit(results_summary)

func fail_mission(reason: String) -> void:
	current_state = MissionState.FAILED
	mission_failed.emit(reason)

func _calculate_medal(elapsed_time: float) -> String:
	var medals = active_mission_def.get("medals", {})
	if medals.is_empty():
		return "bronze"

	var gold = medals.get("gold_time_sec", 30.0)
	var silver = medals.get("silver_time_sec", 45.0)
	var bronze = medals.get("bronze_time_sec", 60.0)

	if elapsed_time <= gold:
		return "gold"
	elif elapsed_time <= silver:
		return "silver"
	elif elapsed_time <= bronze:
		return "bronze"
	else:
		return "none"
