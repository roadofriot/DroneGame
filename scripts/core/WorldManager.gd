class_name WorldManager
extends Node

## WorldManager: Handles world catalogue queries, loading, and active world transitions.

signal world_loaded(world_id: String, world_instance: Node3D)
signal world_unloaded(world_id: String)

var active_world_id: String = ""
var active_world_instance: Node3D = null

func get_catalogue() -> Array[Dictionary]:
	return WorldData.get_all_worlds()

func load_world_scene(world_id: String, parent_container: Node) -> Node3D:
	var def = WorldData.get_world_by_id(world_id)
	if def.is_empty():
		printerr("WorldManager: World ID not found: ", world_id)
		return null

	var scene_path = def.get("scene_path", "")
	if not ResourceLoader.exists(scene_path):
		printerr("WorldManager: Scene file not found: ", scene_path)
		return null

	if active_world_instance:
		unload_active_world()

	var packed_scene = load(scene_path) as PackedScene
	if not packed_scene:
		printerr("WorldManager: Failed to load packed scene: ", scene_path)
		return null

	var instance = packed_scene.instantiate() as Node3D
	parent_container.add_child(instance)

	active_world_id = world_id
	active_world_instance = instance
	world_loaded.emit(world_id, instance)
	return instance

func unload_active_world() -> void:
	if active_world_instance:
		var old_id = active_world_id
		active_world_instance.queue_free()
		active_world_instance = null
		active_world_id = ""
		world_unloaded.emit(old_id)
