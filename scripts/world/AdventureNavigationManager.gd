class_name AdventureNavigationManager
extends Node

## AdventureNavigationManager: Open-world navigation, checkpoint routing,
## real-time distance tracking, landmark discovery, and destination landing.

signal navigation_telemetry_updated(telemetry: Dictionary)
signal checkpoint_passed(index: int, total: int, reward_coins: int)
signal landmark_discovered(landmark_def: Dictionary)
signal destination_approached(stage_def: Dictionary)
signal destination_reached(stage_def: Dictionary, results: Dictionary)

const NepalRegions = preload("res://scripts/world/NepalWorldRegions.gd")
const CollectibleCoinScene = preload("res://scenes/collectibles/CollectibleCoin.tscn")
const MissionGateScene = preload("res://scenes/missions/MissionGate.tscn")

@export var target_drone: Node3D

var progression_service: ProgressionService
var active_stage_id: String = "stage_01_butwal"
var target_stage_id: String = "stage_02_lumbini"

# Distance and Telemetry Tracking
var previous_drone_pos: Vector3 = Vector3.ZERO
var total_distance_travelled_meters: float = 0.0
var flight_time_seconds: float = 0.0
var max_altitude_reached: float = 0.0
var max_speed_kmh: float = 0.0

# Checkpoints and Coins
var active_checkpoints: Array[Vector3] = []
var current_checkpoint_index: int = 0
var checkpoint_nodes: Array[Node3D] = []
var coin_container: Node3D = null
var coins_collected_count: int = 0

# Status flags
var has_reached_destination: bool = false
var destination_notified: bool = false

func _ready() -> void:
	if not progression_service:
		progression_service = ProgressionService.new()

	coin_container = Node3D.new()
	coin_container.name = "AdventureCoins"
	add_child(coin_container)

	setup_active_journey(active_stage_id, target_stage_id)

func setup_active_journey(from_id: String, to_id: String) -> void:
	active_stage_id = from_id
	target_stage_id = to_id
	has_reached_destination = false
	destination_notified = false
	current_checkpoint_index = 0

	var from_stage = NepalRegions.get_stage_by_id(from_id)
	var to_stage = NepalRegions.get_stage_by_id(to_id)

	# Clean up previous checkpoints and coins
	for cn in checkpoint_nodes:
		if is_instance_valid(cn):
			cn.queue_free()
	checkpoint_nodes.clear()

	if not coin_container:
		coin_container = Node3D.new()
		coin_container.name = "AdventureCoins"
		add_child(coin_container)
	else:
		for c in coin_container.get_children():
			c.queue_free()

	active_checkpoints.clear()
	for cp in from_stage.get("checkpoints", []):
		active_checkpoints.append(cp)

	_spawn_checkpoint_gates()
	_spawn_journey_coin_trails(from_stage, to_stage)

func _setup_active_journey(from_id: String, to_id: String) -> void:
	setup_active_journey(from_id, to_id)

func _spawn_checkpoint_gates() -> void:
	for i in range(active_checkpoints.size()):
		var cp_pos = active_checkpoints[i]
		var gate = MissionGateScene.instantiate() as MissionGate
		gate.name = "CheckpointGate_%d" % i
		gate.position = cp_pos
		gate.gate_index = i
		var cur_i = i
		gate.gate_passed.connect(func(_idx): _on_checkpoint_gate_passed(cur_i))
		add_child(gate)
		checkpoint_nodes.append(gate)
		if i == 0:
			gate.set_state(MissionGate.GateState.ACTIVE)
		else:
			gate.set_state(MissionGate.GateState.INACTIVE)

func _spawn_journey_coin_trails(from_stage: Dictionary, to_stage: Dictionary) -> void:
	var p0: Vector3 = from_stage.get("target_coordinates", Vector3.ZERO)
	var p1: Vector3 = to_stage.get("target_coordinates", Vector3(500, 6, 3000))
	var cps = active_checkpoints

	# 1. Straight trails between waypoints
	var waypoints: Array[Vector3] = [p0]
	for cp in cps:
		waypoints.append(cp)
	waypoints.append(p1)

	for w in range(waypoints.size() - 1):
		var start_pt = waypoints[w]
		var end_pt = waypoints[w + 1]
		var segment_len = start_pt.distance_to(end_pt)
		var num_coins = clamp(int(segment_len / 120.0), 3, 10)

		for k in range(1, num_coins):
			var frac = float(k) / float(num_coins)
			var coin_pos = start_pt.lerp(end_pt, frac)
			# Add subtle parabolic vertical curve
			coin_pos.y += sin(frac * PI) * 12.0
			_spawn_single_coin(coin_pos, 15)

	# 2. Circular formation around destination landmark
	for rad_idx in range(6):
		var angle = (float(rad_idx) / 6.0) * TAU
		var ring_offset = Vector3(cos(angle) * 35.0, 8.0, sin(angle) * 35.0)
		_spawn_single_coin(p1 + ring_offset, 25)

func _spawn_single_coin(pos: Vector3, val: int) -> void:
	var coin = CollectibleCoinScene.instantiate() as CollectibleCoin
	coin.position = pos
	coin.coin_value = val
	coin.coin_collected.connect(func(_coin_inst, value):
		coins_collected_count += 1
		Input.vibrate_handheld(30)
		if progression_service:
			progression_service.add_coins(value)
	)
	coin_container.add_child(coin)

func _physics_process(delta: float) -> void:
	update_navigation_step(delta)

