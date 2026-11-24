extends Node2D
## Visual proxy of a LOGIC body (player.gd / enemy.gd) inside the Y-sorted view.
##
## The body keeps simulating in cartesian space; this node sits at the projected
## FOOT position, so Y-sort compares Kael's feet against wall/prop bases. Sprites
## and lights that the body created for itself are moved here unchanged, and the
## PixelActor receives the projection basis so it faces the screen direction.
## Height (dais, stairs) is applied to `lift_root` only, never to the sort point.
const IsoMath = preload("res://isometric/iso_math.gd")

var source: Node2D
var world: Node
var lift_root: Node2D
var shadow_radius: float = 8.0
var lift: float = 0.0

func bind(body: Node2D, iso_world: Node, radius: float) -> void:
	source = body
	world = iso_world
	shadow_radius = radius
	name = String(body.name) + "View"
	lift_root = Node2D.new()
	lift_root.name = "Lift"
	add_child(lift_root)
	for child in body.get_children():
		# Collision shapes stay in logic space; only visuals and lights move.
		if child is AnimatedSprite2D or child is Sprite2D or child is Light2D:
			child.reparent(lift_root, false)
			if "facing_transform" in child:
				child.facing_transform = IsoMath.BASIS
				child.up_threshold = -0.3
	body.set_meta("iso_view", self)
	_sync(0.0)

func _process(delta: float) -> void:
	if not is_instance_valid(source):
		queue_free()
		return
	_sync(delta)

func _sync(delta: float) -> void:
	var target_lift: float = float(world.height_at(source.position))
	lift = target_lift if delta <= 0.0 else move_toward(lift, target_lift, 60.0 * delta)
	position = IsoMath.world_to_screen(source.position).round()
	lift_root.position = Vector2(0, -roundf(lift))
	modulate = source.modulate
	queue_redraw()

## Feet point including height; used by the camera-facing helpers and effects.
func feet() -> Vector2:
	return global_position + lift_root.position

func _draw() -> void:
	var ground: Vector2 = lift_root.position + Vector2(0, 1)
	draw_set_transform(ground, 0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, shadow_radius, Color("080e1970"))
	draw_set_transform(Vector2.ZERO)
	if source.is_in_group("enemies") and "max_health" in source and source.health < source.max_health:
		var top: Vector2 = lift_root.position + Vector2(-10, -31)
		draw_rect(Rect2(top, Vector2(20, 3)), Color("080e19"))
		draw_rect(Rect2(top + Vector2(1, 1), Vector2(maxf(0, 18 * source.health / source.max_health), 1)), Color("ff947f"))
