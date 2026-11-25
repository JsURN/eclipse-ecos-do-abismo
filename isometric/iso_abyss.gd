extends Node2D
## The deep rock beyond the halls. Instead of a flat dark plain (which read as an
## unfinished void, or worse, as walkable floor), the rock shelf the catacombs are
## carved into breaks off into terraces that step down into darkness:
##   * the shelf edge is irregular (its reach varies per cell), so no straight borders;
##   * each terrace is lower and hazier than the last (DEPTHS), with strata faces
##     hanging from every lip (abyss_faces.png) that fade to black;
##   * a few ruined column silhouettes stand on the deep terraces, and a handful of
##     distant lights glimmer far below: the catacombs are part of a much larger ruin.
## Purely visual and static: drawn once, under the floor tiles, never on a floor cell
## or next to one (the shelf is always at least ROCK_REACH - 2 cells wide), so it can
## never be mistaken for a walkable area and never touches collision or navigation.
const IsoMath = preload("res://isometric/iso_math.gd")

## Screen drop (px) of each terrace step away from the shelf.
const DEPTHS: Array[int] = [0, 14, 30, 50, 76, 108, 140]
## Haze laid over a terrace at full depth (deep blue-violet, never pure black).
const FOG: Color = Color(0.11, 0.12, 0.24)
const FAR_LIGHTS: Array[Color] = [Color("65dddb"), Color("9674d6"), Color("9d855c")]

var world: Node
var rock_texture: Texture2D
var face_texture: Texture2D
## cell -> terrace step (1..) for abyss cells; shelf cells are absent.
var steps: Dictionary = {}
## Rock shelf cells (non-floor, not abyss) around the halls.
var shelf: Dictionary = {}
## Painter-ordered draw list, built once.
var order: Array[Vector2i] = []
var silhouettes: Dictionary = {}
var far_lights: Dictionary = {}
## Canvas item being painted (the bake viewport's painter) while _paint runs.
var pen: CanvasItem

func setup(world_node: Node, rock: Texture2D, faces: Texture2D) -> void:
	name = "Abyss"
	world = world_node
	rock_texture = rock
	face_texture = faces
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## Shelf reach (in cells from the nearest floor) varies 4..6 for an organic edge: just
## past the raised rock mass, so the abyss shows in normal play, while the shelf stays
## wide enough that halls never read as floating platforms.
## In front of a hall (below it on screen) the rock is already cut low, so the shelf is
## only 3..4 cells deep there and then steps down gradually: halls rest on a massif
## that descends in terraces, never on a sheer edge.
static func reach(cell: Vector2i, noise: int, max_reach: int, in_front: bool = false) -> int:
	if in_front: return 3 + (noise / 11) % 2
	return max_reach - 1 - (noise / 11) % 3

## Registers a non-floor cell `distance` cells away from the halls. Returns true when it
## belongs to the abyss (the caller then paints no rock tile there).
func classify(cell: Vector2i, distance: int, noise: int, max_reach: int, in_front: bool = false) -> bool:
	var edge: int = reach(cell, noise, max_reach, in_front)
	if distance <= edge:
		shelf[cell] = true
		return false
	steps[cell] = DEPTHS.size() - 1
	return true

## Terrace drop of a cell. Terraces are flat: their outline (the irregular shelf edge
## and the graded steps) carries the irregularity, not per-cell bumps (stacked cubes).
func depth(cell: Vector2i) -> int:
	var step: int = int(steps.get(cell, 0))
	if step == 0: return 0
	return DEPTHS[step]

