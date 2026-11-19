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
@onready var real_location_explorer: RealLocationExplorer = get_node_or_null(
	"FlightHUD/RealLocationExplorer"
)
@onready var training_academy: TrainingAcademy = get_node_or_null("TrainingAcademy")
@onready var audio_director: AudioDirector = get_node_or_null("AudioDirector")
@onready var vfx_director: VFXDirector = get_node_or_null("VFXDirector")

@onready var gates_container: Node3D = $EnvironmentGeometry/FlightGates
@onready var coins_container: Node3D = $EnvironmentGeometry/CollectibleCoins

func _ready() -> void:
	# Connect InputRouter Action Signals to Drone and Systems
	if input_router and quadcopter:
		var cam_dir = get_node_or_null("CameraDirector")
		input_router.takeoff_requested.connect(func(): quadcopter.takeoff())
		input_router.land_requested.connect(func(): quadcopter.land())
		input_router.rth_requested.connect(func():
			if quadcopter.current_state == FlightPhysics.DroneState.RTH:
				quadcopter.cancel_rth()
			else:
				quadcopter.trigger_rth()
		)
		input_router.takeoff_land_requested.connect(func():
			if quadcopter.current_state == FlightPhysics.DroneState.DISARMED:
				quadcopter.takeoff()
			elif quadcopter.current_state == FlightPhysics.DroneState.CRASHED:
				quadcopter.reset_to_pad()
			else:
				quadcopter.land()
		)
		input_router.emergency_cut_requested.connect(func(): quadcopter.emergency_motor_cut())
		input_router.reset_requested.connect(func(): quadcopter.reset_to_pad())
		input_router.flight_mode_cycle_requested.connect(func():
			var modes = ["cine", "normal", "sport", "arcade", "acro"]
			var cur_idx = modes.find(quadcopter.active_profile_name)
			var next_idx = (cur_idx + 1) % modes.size()
			quadcopter.set_flight_profile(modes[next_idx])
		)
		input_router.stunt_requested.connect(func(stunt_type):
			if quadcopter.stunt_engine:
				quadcopter.stunt_engine.execute_stunt(stunt_type)
		)
		if quadcopter.stunt_engine:
			quadcopter.stunt_engine.stunt_completed.connect(func(_type, score, _quality):
				Input.vibrate_handheld(75)
				if mission_manager and mission_manager.progression_service:
					mission_manager.progression_service.add_xp(score / 5)
					mission_manager.progression_service.add_coins(score / 10)
			)
		if cam_dir:
			input_router.camera_toggle_requested.connect(func(): cam_dir.cycle_camera_mode())
		if pause_menu:
			input_router.pause_requested.connect(func(): pause_menu.toggle_pause())

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
			var is_coin = child is CollectibleCoin or child.has_signal("coin_collected")
			if is_coin and not child.coin_collected.is_connected(_on_coin_collected):
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
		if real_location_explorer:
			var rle_sig = world_select_menu.real_location_explorer_requested
			if not rle_sig.is_connected(_on_explorer_requested):
				rle_sig.connect(_on_explorer_requested)

	# Initialize Training Academy
	if not training_academy:
		training_academy = TrainingAcademy.new()
		training_academy.name = "TrainingAcademy"
		training_academy.target_drone = quadcopter
		add_child(training_academy)

	if training_academy:
		for gate in gates:
			if not gate.gate_passed.is_connected(training_academy.on_gate_passed):
				gate.gate_passed.connect(training_academy.on_gate_passed)
		if not training_academy.step_updated.is_connected(_on_academy_step_updated):
			training_academy.step_updated.connect(_on_academy_step_updated)
		if not training_academy.lesson_completed.is_connected(_on_academy_lesson_completed):
			training_academy.lesson_completed.connect(_on_academy_lesson_completed)
		if not training_academy.lesson_failed.is_connected(_on_academy_lesson_failed):
			training_academy.lesson_failed.connect(_on_academy_lesson_failed)

	# Initialize Audio and VFX Directors
	if not audio_director:
		audio_director = AudioDirector.new()
		audio_director.name = "AudioDirector"
		audio_director.target_drone = quadcopter
		add_child(audio_director)

	if not vfx_director:
		vfx_director = VFXDirector.new()
		vfx_director.name = "VFXDirector"
		vfx_director.target_drone = quadcopter
		add_child(vfx_director)

	# Connect gate pass audio and particle effects
	for gate in gates:
		gate.gate_passed.connect(func(_idx: int):
			Input.vibrate_handheld(45)
			if audio_director: audio_director.play_gate_passed()
			if vfx_director:
				var g_pos = gate.global_position if gate.is_inside_tree() else gate.position
				var g_basis = (
					gate.global_transform.basis if gate.is_inside_tree()
					else gate.transform.basis
				)
				vfx_director.spawn_gate_pass_vfx(g_pos, g_basis)
		)

	# Connect crash audio and debris particle effects
	if quadcopter and not quadcopter.drone_crashed.is_connected(_on_drone_crashed_feedback):
		quadcopter.drone_crashed.connect(_on_drone_crashed_feedback)

	# Initialize environment wind from active world data
	if quadcopter:
		var cur_scene = scene_file_path
		var worlds = WorldData.get_all_worlds()
		for w in worlds:
			if w.get("scene_path", "") == cur_scene or cur_scene.ends_with("FlightWorld.tscn"):
				var wv = w.get("wind_vector", [0.0, 0.0, 0.0])
				if wv is Array and wv.size() == 3:
					quadcopter.set_world_wind(Vector3(wv[0], wv[1], wv[2]) * 6.0)
				break

	# Apply user quality settings preset
	var settings_svc = SettingsService.new()
	var world_env: WorldEnvironment = get_node_or_null("WorldEnvironment")
	var env = world_env.environment if world_env else null
	settings_svc.apply_quality_preset(settings_svc.get_current_preset_key(), get_viewport(), env)

	# Start default tutorial mission
	if mission_manager:
		mission_manager.start_mission("training_gate_run")

