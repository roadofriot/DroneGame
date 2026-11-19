class_name WorldSelectMenu
extends Control

## WorldSelectMenu: UI Screen to inspect and select unlocked worlds from the catalogue.

signal world_selected(world_id: String)
signal real_location_explorer_requested
signal menu_closed

var progression_service: ProgressionService

@onready var grid_container: HBoxContainer = $Card/VBox/ScrollContainer/HBoxWorlds
@onready var btn_close: Button = $Card/VBox/HBoxTop/BtnClose
@onready var btn_explorer: Button = get_node_or_null("Card/VBox/HBoxTop/BtnExplorer")

func _ready() -> void:
	visible = false
	if btn_close:
		btn_close.pressed.connect(func():
			visible = false
			menu_closed.emit()
		)
	if btn_explorer:
		btn_explorer.pressed.connect(func():
			visible = false
			real_location_explorer_requested.emit()
		)
	if not progression_service:
		progression_service = ProgressionService.new()
	populate_cards()

func show_menu() -> void:
	populate_cards()
	visible = true

func populate_cards() -> void:
	if not grid_container:
		return

	for child in grid_container.get_children():
		child.queue_free()

	var player_level = progression_service.get_level() if progression_service else 1
	var worlds = WorldData.get_all_worlds()

	for w in worlds:
		var card = create_world_card(w, player_level)
		grid_container.add_child(card)

func create_world_card(world_def: Dictionary, player_level: int) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 340)

	var wid = world_def.get("id", "")
	var is_stage = wid.begins_with("stage_") or wid == "nepal_adventure"

	var style = StyleBoxFlat.new()
	if is_stage:
		style.bg_color = Color(0.08, 0.13, 0.22, 0.95)
		style.border_color = Color(0.95, 0.72, 0.2, 0.8)
	else:
		style.bg_color = Color(0.1, 0.14, 0.2, 0.9)
		style.border_color = Color(0.25, 0.75, 1, 0.7)

	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.content_margin_left = 16
	style.content_margin_top = 16
	style.content_margin_right = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = world_def.get("name", "World").to_upper()
	if is_stage:
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	else:
		title_lbl.add_theme_color_override("font_color", Color(0.2, 0.85, 1))
	title_lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title_lbl)

	var region_lbl = Label.new()
	region_lbl.text = world_def.get("region", "")
	region_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	region_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(region_lbl)

	var diff_lbl = Label.new()
	diff_lbl.text = "DIFFICULTY: " + world_def.get("difficulty", "Normal").to_upper()
	diff_lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	diff_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(diff_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = world_def.get("description", "")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(desc_lbl)

	var is_unlocked = WorldData.is_world_unlocked(world_def, player_level)
	var action_btn = Button.new()
	action_btn.custom_minimum_size = Vector2(0, 42)

	var btn_style = StyleBoxFlat.new()
	btn_style.set_corner_radius_all(6)

	if is_unlocked:
		action_btn.text = "FLY STAGE" if is_stage else "FLY WORLD"
		if is_stage:
			btn_style.bg_color = Color(0.14, 0.48, 0.32, 0.95)
		else:
			btn_style.bg_color = Color(0.12, 0.45, 0.7, 0.9)
		action_btn.add_theme_stylebox_override("normal", btn_style)
		action_btn.pressed.connect(func():
			visible = false
			world_selected.emit(wid)
		)
	else:
		if is_stage:
			action_btn.text = "LOCKED (Fly Prev Stage)"
		else:
			action_btn.text = "LOCKED (LVL %d)" % world_def.get("required_level", 2)
		action_btn.disabled = true
		btn_style.bg_color = Color(0.2, 0.2, 0.25, 0.6)
		action_btn.add_theme_stylebox_override("disabled", btn_style)

	vbox.add_child(action_btn)
	return panel

func _create_world_card(world_def: Dictionary, player_level: int) -> Control:
	return create_world_card(world_def, player_level)
