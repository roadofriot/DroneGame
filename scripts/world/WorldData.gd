class_name WorldData
extends RefCounted

## WorldData: Data provider and helper for World Catalogue definitions.

static func get_all_worlds() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var path = "res://data/worlds/worlds.json"
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			var arr = json.data.get("worlds", [])
			for w in arr:
				list.append(w)
	return list

static func get_world_by_id(world_id: String) -> Dictionary:
	var all = get_all_worlds()
	for w in all:
		if w.get("id") == world_id:
			return w
	return {}

static func is_world_unlocked(world_def: Dictionary, player_level: int) -> bool:
	var wid = world_def.get("id", "")
	if SaveService.is_stage_unlocked(wid):
		return true
	if world_def.get("unlocked_by_default", false):
		return true
	var req_lvl = world_def.get("required_level", 1)
	return player_level >= req_lvl