func _on_coin_collected(coin_inst: CollectibleCoin, value: int) -> void:
	Input.vibrate_handheld(30)
	if audio_director:
		audio_director.play_coin_pickup()
	if vfx_director and coin_inst:
		var c_pos = coin_inst.global_position if coin_inst.is_inside_tree() else coin_inst.position
		vfx_director.spawn_coin_pickup_vfx(c_pos)
	if mission_manager:
		mission_manager.record_coin_pickup(value)

func _on_drone_crashed_feedback(impact_force: float) -> void:
	Input.vibrate_handheld(250)
	if audio_director:
		audio_director.play_crash()
	if vfx_director and quadcopter:
		var d_pos = (
			quadcopter.global_position if quadcopter.is_inside_tree()
			else quadcopter.position
		)
		vfx_director.spawn_crash_vfx(d_pos, impact_force)

func _on_mission_started(mission_def: Dictionary) -> void:
	if mission_overlay:
		mission_overlay.set_mission(mission_def.get("title", "Mission"))

func _on_mission_progress_updated(
	obj_text: String, cur_val: int, target_val: int, time_left: float
) -> void:
	if mission_overlay:
		mission_overlay.update_progress(obj_text, cur_val, target_val, time_left)

func _on_mission_completed(results: Dictionary) -> void:
	if audio_director:
		audio_director.play_mission_completed()
	if mission_overlay:
		mission_overlay.hide_overlay()
	if mission_results:
		mission_results.display_results(results)

func _on_mission_failed(reason: String) -> void:
	if flight_hud and flight_hud.label_state_banner:
		flight_hud.label_state_banner.text = "MISSION FAILED: %s — PRESS R TO RETRY" % reason
		flight_hud.label_state_banner.visible = true

func _on_academy_step_updated(
	instruction: String, current_step: int, total_steps: int
) -> void:
	if mission_overlay:
		var step_str = "Step %d/%d: %s" % [current_step, total_steps, instruction]
		mission_overlay.update_progress(step_str, current_step, total_steps, 0.0)

func _on_academy_lesson_completed(
	_lesson_id: String, medal: String, score: int, _rewards: Dictionary
) -> void:
	if flight_hud and flight_hud.label_state_banner:
		var banner_str = "ACADEMY LESSON COMPLETE [%s MEDAL] +%d PTS!" % [medal, score]
		flight_hud.label_state_banner.text = banner_str
		flight_hud.label_state_banner.visible = true

func _on_academy_lesson_failed(_lesson_id: String, reason: String) -> void:
	if flight_hud and flight_hud.label_state_banner:
		flight_hud.label_state_banner.text = "LESSON FAILED: %s — PRESS R TO RETRY" % reason
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

func _on_explorer_requested() -> void:
	if real_location_explorer:
		real_location_explorer.visible = true
