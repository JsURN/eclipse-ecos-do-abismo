extends Area2D

signal collected(amount: int)

var target: CharacterBody2D
var game: Node
var amount: int = 2
var drift_time: float = 0.0
var pickup_radius: float = 10.0

func _ready() -> void:
	add_to_group("experience_orbs")
	monitoring = false
	collision_layer = 0
	collision_mask = 0
	queue_redraw()

func _physics_process(delta: float) -> void:
	drift_time += delta
	if not is_instance_valid(target) or game.game_finished:
		return
	var distance: float = global_position.distance_to(target.global_position)
	if distance < 64.0 or game.room_cleared or game.wave_timer >= 0.0:
		global_position = global_position.move_toward(target.global_position, 165.0 * delta)
	if distance < pickup_radius:
		collected.emit(amount)
		game.effect(target.position, Color("65dddb"), "collect")
		queue_free()
	queue_redraw()

func _draw() -> void:
	var bob: float = round(sin(drift_time * 4.0))
	draw_rect(Rect2(-3, -3 + bob, 6, 6), Color("25355b"))
	draw_rect(Rect2(-2, -2 + bob, 4, 4), Color("65dddb"))
	draw_rect(Rect2(-1, -2 + bob, 2, 1), Color("b7f6ee"))
