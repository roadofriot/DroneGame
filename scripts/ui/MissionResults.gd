class_name MissionResults
extends Control

## MissionResults: Post-mission modal showcasing medal grade, time, rewards, and retry/continue.

signal retry_pressed
signal continue_pressed

@onready var label_title: Label = $Card/VBox/LabelTitle
@onready var label_medal: Label = $Card/VBox/MedalPill/LabelMedal
@onready var label_time: Label = $Card/VBox/HBoxStats/TimeVBox/LabelTime
@onready var label_coins: Label = $Card/VBox/HBoxStats/CoinsVBox/LabelCoins
@onready var label_xp: Label = $Card/VBox/HBoxStats/XpVBox/LabelXp
@onready var btn_retry: Button = $Card/VBox/HBoxButtons/BtnRetry
@onready var btn_continue: Button = $Card/VBox/HBoxButtons/BtnContinue

func _ready() -> void:
	visible = false
	if btn_retry:
		btn_retry.pressed.connect(func(): retry_pressed.emit())
	if btn_continue:
		btn_continue.pressed.connect(func(): continue_pressed.emit())

func display_results(results: Dictionary) -> void:
	visible = true

	if label_title:
		label_title.text = results.get("title", "MISSION COMPLETE").to_upper()

	var medal = results.get("medal", "none").to_upper()
	if label_medal:
		label_medal.text = "MEDAL: %s" % medal
		match medal:
			"GOLD":
				label_medal.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
			"SILVER":
				label_medal.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
			"BRONZE":
				label_medal.add_theme_color_override("font_color", Color(0.8, 0.5, 0.25))
			_:
				label_medal.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

	var elapsed = results.get("time_elapsed_sec", 0.0)
	if label_time:
		var mins = int(elapsed) / 60
		var secs = int(elapsed) % 60
		var tenths = int((elapsed - floor(elapsed)) * 10.0)
		label_time.text = "%02d:%02d.%d" % [mins, secs, tenths]

	if label_coins:
		label_coins.text = "+%d" % results.get("coins_earned", 0)

	if label_xp:
		label_xp.text = "+%d" % results.get("xp_earned", 0)

func hide_modal() -> void:
	visible = false