func update_navigation_step(delta: float) -> void:
	if not target_drone or not is_instance_valid(target_drone):
		return

	var is_ready = target_drone.is_inside_tree() and target_drone.is_node_ready()
	var cur_pos = target_drone.global_position if is_ready else target_drone.position

	# 1. Distance & Velocity telemetry
	if previous_drone_pos != Vector3.ZERO and cur_pos.is_finite():
		var step_dist = previous_drone_pos.distance_to(cur_pos)
		if step_dist > 0.001 and step_dist < 2500.0:
			total_distance_travelled_meters += step_dist
			SaveService.record_distance_km(step_dist / 1000.0)

	previous_drone_pos = cur_pos
	flight_time_seconds += delta

	var spd_ms = 0.0
	if target_drone is FlightPhysics and target_drone.linear_velocity.is_finite():
		spd_ms = target_drone.linear_velocity.length()
	var spd_kmh = spd_ms * 3.6
	max_speed_kmh = maxf(max_speed_kmh, spd_kmh)

	var alt = target_drone.altitude_agl if target_drone is FlightPhysics else 0.0
	max_altitude_reached = maxf(max_altitude_reached, alt)

	# 2. Destination calculation
	var to_stage = NepalRegions.get_stage_by_id(target_stage_id)
	var dest_coords: Vector3 = to_stage.get("target_coordinates", Vector3.ZERO)
	var dist_remaining = cur_pos.distance_to(dest_coords)

	# Emit telemetry packet for HUD
	var telemetry = {
		"destination_name": to_stage.get("name", "Destination"),
		"distance_travelled_m": total_distance_travelled_meters,
		"distance_remaining_m": dist_remaining,
		"speed_kmh": spd_kmh,
		"altitude_m": alt,
		"flight_time_sec": flight_time_seconds,
		"next_checkpoint": current_checkpoint_index + 1,
		"total_checkpoints": active_checkpoints.size(),
		"coins_collected": coins_collected_count
	}
	navigation_telemetry_updated.emit(telemetry)

	# 3. Check landmark proximity discovery
	check_landmark_discoveries(cur_pos)

	# 4. Check destination arrival and landing
	check_destination_arrival(cur_pos, to_stage, dist_remaining, spd_ms)

func check_landmark_discoveries(cur_pos: Vector3) -> void:
	var stages = NepalRegions.get_all_stages()
	for st in stages:
		for lm in st.get("landmarks", []):
			var lm_pos: Vector3 = lm.get("position", Vector3.ZERO)
			var radius: float = lm.get("discovery_radius", 35.0)
			if cur_pos.distance_to(lm_pos) <= radius:
				var lm_id: String = lm.get("id", "")
				if not SaveService.is_landmark_discovered(lm_id):
					SaveService.discover_landmark(lm_id)
					var xp = lm.get("xp_reward", 150)
					var coins = lm.get("coin_reward", 200)
					if progression_service:
						progression_service.add_xp(xp)
						progression_service.add_coins(coins)
					Input.vibrate_handheld(60)
					landmark_discovered.emit(lm)

func _check_landmark_discoveries(cur_pos: Vector3) -> void:
	check_landmark_discoveries(cur_pos)

func check_destination_arrival(
	_cur_pos: Vector3, to_stage: Dictionary, dist_to_dest: float, spd_ms: float
) -> void:
	var arrival_rad = to_stage.get("arrival_radius", 50.0)

	if dist_to_dest <= arrival_rad and not destination_notified:
		destination_notified = true
		destination_approached.emit(to_stage)

	if dist_to_dest <= arrival_rad and not has_reached_destination:
		var alt = target_drone.altitude_agl if target_drone is FlightPhysics else 0.0
		var climb = (
			absf(target_drone.climb_rate)
			if target_drone is FlightPhysics
			else 0.0
		)
		# Smooth landing touchdown confirmation
		if alt <= 0.35 and spd_ms <= 1.4 and climb <= 0.6:
			has_reached_destination = true
			Input.vibrate_handheld(150)

			# Permanently unlock next stage in progression
			var next_st = NepalRegions.get_next_stage(target_stage_id)
			if not next_st.is_empty():
				SaveService.unlock_stage(next_st.get("id"))

			var results = {
				"completed_stage": to_stage.get("name"),
				"unlocked_next": next_st.get("name", "World Conquered"),
				"travel_distance_km": total_distance_travelled_meters / 1000.0,
				"flight_time_sec": flight_time_seconds,
				"coins_collected": coins_collected_count,
				"max_speed_kmh": max_speed_kmh,
				"max_altitude_m": max_altitude_reached
			}

			if progression_service:
				progression_service.add_coins(350)
				progression_service.add_xp(500)

			destination_reached.emit(to_stage, results)

func _check_destination_arrival(
	_cur_pos: Vector3, to_stage: Dictionary, dist_to_dest: float, spd_ms: float
) -> void:
	check_destination_arrival(_cur_pos, to_stage, dist_to_dest, spd_ms)

func pass_checkpoint_gate(passed_idx: int) -> void:
	if passed_idx == current_checkpoint_index:
		current_checkpoint_index += 1
		Input.vibrate_handheld(45)
		if progression_service:
			progression_service.add_coins(50)
		checkpoint_passed.emit(current_checkpoint_index, active_checkpoints.size(), 50)

		# Activate next gate
		if current_checkpoint_index < checkpoint_nodes.size():
			var next_gate = checkpoint_nodes[current_checkpoint_index] as MissionGate
			if is_instance_valid(next_gate):
				next_gate.set_state(MissionGate.GateState.ACTIVE)

func _on_checkpoint_gate_passed(passed_idx: int) -> void:
	pass_checkpoint_gate(passed_idx)
