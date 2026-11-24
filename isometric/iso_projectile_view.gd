extends Node2D
## Draws a logic-space projectile.gd in the isometric view. The projectile keeps its
## ray-cast hit logic in world space; here its trail and heading are projected and
## lifted to chest height (FLIGHT_HEIGHT) without affecting the sort point.
const IsoMath = preload("res://isometric/iso_math.gd")
const FLIGHT_HEIGHT: float = 12.0
const ARROW: Texture2D = preload("res://assets/effects/spectral_projectile.png")

var source: Node2D

func bind(projectile: Node2D) -> void:
	source = projectile
	name = "ProjectileView"
	_sync()

func _process(_delta: float) -> void:
	if not is_instance_valid(source):
		queue_free()
		return
	_sync()

func _sync() -> void:
	position = IsoMath.world_to_screen(source.position).round()
	queue_redraw()

func _draw() -> void:
	var lift: Vector2 = Vector2(0, -FLIGHT_HEIGHT)
	var heading: Vector2 = IsoMath.direction_to_screen(source.direction)
	var ink: Color = Color("ffa787") if source.hostile else Color("79dedc")
	draw_set_transform(Vector2(0, 1), 0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 3.0, Color("080e1950"))
	draw_set_transform(Vector2.ZERO)
	var trail: Array = source.trail
	for i in range(trail.size()):
		var at: Vector2 = (IsoMath.world_to_screen(trail[i] - source.position) + lift).round()
		draw_rect(Rect2(at - Vector2.ONE, Vector2(2, 2)), Color(ink, (1.0 - float(i) / 5.0) * 0.35))
	if source.hostile:
		draw_set_transform(lift, heading.angle())
		draw_texture_rect(ARROW, Rect2(-36, -16, 48, 32), false, Color(1.1, 0.95, 1.0))
		draw_set_transform(Vector2.ZERO)
	else:
		draw_line(lift - heading * 9, lift + heading * 3, Color("285779"), 3)
		draw_line(lift - heading * 5, lift + heading * 3, ink, 1)
		draw_rect(Rect2(lift - Vector2.ONE, Vector2(3, 3)), Color("c4f4ed"))