## Sorts terraces deepest first, then back to front, and queues the single redraw.
## Shelf cells bordering the abyss are included (depth 0) to hang their cliff faces.
func build() -> void:
	_grade_steps()
	for cell: Vector2i in steps:
		var noise: int = world._noise(cell)
		var step: int = int(steps[cell])
		if step >= 3 and noise % 41 == 0 and not _near(silhouettes, cell, 3): silhouettes[cell] = noise
		elif step >= 4 and noise % 29 == 0: far_lights[cell] = noise
	var cells: Dictionary = {}
	for cell: Vector2i in steps:
		cells[cell] = true
		for offset: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1)]:
			if not steps.has(cell + offset) and not world.is_floor(cell + offset): cells[cell + offset] = true
	order.assign(cells.keys())
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = depth(a)
		var db: int = depth(b)
		if da != db: return da > db
		if a.x + a.y != b.x + b.y: return a.x + a.y < b.x + b.y
		return a.x < b.x)
	_bake()

## Thousands of small primitives with alternating textures would break batching every
## frame, so the terraces are rendered ONCE into an off-screen viewport and shown as a
## single sprite (still lit by the 2D lights and tinted by the world CanvasModulate,
## exactly like the tiles around it).
func _bake() -> void:
	var bounds: Rect2 = Rect2(IsoMath.cell_to_screen(order[0]), Vector2.ZERO)
	for cell in order: bounds = bounds.expand(IsoMath.cell_to_screen(cell))
	bounds = Rect2(bounds.position - Vector2(24, 72), bounds.size + Vector2(48, 72 + DEPTHS[DEPTHS.size() - 1] + 24)).abs()
	bounds.position = bounds.position.floor()
	var viewport: SubViewport = SubViewport.new()
	viewport.name = "Bake"
	viewport.size = Vector2i(bounds.size.ceil())
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter: Node2D = Node2D.new()
	painter.name = "Painter"
	painter.draw.connect(_paint.bind(painter))
	viewport.add_child(painter)
	add_child(viewport)
	# Only valid once the viewport has its canvas (i.e. is inside the tree).
	viewport.canvas_transform = Transform2D(0.0, -bounds.position)
	var picture: Sprite2D = Sprite2D.new()
	picture.name = "Terraces"
	picture.centered = false
	picture.position = bounds.position
	picture.texture = viewport.get_texture()
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(picture)

## Terrace step = distance (8-neighbour) to the nearest shelf cell, capped. Neighbours
## then never differ by more than one step, so every cliff face is one terrace tall.
func _grade_steps() -> void:
	var frontier: Array[Vector2i] = []
	for cell: Vector2i in steps:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if shelf.has(cell + Vector2i(dx, dy)):
					steps[cell] = 1
					frontier.append(cell)
					break
			if int(steps[cell]) == 1: break
	var step: int = 1
	while not frontier.is_empty() and step < DEPTHS.size() - 1:
		step += 1
		var next: Array[Vector2i] = []
		for cell in frontier:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var other: Vector2i = cell + Vector2i(dx, dy)
					if steps.has(other) and int(steps[other]) > step:
						steps[other] = step
						next.append(other)
		frontier = next

## Paints every terrace into the bake viewport (called once, from the painter's draw signal).
func _paint(painter: Node2D) -> void:
	pen = painter
	for cell in order:
		var drop: int = depth(cell)
		var at: Vector2 = IsoMath.cell_to_screen(cell) + Vector2(0, drop)
		var haze: float = clampf(float(drop) / float(DEPTHS[DEPTHS.size() - 1]), 0.0, 1.0)
		var noise: int = world._noise(cell)
		if steps.has(cell):
			var variant: int = (noise / 3) % 4
			# The rock texture is very dark: lift it (modulate > 1) so the terraces read, then
			# veil it with haze. Deeper = hazier and flatter, never just blacker.
			var tint: Color = Color(1.7, 1.75, 2.15).lerp(Color(1.0, 1.05, 1.45), haze)
			pen.draw_texture_rect_region(rock_texture, Rect2(at - Vector2(16, 8), Vector2(32, 16)), Rect2(variant * 32, 40, 32, 16), tint)
			pen.draw_colored_polygon(_diamond(at), Color(FOG, 0.12 + haze * 0.62))
		# Cliff faces hanging from this lip down to the terrace in front of it.
		for side in range(2):
			var front: Vector2i = cell + (Vector2i(0, 1) if side == 0 else Vector2i(1, 0))
			if world.is_floor(front): continue
			var fall: int = depth(front) - drop
			if fall <= 0: continue
			_face(at, side, fall, noise, haze)
		if silhouettes.has(cell): _silhouette(at, silhouettes[cell], haze)
		if far_lights.has(cell): _far_light(at, far_lights[cell])

