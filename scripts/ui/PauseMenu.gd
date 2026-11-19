class_name PauseMenu
extends Control

## PauseMenu: In-flight pause modal with Resume, Restart, and comprehensive
## Settings controls: per-profile expo/deadzone, axis inverts, camera FOV,
## units toggle, trim reset, and key rebinding with conflict detection.

signal resume_requested
signal restart_requested
signal trim_reset_requested

var settings_service: SettingsService

@onready var btn_resume: Button = get_node_or_null("Card/VBox/BtnResume")
@onready var btn_restart: Button = get_node_or_null("Card/VBox/BtnRestart")
@onready var tab_container: TabContainer = get_node_or_null("Card/VBox/TabContainer")

# Settings Controls - General / Tuning
@onready var slider_fov: HSlider = get_node_or_null(
	"Card/VBox/TabContainer/Controls/Scroll/VBox/HBoxFOV/SliderFOV"
)
@onready var label_fov: Label = get_node_or_null(
	"Card/VBox/TabContainer/Controls/Scroll/VBox/HBoxFOV/LabelFOVVal"
)
@onready var btn_units: Button = get_node_or_null(
	"Card/VBox/TabContainer/Controls/Scroll/VBox/BtnUnits"
)
@onready var btn_quality: Button = get_node_or_null(
	"Card/VBox/TabContainer/Controls/Scroll/VBox/BtnQuality"
)
@onready var btn_trim_reset: Button = get_node_or_null(
	"Card/VBox/TabContainer/Controls/Scroll/VBox/BtnTrimReset"
)

# Inverts
@onready var check_inv_pitch: CheckBox = get_node_or_null(
	"Card/VBox/TabContainer/Controls/Scroll/VBox/GridInverts/CheckInvPitch"
)
@onready var check_inv_roll: CheckBox = get_node_or_null(
	"Card/VBox/TabContainer/Controls/Scroll/VBox/GridInverts/CheckInvRoll"
)
@onready var check_inv_yaw: CheckBox = get_node_or_null(
	"Card/VBox/TabContainer/Controls/Scroll/VBox/GridInverts/CheckInvYaw"
)
@onready var check_inv_throttle: CheckBox = get_node_or_null(
	"Card/VBox/TabContainer/Controls/Scroll/VBox/GridInverts/CheckInvThrottle"
)

# Per-Profile Expo & Deadzone Sliders
@onready var slider_expo_cine: HSlider = get_node_or_null(
	"Card/VBox/TabContainer/Tuning/Scroll/VBox/ExpoCine/Slider"
)
@onready var slider_dead_cine: HSlider = get_node_or_null(
	"Card/VBox/TabContainer/Tuning/Scroll/VBox/DeadCine/Slider"
)
@onready var slider_expo_norm: HSlider = get_node_or_null(
	"Card/VBox/TabContainer/Tuning/Scroll/VBox/ExpoNorm/Slider"
)
@onready var slider_dead_norm: HSlider = get_node_or_null(
	"Card/VBox/TabContainer/Tuning/Scroll/VBox/DeadNorm/Slider"
)
@onready var slider_expo_sport: HSlider = get_node_or_null(
	"Card/VBox/TabContainer/Tuning/Scroll/VBox/ExpoSport/Slider"
)
@onready var slider_dead_sport: HSlider = get_node_or_null(
	"Card/VBox/TabContainer/Tuning/Scroll/VBox/DeadSport/Slider"
)
@onready var slider_expo_acro: HSlider = get_node_or_null(
	"Card/VBox/TabContainer/Tuning/Scroll/VBox/ExpoAcro/Slider"
)
@onready var slider_dead_acro: HSlider = get_node_or_null(
	"Card/VBox/TabContainer/Tuning/Scroll/VBox/DeadAcro/Slider"
)

# Rebinding UI
@onready var rebind_container: VBoxContainer = get_node_or_null(
	"Card/VBox/TabContainer/Keybinds/Scroll/RebindList"
)
@onready var label_rebind_status: Label = get_node_or_null(
	"Card/VBox/TabContainer/Keybinds/LabelRebindStatus"
)

