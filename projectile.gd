extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 280.0
var damage: float = 18.0
var lifetime: float = 1.6
var hostile: bool = false
var game: Node

func _ready() -> void:
	monitoring = false
	collision_layer = 0
	collision_mask = 0
	if hostile: speed = 130.0
	queue_redraw()

func _physics_process(delta: float) -> void:
	if game.game_finished:
		queue_free()
		return
	var next: Vector2 = position + direction * speed * delta
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(position, next, 1)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		game.effect(Vector2(hit["position"]), Color("61718a"))
		queue_free()
		return
	var targets: Array[Node] = []
	if hostile: targets.append(game.player)
	else: targets = get_tree().get_nodes_in_group("enemies")
	for target in targets:
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(target.position, position, next)
		if target.position.distance_to(closest) < 9.0:
			target.take_damage(damage)
			queue_free()
			return
	position = next
	lifetime -= delta
	if lifetime <= 0.0: queue_free()

func _draw() -> void:
	var ink: Color = Color("bd627e") if hostile else Color("65dddb")
	draw_rect(Rect2(-direction * 6.0 - Vector2(1, 1), Vector2(3, 3)), ink.darkened(0.4))
	draw_rect(Rect2(-2, -2, 4, 4), ink)
	draw_rect(Rect2(-1, -1, 2, 2), Color("dce9ed"))
