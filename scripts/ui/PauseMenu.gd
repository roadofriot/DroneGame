class_name PauseMenu
extends Control

## PauseMenu: In-flight pause modal with Resume, Restart, and Controls overlay.

signal resume_requested
signal restart_requested

@onready var btn_resume: Button = $Card/VBox/BtnResume
@onready var btn_restart: Button = $Card/VBox/BtnRestart

func _ready() -> void:
	visible = false
	if btn_resume:
		btn_resume.pressed.connect(func(): resume_requested.emit())
	if btn_restart:
		btn_restart.pressed.connect(func(): restart_requested.emit())

func _unhandled_input(event: InputEvent) -> void:
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