var is_rebinding: bool = false
var rebinding_action: String = ""

func _ready() -> void:
	visible = false
	if not settings_service:
		settings_service = SettingsService.new()

	if btn_resume:
		btn_resume.pressed.connect(func(): resume())
	if btn_restart:
		btn_restart.pressed.connect(func(): restart_requested.emit())
	if btn_trim_reset:
		btn_trim_reset.pressed.connect(_on_trim_reset_pressed)
	if btn_units:
		btn_units.pressed.connect(_on_btn_units_pressed)
	if btn_quality:
		var cur_q = settings_service.get_current_preset_key().to_upper()
		btn_quality.text = "Quality: %s" % cur_q
		btn_quality.pressed.connect(_on_btn_quality_pressed)

	_setup_tuning_ui()
	_setup_inverts_ui()
	_setup_fov_ui()
	_populate_rebinding_ui()

func _setup_tuning_ui() -> void:
	if not settings_service:
		return

	if slider_expo_cine:
		slider_expo_cine.value = settings_service.get_profile_expo("cine")
		slider_expo_cine.value_changed.connect(func(v):
			settings_service.set_profile_expo("cine", v)
			settings_service.save_settings()
		)
	if slider_dead_cine:
		slider_dead_cine.value = settings_service.get_profile_deadzone("cine")
		slider_dead_cine.value_changed.connect(func(v):
			settings_service.set_profile_deadzone("cine", v)
			settings_service.save_settings()
		)

	if slider_expo_norm:
		slider_expo_norm.value = settings_service.get_profile_expo("normal")
		slider_expo_norm.value_changed.connect(func(v):
			settings_service.set_profile_expo("normal", v)
			settings_service.save_settings()
		)
	if slider_dead_norm:
		slider_dead_norm.value = settings_service.get_profile_deadzone("normal")
		slider_dead_norm.value_changed.connect(func(v):
			settings_service.set_profile_deadzone("normal", v)
			settings_service.save_settings()
		)

	if slider_expo_sport:
		slider_expo_sport.value = settings_service.get_profile_expo("sport")
		slider_expo_sport.value_changed.connect(func(v):
			settings_service.set_profile_expo("sport", v)
			settings_service.save_settings()
		)
	if slider_dead_sport:
		slider_dead_sport.value = settings_service.get_profile_deadzone("sport")
		slider_dead_sport.value_changed.connect(func(v):
			settings_service.set_profile_deadzone("sport", v)
			settings_service.save_settings()
		)

	if slider_expo_acro:
		slider_expo_acro.value = settings_service.get_profile_expo("acro")
		slider_expo_acro.value_changed.connect(func(v):
			settings_service.set_profile_expo("acro", v)
			settings_service.save_settings()
		)
	if slider_dead_acro:
		slider_dead_acro.value = settings_service.get_profile_deadzone("acro")
		slider_dead_acro.value_changed.connect(func(v):
			settings_service.set_profile_deadzone("acro", v)
			settings_service.save_settings()
		)

func _setup_inverts_ui() -> void:
	if not settings_service:
		return
	if check_inv_pitch:
		check_inv_pitch.button_pressed = settings_service.is_axis_inverted("pitch")
		check_inv_pitch.toggled.connect(func(b):
			settings_service.set_axis_inverted("pitch", b)
			settings_service.save_settings()
		)
	if check_inv_roll:
		check_inv_roll.button_pressed = settings_service.is_axis_inverted("roll")
		check_inv_roll.toggled.connect(func(b):
			settings_service.set_axis_inverted("roll", b)
			settings_service.save_settings()
		)
	if check_inv_yaw:
		check_inv_yaw.button_pressed = settings_service.is_axis_inverted("yaw")
		check_inv_yaw.toggled.connect(func(b):
			settings_service.set_axis_inverted("yaw", b)
			settings_service.save_settings()
		)
	if check_inv_throttle:
		check_inv_throttle.button_pressed = settings_service.is_axis_inverted("throttle")
		check_inv_throttle.toggled.connect(func(b):
			settings_service.set_axis_inverted("throttle", b)
			settings_service.save_settings()
		)

