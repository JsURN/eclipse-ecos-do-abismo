extends Node2D
## Everything that lies ON the floor and must stay under actors and walls: contact
## shadows of tall props, pulsing runes, the exit/moon seal rings and the dormant
## gold thresholds of the sealable passages. Drawn between the floor tiles and the
## depth-sorted layer, so it never covers actors or walls.
const IsoMath = preload("res://isometric/iso_math.gd")

var rune_cells: Array[Vector2i] = []
var seal_cells: Array[Vector2i] = []
var heights: Dictionary = {}
## [screen position, horizontal radius] — flattened ellipses under props.
var shadows: Array = []
## Screen-space segments across each sealable passage (iso_seal.gd threshold()).
var thresholds: Array[PackedVector2Array] = []
## Shallow water cells (set): stone banks + drifting glints.
var water_cells: Dictionary = {}
## Gilded floor inlays: {"center": world Vector2, "radius": world units, "kind": "mosaic" | "ring"}.
var inlays: Array[Dictionary] = []
var time: float = 0.0
const GOLD_INLAY: Color = Color(0.77, 0.65, 0.42, 0.55)
const WATER_EDGES: Array = [[Vector2i(-1, 0), Vector2(-16, 0), Vector2(0, -8)], [Vector2i(0, -1), Vector2(0, -8), Vector2(16, 0)], [Vector2i(1, 0), Vector2(16, 0), Vector2(0, 8)], [Vector2i(0, 1), Vector2(0, 8), Vector2(-16, 0)]]

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	for inlay in inlays: _inlay(inlay)
	for cell: Vector2i in water_cells:
		var at: Vector2 = IsoMath.cell_to_screen(cell)
		for edge in WATER_EDGES:
			if water_cells.has(cell + edge[0]): continue
			draw_line(at + edge[1], at + edge[2], Color(0.38, 0.45, 0.66, 0.55), 1.0)
		var drift: float = fmod(time * 3.0 + float((cell.x * 7 + cell.y * 13) % 11), 11.0) - 5.5
		var glint: Vector2 = (at + Vector2(drift, drift * 0.25 - 1.0)).round()
		draw_line(glint, glint + Vector2(3, 0), Color(0.6, 0.95, 0.95, 0.35 * (1.0 - absf(drift) / 5.5)), 1.0)
	for shadow in shadows:
		_ellipse(shadow[0], float(shadow[1]), Color(0.0, 0.0, 0.03, 0.38))
		_ellipse(shadow[0], float(shadow[1]) * 0.6, Color(0.0, 0.0, 0.03, 0.22))
	for i in range(rune_cells.size()):
		var at: Vector2 = IsoMath.cell_to_screen(rune_cells[i])
		var alpha: float = 0.12 + (sin(time * 2.0 + i) + 1.0) * 0.06
		_diamond(at, 0.75, Color(0.4, 0.86, 0.86, alpha))
	for i in range(seal_cells.size()):
		var at: Vector2 = IsoMath.cell_to_screen(seal_cells[i]) - Vector2(0, float(heights.get(seal_cells[i], 0.0)))
		var grow: float = fmod(time * 0.6 + i * 0.3, 1.0)
		_diamond(at, 0.6 + grow * 1.6, Color(0.47, 0.87, 0.86, (1.0 - grow) * 0.5), false)
	# Dormant thresholds: a thin aged-gold line with rune studs tells the player
	# "this passage can close" before the encounter ever starts.
	for line in thresholds:
		var shimmer: float = 0.32 + sin(time * 1.4) * 0.08
		draw_line(line[0], line[1], Color(0.77, 0.65, 0.42, shimmer), 1.0)
		for k in range(5):
			var stud: Vector2 = line[0].lerp(line[1], k / 4.0).round()
			draw_rect(Rect2(stud - Vector2(1, 0), Vector2(2, 1)), Color(0.4, 0.86, 0.86, shimmer * 0.9))

