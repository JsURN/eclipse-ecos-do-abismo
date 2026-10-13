extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 280.0
var damage: float = 18.0
var lifetime: float = 1.6
var hostile: bool = false
var game: Node
var trail: Array[Vector2] = []

func _ready() -> void:
	monitoring = false
	collision_layer = 0
	collision_mask = 0
	if hostile: speed = 130.0
	z_index = 6
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
	trail.push_front(position)
	if trail.size() > 5: trail.pop_back()
	queue_redraw()
	lifetime -= delta
	if lifetime <= 0.0: queue_free()

func _draw() -> void:
	var ink: Color = Color("ffa787") if hostile else Color("79dedc")
	for i in range(trail.size()):
		var at: Vector2 = (trail[i] - position).round()
		draw_rect(Rect2(at - Vector2.ONE, Vector2(2, 2)), Color(ink, (1.0 - float(i) / 5.0) * 0.35))
	if hostile:
		# Warm diamond and violet rim remain distinct even without color alone.
		draw_colored_polygon(PackedVector2Array([Vector2(0,-5), Vector2(5,0), Vector2(0,5), Vector2(-5,0)]), Color("735585"))
		draw_colored_polygon(PackedVector2Array([Vector2(0,-3), Vector2(3,0), Vector2(0,3), Vector2(-3,0)]), ink)
		draw_rect(Rect2(-1, -1, 2, 2), Color("fff0cf"))
	else:
		draw_line(-direction * 9, direction * 3, Color("285779"), 3)
		draw_line(-direction * 5, direction * 3, ink, 1)
		draw_rect(Rect2(-1, -1, 3, 3), Color("c4f4ed"))