func _setup_fov_ui() -> void:
	if not settings_service:
		return
	if slider_fov:
		slider_fov.value = settings_service.get_camera_fov()
		if label_fov:
			label_fov.text = "%d°" % int(slider_fov.value)
		slider_fov.value_changed.connect(func(v):
			settings_service.set_camera_fov(v)
			if label_fov:
				label_fov.text = "%d°" % int(v)
			settings_service.save_settings()
		)
	if btn_units:
		btn_units.text = "Units: %s" % settings_service.get_units().to_upper()

func _on_btn_units_pressed() -> void:
	if not settings_service:
		return
	var new_u = "imperial" if settings_service.get_units() == "metric" else "metric"
	settings_service.set_units(new_u)
	settings_service.save_settings()
	if btn_units:
		btn_units.text = "Units: %s" % new_u.to_upper()

func _on_btn_quality_pressed() -> void:
	if not settings_service:
		return
	var cur = settings_service.get_current_preset_key().to_lower()
	var next_q = "medium"
	if cur == "low":
		next_q = "medium"
	elif cur == "medium":
		next_q = "high"
	else:
		next_q = "low"
	settings_service.apply_quality_preset(next_q, get_viewport())
	settings_service.save_settings()
	if btn_quality:
		btn_quality.text = "Quality: %s" % next_q.to_upper()

func _on_trim_reset_pressed() -> void:
	if settings_service:
		settings_service.request_trim_reset()
	trim_reset_requested.emit()
	if label_rebind_status:
		label_rebind_status.text = "Trims reset to center (0.0)."

func _populate_rebinding_ui() -> void:
	if not rebind_container or not settings_service:
		return

	for c in rebind_container.get_children():
		c.queue_free()

	for action in SettingsService.REBINDABLE_ACTIONS:
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var lbl = Label.new()
		lbl.text = action.replace("flight_", "").replace("_", " ").capitalize()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(110, 32)
		btn.text = settings_service.get_action_binding_text(action)
		btn.pressed.connect(func(): _start_rebinding(action, btn))
		row.add_child(btn)

		rebind_container.add_child(row)

func _start_rebinding(action_name: String, btn: Button) -> void:
	is_rebinding = true
	rebinding_action = action_name
	btn.text = "[PRESS KEY...]"
	if label_rebind_status:
		label_rebind_status.text = "Press any key to bind '%s' (ESC cancels)..." % action_name

func _unhandled_input(event: InputEvent) -> void:
	if is_rebinding:
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			if event.keycode == KEY_ESCAPE:
				is_rebinding = false
				rebinding_action = ""
				if label_rebind_status:
					label_rebind_status.text = "Rebinding cancelled."
				_populate_rebinding_ui()
				return

			var conflict = settings_service.check_rebinding_conflict(rebinding_action, event)
			if conflict != "":
				if label_rebind_status:
					label_rebind_status.text = "⚠️ Conflict: Already bound to '%s'!" % conflict
				is_rebinding = false
				rebinding_action = ""
				_populate_rebinding_ui()
				return

			var ok = settings_service.rebind_action(rebinding_action, event)
			if ok and label_rebind_status:
				var kc = event.physical_keycode if event.physical_keycode != 0 else event.keycode
				var key_name = OS.get_keycode_string(kc)
				label_rebind_status.text = "✓ Successfully rebound '%s' to %s" % [
					rebinding_action, key_name
				]
			is_rebinding = false
			rebinding_action = ""
			_populate_rebinding_ui()
		return

	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause() -> void:
	if visible:
		resume()
	else:
		pause()

func pause() -> void:
	visible = true
	get_tree().paused = true

func resume() -> void:
	visible = false
	get_tree().paused = false
	resume_requested.emit()
