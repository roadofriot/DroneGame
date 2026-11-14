class_name MissionGate
extends Area3D

## MissionGate: 3D Flight Gate with sequential trigger and visual feedback states.

signal gate_passed(gate_index: int)

enum GateState { INACTIVE, ACTIVE, PASSED }

@export var gate_index: int = 0
@export var auto_activate: bool = false

@onready var mesh_instance: MeshInstance3D = $RingMesh

var current_state: GateState = GateState.INACTIVE

var mat_inactive: StandardMaterial3D
var mat_active: StandardMaterial3D
var mat_passed: StandardMaterial3D

func _ready() -> void:
	_init_materials()
	body_entered.connect(_on_body_entered)
	if auto_activate:
		set_state(GateState.ACTIVE)
	else:
		set_state(GateState.INACTIVE)

func _init_materials() -> void:
	mat_inactive = StandardMaterial3D.new()
	mat_inactive.albedo_color = Color(0.15, 0.4, 0.6, 0.5)
	mat_inactive.emission_enabled = true
	mat_inactive.emission = Color(0.1, 0.3, 0.5)
	mat_inactive.emission_energy_multiplier = 0.5

	mat_active = StandardMaterial3D.new()
	mat_active.albedo_color = Color(0.1, 0.85, 1.0, 1.0)
	mat_active.emission_enabled = true
	mat_active.emission = Color(0.1, 0.85, 1.0)
	mat_active.emission_energy_multiplier = 3.5

	mat_passed = StandardMaterial3D.new()
	mat_passed.albedo_color = Color(0.2, 1.0, 0.35, 1.0)
	mat_passed.emission_enabled = true
	mat_passed.emission = Color(0.2, 1.0, 0.35)
	mat_passed.emission_energy_multiplier = 2.0

func set_state(new_state: GateState) -> void:
	current_state = new_state
	if not mesh_instance:
		return
	match current_state:
		GateState.INACTIVE:
			mesh_instance.material_override = mat_inactive
		GateState.ACTIVE:
			mesh_instance.material_override = mat_active
		GateState.PASSED:
			mesh_instance.material_override = mat_passed

func _on_body_entered(body: Node) -> void:
	if current_state != GateState.ACTIVE:
		return
	if body is FlightPhysics or body.name == "Quadcopter":
		set_state(GateState.PASSED)
		gate_passed.emit(gate_index)
