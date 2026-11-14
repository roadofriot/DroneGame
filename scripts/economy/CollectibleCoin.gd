class_name CollectibleCoin
extends Area3D

## CollectibleCoin: Floating 3D Gold Coin with spin, bobbing, and pickup detection.

signal coin_collected(coin_instance: CollectibleCoin, value: int)

@export var coin_value: int = 10
@export var rotation_speed: float = 3.5
@export var bob_amplitude: float = 0.12
@export var bob_frequency: float = 2.5

@onready var mesh_instance: MeshInstance3D = $CoinMesh

var initial_y: float = 0.0
var time_elapsed: float = 0.0
var is_collected: bool = false

func _ready() -> void:
	initial_y = position.y
	# Randomize phase so coin groups don't all bob in lockstep
	time_elapsed = randf_range(0.0, TAU)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_collected:
		return

	time_elapsed += delta
	# Continuous rotation
	rotate_y(rotation_speed * delta)
	# Harmonic vertical bobbing
	position.y = initial_y + sin(time_elapsed * bob_frequency) * bob_amplitude

func _on_body_entered(body: Node) -> void:
	if is_collected:
		return
	if body is FlightPhysics or body.name == "Quadcopter":
		is_collected = true
		coin_collected.emit(self, coin_value)
		# Deactivate and despawn
		set_deferred("monitoring", false)
		visible = false
		queue_free()
