extends StaticBody2D
## A sealable passage. Collision lives in LOGIC space (this body); each sealed cell
## gets one pane in the depth-sorted VIEW so it overlaps actors correctly.
## Isometric counterpart of gate.gd (whose rotated top-down door art does not fit).
## Visual: a vertical curtain of lunar energy standing on the passage's gold
## threshold (rising scanlines, flickering runic bars, a crescent on the middle cell).
const IsoMath = preload("res://isometric/iso_math.gd")
const CURTAIN_HEIGHT: float = 34.0

var cells: Array[Vector2i] = []
var panes: Array[Node2D] = []
var shapes: Array[CollisionShape2D] = []
## Grid direction in which the sealed cells are lined up (the curtain's plane).
var along: Vector2i = Vector2i(0, 1)
var amount: float = 0.0
var closed: bool = false
var showing: bool = false
var seal_tween: Tween

func setup(seal_cells: Array, depth: Node2D) -> void:
	collision_layer = 1
	collision_mask = 0
	for cell: Vector2i in seal_cells: cells.append(cell)
	along = Vector2i(0, 1) if cells.front().x == cells.back().x else Vector2i(1, 0)
	var half: Vector2 = IsoMath.world_to_screen(Vector2(along) * IsoMath.CELL * 0.5)
	for i in range(cells.size()):
		var cell: Vector2i = cells[i]
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rectangle: RectangleShape2D = RectangleShape2D.new()
		rectangle.size = Vector2(IsoMath.CELL, IsoMath.CELL)
		shape.shape = rectangle
		shape.position = IsoMath.cell_center(cell)
		shape.disabled = true
		add_child(shape)
		shapes.append(shape)
		var pane: SealPane = SealPane.new()
		pane.name = "SealPane"
		pane.seal = self
		pane.half = half
		pane.index = i
		pane.count = cells.size()
		# Sorted one pixel ahead of the arch slice of the same cell, so the voussoirs in
		# front of the curtain plane cover it (drawn back at the cell centre in _draw).
		pane.position = IsoMath.cell_to_screen(cell) - Vector2(0, 1)
		depth.add_child(pane)
		panes.append(pane)

## Curtain height along each pane: 9 samples from its low end to its high end along
## the passage (iso_world.gd fits them under the arch's intrados).
func fit_opening(tops: Array) -> void:
	for i in range(panes.size()): panes[i].tops = tops[i]

## Screen segment across the passage, drawn on the floor by iso_floor_glow.gd.
func threshold() -> PackedVector2Array:
	var step: Vector2 = Vector2(along) * IsoMath.CELL * 0.5
	return PackedVector2Array([
		IsoMath.world_to_screen(IsoMath.cell_center(cells.front()) - step),
		IsoMath.world_to_screen(IsoMath.cell_center(cells.back()) + step),
	])

func set_closed(value: bool) -> void:
	closed = value
	for shape in shapes: shape.set_deferred("disabled", not value)
	if seal_tween and seal_tween.is_running(): seal_tween.kill()
	seal_tween = create_tween()
	seal_tween.tween_property(self, "amount", 1.0 if value else 0.0, 0.35)

func _process(_delta: float) -> void:
	# Redraw while visible, plus one last frame after fading out (clears the pane).
	if amount > 0.0 or showing:
		for pane in panes: pane.queue_redraw()
	showing = amount > 0.0

class SealPane extends Node2D:
	var seal: Node
	## Screen half-extent of the curtain base along the passage width.
	var half: Vector2
	var index: int = 0
	var count: int = 1
	## Curtain height at 9 points along the pane (fit_opening); flat when empty.
	var tops: PackedFloat32Array = PackedFloat32Array()

	func _top(f: float) -> float:
		if tops.is_empty(): return CURTAIN_HEIGHT
		var x: float = clampf(f, 0.0, 1.0) * (tops.size() - 1)
		var i: int = mini(int(x), tops.size() - 2)
		return lerpf(tops[i], tops[i + 1], x - i)

	func _draw() -> void:
		var strength: float = float(seal.amount)
		if strength <= 0.01: return
		draw_set_transform(Vector2(0, 1))
		var t: float = Time.get_ticks_msec() * 0.001
		var height: float = 0.0
		for f in range(9): height = maxf(height, _top(f / 8.0))
		var pulse: float = 0.85 + sin(t * 6.0 + index) * 0.15
		var a: Vector2 = -half
		var b: Vector2 = half
		# Curtain body follows the opening: its top edge traces the arch.
		var outline: PackedVector2Array = PackedVector2Array([a, b])
		for j in range(8, -1, -1): outline.append(a.lerp(b, j / 8.0) - Vector2(0, roundf(_top(j / 8.0))))
		draw_colored_polygon(outline, Color(0.3, 0.2, 0.46, 0.24 * strength))
		var band: Vector2 = Vector2(0, -9)
		draw_colored_polygon(PackedVector2Array([a, b, b + band, a + band]), Color(0.47, 0.87, 0.86, 0.14 * strength * pulse))
		for j in range(4):
			var z: float = floorf(fmod(t * 16.0 + j * height / 4.0 + index * 5.0, height))
			var ink: Color = Color(0.73, 0.58, 0.82, (1.0 - z / height) * 0.7 * strength)
			for m in range(8):
				# Scanline pieces only where the opening is taller than the line.
				if minf(_top(m / 8.0), _top((m + 1) / 8.0)) > z:
					draw_line(a.lerp(b, m / 8.0) - Vector2(0, z), a.lerp(b, (m + 1) / 8.0) - Vector2(0, z), ink, 1.0)
		for k in range(3):
			var f_k: float = (k + 0.5) / 3.0
			var foot: Vector2 = a.lerp(b, f_k).round()
			var flicker: float = 0.5 + 0.5 * sin(t * 9.0 + k * 2.1 + index * 1.7)
			draw_line(foot, foot - Vector2(0, roundf((_top(f_k) - 1.0) * (0.55 + 0.45 * flicker))), Color(0.4, 0.86, 0.86, 0.4 * strength * flicker), 1.0)
		var rim: PackedVector2Array = PackedVector2Array()
		for j in range(9): rim.append(a.lerp(b, j / 8.0) - Vector2(0, roundf(_top(j / 8.0))))
		draw_polyline(rim, Color(0.73, 0.58, 0.82, 0.5 * strength), 1.0)
		draw_line(a, b, Color(0.77, 0.65, 0.42, 0.95 * strength), 1.0)
		if index == count / 2:
			var center: Vector2 = Vector2(0, -roundf(minf(_top(0.5), CURTAIN_HEIGHT + 6.0) * 0.55))
			draw_arc(center, 5.0, PI * 0.3, PI * 1.7, 16, Color(0.79, 0.98, 0.95, 0.9 * strength * pulse), 1.0)
			draw_arc(center + Vector2(2, -1), 3.6, PI * 0.45, PI * 1.55, 12, Color(0.4, 0.86, 0.86, 0.5 * strength * pulse), 1.0)