## World-space circle projected to the floor (2:1 ellipse), pixel-snapped.
func _iso_ring(center: Vector2, radius: float, ink: Color, segments: int = 48) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(segments + 1):
		points.append(IsoMath.world_to_screen(center + Vector2.from_angle(TAU * i / segments) * radius).round())
	draw_polyline(points, ink, 1.0)

func _inlay(inlay: Dictionary) -> void:
	var center: Vector2 = inlay["center"]
	var radius: float = float(inlay["radius"])
	var glint: float = 0.85 + sin(time * 0.9) * 0.15
	if inlay["kind"] == "corona":
		# Eclipse corona: 24 engraved rays of alternating length, faint lunar studs.
		for i in range(24):
			var direction_c: Vector2 = Vector2.from_angle(TAU * i / 24.0)
			var inner: float = radius - (10.0 if i % 2 == 0 else 6.0)
			draw_line(IsoMath.world_to_screen(center + direction_c * inner).round(), IsoMath.world_to_screen(center + direction_c * radius).round(), Color(0.27, 0.3, 0.52, 0.5), 1.0)
			if i % 3 == 0:
				var stud_c: Vector2 = IsoMath.world_to_screen(center + direction_c * (radius + 3.0)).round()
				draw_rect(Rect2(stud_c, Vector2(1, 1)), Color(0.55, 0.5, 0.85, 0.45 * glint))
		return
	_iso_ring(center, radius, Color(GOLD_INLAY, GOLD_INLAY.a * glint))
	_iso_ring(center, radius - 4.0, Color(0.27, 0.34, 0.55, 0.45))
	for i in range(8):
		var direction: Vector2 = Vector2.from_angle(TAU * i / 8.0 + PI / 8.0)
		var stud: Vector2 = IsoMath.world_to_screen(center + direction * (radius - 2.0)).round()
		draw_rect(Rect2(stud - Vector2(1, 0), Vector2(2, 1)), Color(0.4, 0.86, 0.86, 0.5 * glint))
	if inlay["kind"] != "mosaic": return
	# Lunar mosaic: inner ring, eight spokes and a crescent of inlaid gold.
	_iso_ring(center, radius * 0.5, Color(GOLD_INLAY, 0.4))
	for i in range(8):
		var direction_s: Vector2 = Vector2.from_angle(TAU * i / 8.0)
		draw_line(IsoMath.world_to_screen(center + direction_s * radius * 0.5).round(), IsoMath.world_to_screen(center + direction_s * (radius - 4.0)).round(), Color(0.27, 0.34, 0.55, 0.5), 1.0)
	var crescent: PackedVector2Array = PackedVector2Array()
	for i in range(13):
		crescent.append(IsoMath.world_to_screen(center + Vector2.from_angle(PI * 0.35 + PI * 1.3 * i / 12.0) * radius * 0.32).round())
	for i in range(12, -1, -1):
		crescent.append(IsoMath.world_to_screen(center + Vector2(radius * 0.08, -radius * 0.04) + Vector2.from_angle(PI * 0.45 + PI * 1.1 * i / 12.0) * radius * 0.24).round())
	draw_colored_polygon(crescent, Color(0.4, 0.86, 0.86, 0.22 * glint))
	draw_polyline(crescent, Color(GOLD_INLAY, 0.7), 1.0)

func _ellipse(at: Vector2, radius: float, ink: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(16):
		var angle: float = TAU * i / 16.0
		points.append(at + Vector2(cos(angle) * radius, sin(angle) * radius * 0.5))
	draw_colored_polygon(points, ink)

func _diamond(at: Vector2, scale_factor: float, ink: Color, filled: bool = true) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for corner in [Vector2(0, -8), Vector2(16, 0), Vector2(0, 8), Vector2(-16, 0)]:
		points.append(at + corner * scale_factor)
	if filled:
		draw_colored_polygon(points, ink)
	else:
		points.append(points[0])
		draw_polyline(points, ink, 1.0)