## side 0 = +y face (lit, screen left), 1 = +x face (shaded, screen right).
func _face(at: Vector2, side: int, fall: int, noise: int, haze: float) -> void:
	var a: Vector2 = at + (Vector2(-16, 0) if side == 0 else Vector2(0, 8))
	var b: Vector2 = at + (Vector2(0, 8) if side == 0 else Vector2(16, 0))
	var drop: Vector2 = Vector2(0, fall)
	var strip: int = side * 2 + (noise / 5) % 2
	var u0: float = strip * 16.0 / 64.0
	var u1: float = (strip * 16.0 + 16.0) / 64.0
	var v1: float = minf(1.0, float(fall) / 128.0)
	var lip: Color = Color(1.45, 1.5, 1.75).lerp(Color(0.85, 0.9, 1.2), haze)
	var foot: Color = lip.darkened(clampf(float(fall) / 90.0, 0.2, 0.5))
	pen.draw_polygon(PackedVector2Array([a, b, b + drop, a + drop]), PackedColorArray([lip, lip, foot, foot]),
		PackedVector2Array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, v1), Vector2(u0, v1)]), face_texture)

## Ruined column far below: a shaft (lit left half, dark right half) with a broken top
## and, sometimes, a stub of the arch it once carried. Fades into the haze.
func _silhouette(at: Vector2, noise: int, haze: float) -> void:
	var fade: float = 0.55 - haze * 0.25
	var lit: Color = Color("242b48") * Color(fade * 1.6, fade * 1.6, fade * 1.6)
	var dark: Color = Color("12162a") * Color(fade * 1.6, fade * 1.6, fade * 1.6)
	lit.a = 1.0
	dark.a = 1.0
	var tall: int = 22 + noise % 24
	var base: Vector2 = at.round()
	pen.draw_rect(Rect2(base.x - 5, base.y - 2, 12, 3), dark)
	pen.draw_rect(Rect2(base.x - 4, base.y - tall, 4, tall), lit)
	pen.draw_rect(Rect2(base.x, base.y - tall, 4, tall), dark)
	# Broken top: one side snapped lower than the other.
	pen.draw_rect(Rect2(base.x - 4, base.y - tall - 3, 3, 3), lit)
	pen.draw_rect(Rect2(base.x - 4, base.y - tall, 1, tall), lit.lightened(0.12))
	if noise % 3 == 0:
		pen.draw_rect(Rect2(base.x - 6, base.y - tall - 6, 14, 3), lit)
		pen.draw_rect(Rect2(base.x + 8, base.y - tall - 6, 6, 3), dark)

func _far_light(at: Vector2, noise: int) -> void:
	var ink: Color = FAR_LIGHTS[noise % FAR_LIGHTS.size()]
	var p: Vector2 = (at + Vector2(float(noise % 9) - 4.0, -float((noise / 9) % 5))).round()
	for offset: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		pen.draw_rect(Rect2(p + offset, Vector2.ONE), Color(ink, 0.22))
	pen.draw_rect(Rect2(p, Vector2.ONE), Color(ink, 0.75))

static func _diamond(at: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at + Vector2(0, -8), at + Vector2(16, 0), at + Vector2(0, 8), at + Vector2(-16, 0)])

static func _near(cells: Dictionary, cell: Vector2i, distance: int) -> bool:
	for other: Vector2i in cells:
		if absi(other.x - cell.x) <= distance and absi(other.y - cell.y) <= distance: return true
	return false
