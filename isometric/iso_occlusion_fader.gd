extends Node
## Contextual transparency: tall sprites (back walls, door posts, pillars, statues)
## that are IN FRONT of Kael (larger sort Y) and overlap his silhouette fade out.
## Only cells near the player are checked, so the cost is a few rect tests a frame.
const IsoMath = preload("res://isometric/iso_math.gd")
const FADED_ALPHA: float = 0.5
const FADE_SPEED: float = 5.0
## Kael's on-screen body (not the full frame) relative to his feet.
const SILHOUETTE: Rect2 = Rect2(-6, -40, 12, 40)
## Sprite rects include transparent margins; trim them so an occluder fades only
## when its solid part actually covers Kael (e.g. a pillar beside him stays opaque).
const OCCLUDER_INSET: float = 6.0

var world: Node
var body: Node2D
var view: Node2D
var faded: Dictionary = {}
var rects: Dictionary = {}

func _process(delta: float) -> void:
	if not is_instance_valid(body) or not is_instance_valid(view): return
	var silhouette: Rect2 = Rect2(view.feet() + SILHOUETTE.position, SILHOUETTE.size)
	var base_cell: Vector2i = IsoMath.world_to_cell(body.position)
	var wanted: Dictionary = {}
	# In front on screen means larger x + y; scan a small window biased that way.
	for dy in range(-2, 5):
		for dx in range(-2, 5):
			for item: CanvasItem in world.occluders.get(base_cell + Vector2i(dx, dy), []):
				if item.position.y > view.position.y and _rect(item).intersects(silhouette):
					wanted[item] = true
	for item: CanvasItem in wanted: faded[item] = true
	for item: CanvasItem in faded.keys():
		var target: float = FADED_ALPHA if wanted.has(item) else 1.0
		item.modulate.a = move_toward(item.modulate.a, target, FADE_SPEED * delta)
		if target == 1.0 and item.modulate.a >= 1.0: faded.erase(item)

func is_faded(item: CanvasItem) -> bool:
	return faded.has(item) and item.modulate.a < 1.0

func _rect(item: CanvasItem) -> Rect2:
	if not rects.has(item):
		var sprite: Sprite2D = item as Sprite2D
		rects[item] = (sprite.get_global_transform() * sprite.get_rect()).grow_individual(-OCCLUDER_INSET, 0, -OCCLUDER_INSET, -4)
	return rects[item]
