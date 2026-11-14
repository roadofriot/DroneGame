class_name MissionOverlay
extends Control

## MissionOverlay: In-game HUD element displaying active objective, step progress, and mission countdown.

@onready var container_panel: PanelContainer = $PanelContainer
@onready var label_title: Label = $PanelContainer/VBox/LabelTitle
@onready var label_objective: Label = $PanelContainer/VBox/LabelObjective
@onready var label_progress: Label = $PanelContainer/VBox/HBox/LabelProgress
@onready var label_timer: Label = $PanelContainer/VBox/HBox/LabelTimer

func _ready() -> void:
	visible = false

func set_mission(title: String) -> void:
	if label_title:
		label_title.text = title.to_upper()
	visible = true

func update_progress(objective_text: String, current_val: int, target_val: int, time_left: float) -> void:
	if label_objective:
		label_objective.text = objective_text

	if label_progress:
		if target_val > 0:
			label_progress.text = "PROGRESS: %d / %d" % [current_val, target_val]
		else:
			label_progress.text = ""

	if label_timer:
		var mins = int(time_left) / 60
		var secs = int(time_left) % 60
		var tenths = int((time_left - floor(time_left)) * 10.0)
		label_timer.text = "%02d:%02d.%d" % [mins, secs, tenths]
		if time_left < 10.0:
			label_timer.add_theme_color_override("font_color", Color(1, 0.25, 0.25))
		else:
			label_timer.add_theme_color_override("font_color", Color(1, 0.85, 0.2))

func hide_overlay() -> void:
	visible = false
