class_name FlightWorld
extends Node3D

## FlightWorld: Orchestrates Flight Physics, Missions, Collectibles, and HUD Overlays.

@onready var quadcopter: FlightPhysics = $Quadcopter
@onready var input_router: InputRouter = $InputRouter
@onready var mission_manager: MissionManager = $MissionManager
@onready var flight_hud: FlightHUD = $FlightHUD
@onready var mission_overlay: MissionOverlay = $FlightHUD/MissionOverlay
@onready var mission_results: MissionResults = $FlightHUD/MissionResults
@onready var pause_menu: PauseMenu = $FlightHUD/PauseMenu
@onready var world_select_menu: WorldSelectMenu = get_node_or_null("FlightHUD/WorldSelectMenu")

@onready var gates_container: Node3D = $EnvironmentGeometry/FlightGates
@onready var coins_container: Node3D = $EnvironmentGeometry/CollectibleCoins

func _ready() -> void:
	# Register sequential gates with MissionManager
	var gates: Array[MissionGate] = []
	if gates_container:
		for child in gates_container.get_children():
			if child is MissionGate or child.has_signal("gate_passed"):
				gates.append(child as MissionGate)
	if mission_manager:
		mission_manager.register_gates(gates)
		mission_manager.target_drone = quadcopter
		if not mission_manager.mission_started.is_connected(_on_mission_started):
			mission_manager.mission_started.connect(_on_mission_started)
		if not mission_manager.mission_progress_updated.is_connected(_on_mission_progress_updated):
			mission_manager.mission_progress_updated.connect(_on_mission_progress_updated)
		if not mission_manager.mission_completed.is_connected(_on_mission_completed):
			mission_manager.mission_completed.connect(_on_mission_completed)
		if not mission_manager.mission_failed.is_connected(_on_mission_failed):
			mission_manager.mission_failed.connect(_on_mission_failed)

	# Register collectible coins
	if coins_container:
		for child in coins_container.get_children():
			if (child is CollectibleCoin or child.has_signal("coin_collected")) and not child.coin_collected.is_connected(_on_coin_collected):
				child.coin_collected.connect(_on_coin_collected)

	# Connect Pause & Results Modals
	if mission_results:
		if not mission_results.retry_pressed.is_connected(_on_results_retry):
			mission_results.retry_pressed.connect(_on_results_retry)
		if not mission_results.continue_pressed.is_connected(_on_results_continue):
			mission_results.continue_pressed.connect(_on_results_continue)

	if pause_menu:
		if not pause_menu.restart_requested.is_connected(_on_pause_restart):
			pause_menu.restart_requested.connect(_on_pause_restart)

	# Connect World Selection Menu
	if flight_hud and world_select_menu:
		if not flight_hud.world_select_requested.is_connected(world_select_menu.show_menu):
			flight_hud.world_select_requested.connect(world_select_menu.show_menu)
		if not world_select_menu.world_selected.is_connected(_on_world_selected):
			world_select_menu.world_selected.connect(_on_world_selected)

	# Start default tutorial mission
	if mission_manager:
		mission_manager.start_mission("training_gate_run")

func _on_coin_collected(coin_inst: CollectibleCoin, value: int) -> void:
	if mission_manager:
		mission_manager.record_coin_pickup(value)

func _on_mission_started(mission_def: Dictionary) -> void:
	if mission_overlay:
		mission_overlay.set_mission(mission_def.get("title", "Mission"))

func _on_mission_progress_updated(obj_text: String, cur_val: int, target_val: int, time_left: float) -> void:
	if mission_overlay:
		mission_overlay.update_progress(obj_text, cur_val, target_val, time_left)

func _on_mission_completed(results: Dictionary) -> void:
	if mission_overlay:
		mission_overlay.hide_overlay()
	if mission_results:
		mission_results.display_results(results)

func _on_mission_failed(reason: String) -> void:
	if flight_hud and flight_hud.label_state_banner:
		flight_hud.label_state_banner.text = "MISSION FAILED: %s — PRESS R TO RETRY" % reason
		flight_hud.label_state_banner.visible = true

func _on_results_retry() -> void:
	if mission_results:
		mission_results.hide_modal()
	if quadcopter:
		quadcopter.reset_to_pad()
	if mission_manager:
		mission_manager.start_mission(mission_manager.active_mission_id)

func _on_results_continue() -> void:
	if mission_results:
		mission_results.hide_modal()
	# Progress to next mission or free flight
	if mission_manager:
		if mission_manager.active_mission_id == "training_gate_run":
			mission_manager.start_mission("training_coin_hunt")
		elif mission_manager.active_mission_id == "training_coin_hunt":
			mission_manager.start_mission("training_precision_landing")

func _on_pause_restart() -> void:
	if pause_menu:
		pause_menu.resume()
	if quadcopter:
		quadcopter.reset_to_pad()
	if mission_manager and not mission_manager.active_mission_id.is_empty():
		mission_manager.start_mission(mission_manager.active_mission_id)

func _on_world_selected(world_id: String) -> void:
	var def = WorldData.get_world_by_id(world_id)
	if not def.is_empty() and def.has("scene_path"):
		var target_scene = def["scene_path"]
		if ResourceLoader.exists(target_scene):
			get_tree().change_scene_to_file(target_scene)
