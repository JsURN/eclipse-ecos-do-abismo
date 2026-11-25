extends SceneTree
## Generates the procedural FIRST-PASS art kit of the isometric Catacumbas do Eclipse.
## Replaces the flat blocks of tools/build_iso_placeholders.gd (kept for reference).
## Run:  godot --headless --path . --script tools/build_iso_art.gd
## then: godot --headless --path . --editor --quit   (imports the PNGs)
##
## Everything is rasterised from real isometric geometry (boxes and cylinders in
## cell-local space), so faces, tops and decorations share one projection:
##   cell-local (u, v, z): u = +x grid, v = +y grid, 0..16 per cell; z = pixels up.
##   image = origin + (u - v, (u + v) / 2 - z)   (origin = top vertex of the base diamond)
## Conventions every hand-drawn replacement must keep (docs/ISOMETRIC_PROTOTYPE.md):
## - 2:1 diamonds; one logical cell = 32x16 px on screen.
## - Floor atlases: 32x32 regions, ground diamond in the BOTTOM 16 rows.
## - Blocks: 32 px wide, base diamond centre 8 px above the image bottom.
const OUT: String = "res://assets/isometric/catacombs/"

enum { TOP, LEFT, RIGHT, SIDE }

# --- palette: blue-black stone, deep purple, luminous cyan, aged gold ----------
const VOID_TONES: Array[Color] = [Color("07090f"), Color("0a0d18"), Color("0d1120")]
const STONE: Array[Color] = [Color("252b44"), Color("29304c"), Color("2d3553"), Color("313a5a")]
const TONES: Array[float] = [-0.06, -0.025, 0.0, 0.03, 0.065]
const JOINT: Color = Color("131829")
const CRACK: Color = Color("0b0f1e")
const MORTAR: Color = Color("11152a")
const MOSS: Array[Color] = [Color("203b3a"), Color("294b45"), Color("355d52")]
const ASH: Color = Color("1c2030")
const WALL_L: Color = Color("2d3659")
const WALL_R: Color = Color("1f2644")
const WALL_TOP: Color = Color("131829")
const RIM: Color = Color("4a5582")
const CAP: Color = Color("3c4672")
const CYAN_DEEP: Color = Color("285779")
const CYAN: Color = Color("65dddb")
const CYAN_GLOW: Color = Color("c9fbf3")
const GOLD_DEEP: Color = Color("6b5838")
const GOLD_DARK: Color = Color("9d855c")
const GOLD: Color = Color("c4a66b")
const GOLD_LIGHT: Color = Color("e6d29c")
const PURPLE_DEEP: Color = Color("251b36")
const PURPLE: Color = Color("3f2f55")
const PURPLE_MID: Color = Color("59426c")
const PURPLE_LIGHT: Color = Color("b995d0")
const BONE: Color = Color("b3ad99")
const BONE_DARK: Color = Color("787467")
const IRON: Color = Color("171a26")
const WOOD: Color = Color("3a2a52")
const NICHE: Color = Color("0b0e1b")
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

## Flagstone partitions of one cell (u, v, du, dv).
var layouts: Array = [
	[Rect2(0, 0, 8, 8), Rect2(8, 0, 8, 8), Rect2(0, 8, 8, 8), Rect2(8, 8, 8, 8)],
	[Rect2(0, 0, 16, 6), Rect2(0, 6, 9, 10), Rect2(9, 6, 7, 10)],
	[Rect2(0, 0, 10, 10), Rect2(10, 0, 6, 10), Rect2(0, 10, 16, 6)],
	[Rect2(0, 0, 6, 16), Rect2(6, 0, 10, 7), Rect2(6, 7, 10, 9)],
	[Rect2(0, 0, 16, 16)],
	[Rect2(0, 0, 8, 16), Rect2(8, 0, 8, 5), Rect2(8, 5, 8, 11)],
]

## Wall atlas rows (see iso_world.gd WALL_ROWS). Suffix _L / _R = decoration on the
## +y (left) or +x (right) face, the one that faces the room.
## Rows 17+ (stage 4) are appended so existing row indices never move.
const FULL_ROWS: Array[String] = ["plain", "plain", "plain", "cracked", "mossy", "rune_L", "rune_R", "banner_L", "banner_R", "sconce_L", "sconce_R", "niche_L", "niche_R", "pier_L", "pier_R", "quoin", "broken", "displaced", "scorched", "relief_L", "relief_R", "loculi_L", "loculi_R", "seep", "inscription_L", "inscription_R"]
const LOW_ROWS: Array[String] = ["plain", "plain", "cracked", "mossy", "broken", "scorched", "displaced"]
const ROCK_HEIGHTS: Array[int] = [0, 12, 20, 28, 40]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var started: int = Time.get_ticks_msec()
	var jobs: Dictionary = {
		"floor_atlas.png": _floor_atlas(),
		"floor_shade.png": _shade_atlas(),
		"floor_decals.png": _decal_atlas(),
		"wall_full.png": _wall_atlas(40, FULL_ROWS),
		"wall_low.png": _wall_atlas(12, LOW_ROWS),
		"wall_broken_a.png": _broken_wall(0),
		"wall_broken_b.png": _broken_wall(1),
		"pillar_a.png": _pillar(false),
		"pillar_b.png": _pillar(true),
		"door_post.png": _door_post(),
		"lintel_x.png": _lintel(true, false),
		"lintel_x_key.png": _lintel(true, true),
		"lintel_y.png": _lintel(false, false),
		"lintel_y_key.png": _lintel(false, true),
		"sarcophagus.png": _sarcophagus(),
		"chest_closed.png": _chest(false),
		"chest_open.png": _chest(true),
		"pedestal.png": _pedestal(),
		"candles.png": _candles(),
		"rock_atlas.png": _rock_atlas(),
		"pillar_stump.png": _pillar_stump(),
		"fallen_column.png": _fallen_column(),
		"urns.png": _urns(),
		"bone_pile.png": _bone_pile(),
		# Stage 4: ruined arch stubs, abyss cliff strata, distant column silhouettes.
		"lintel_x_stub_a.png": _lintel_stub(true, false),
		"lintel_x_stub_b.png": _lintel_stub(true, true),
		"lintel_y_stub_a.png": _lintel_stub(false, false),
		"lintel_y_stub_b.png": _lintel_stub(false, true),
		"abyss_faces.png": _abyss_faces(),
	}
	var failed: bool = false
	for file: String in jobs:
		var image: Image = jobs[file]
		if image.save_png(ProjectSettings.globalize_path(OUT + file)) != OK: failed = true
	print("Isometric art kit: %d images in %s (%d ms); failed=%s" % [jobs.size(), OUT, Time.get_ticks_msec() - started, failed])
	quit(1 if failed else 0)

# --- primitives -------------------------------------------------------------------

static func _h(a: int, b: int, c: int = 0) -> int:
	return ((a * 73856093) ^ (b * 19349663) ^ (c * 83492791)) & 0x7fffffff

static func _tone(ink: Color, amount: float) -> Color:
	return ink.lightened(amount) if amount >= 0.0 else ink.darkened(-amount)

static func _dither(alpha: float, x: int, y: int, steps: float) -> float:
	var level: float = alpha * steps
	var base: float = floorf(level)
	if level - base > (BAYER[(y % 4) * 4 + x % 4] + 0.5) / 16.0: base += 1.0
	return base / steps

static func _ink(image: Image, x: int, y: int, ink: Color) -> void:
	if ink.a <= 0.0 or x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height(): return
	image.set_pixel(x, y, ink if ink.a >= 1.0 else image.get_pixel(x, y).blend(ink))

static func _blank(width: int, height: int) -> Image:
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	return image

## Axis-aligned box [lo, hi] in cell-local iso space. Visible faces: TOP (z = hi.z),
## LEFT (+y face, v = hi.y) and RIGHT (+x face, u = hi.x).
## shade(face, u, v, z) -> Color; alpha 0 leaves the pixel untouched.
static func _box(image: Image, origin: Vector2, lo: Vector3, hi: Vector3, shade: Callable) -> void:
	var x0: int = maxi(0, int(floorf(origin.x + lo.x - hi.y)) - 1)
	var x1: int = mini(image.get_width(), int(ceilf(origin.x + hi.x - lo.y)) + 1)
	var y0: int = maxi(0, int(floorf(origin.y + (lo.x + lo.y) * 0.5 - hi.z)) - 1)
	var y1: int = mini(image.get_height(), int(ceilf(origin.y + (hi.x + hi.y) * 0.5 - lo.z)) + 1)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var a: float = x + 0.5 - origin.x
			var b: float = y + 0.5 - origin.y
			var u: float = b + hi.z + a * 0.5
			var v: float = b + hi.z - a * 0.5
			if u >= lo.x and u < hi.x and v >= lo.y and v < hi.y:
				_ink(image, x, y, shade.call(TOP, u, v, hi.z))
				continue
			u = a + hi.y
			if u >= lo.x and u < hi.x:
				var z: float = (u + hi.y) * 0.5 - b
				if z >= lo.z and z < hi.z:
					_ink(image, x, y, shade.call(LEFT, u, hi.y, z))
					continue
			v = hi.x - a
			if v >= lo.y and v < hi.y:
				var z_right: float = (hi.x + v) * 0.5 - b
				if z_right >= lo.z and z_right < hi.z:
					_ink(image, x, y, shade.call(RIGHT, hi.x, v, z_right))

## Flat top-only diamond (floors, overlays). shade(u, v, x, y) -> Color.
static func _flat(image: Image, origin: Vector2, shade: Callable) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var a: float = x + 0.5 - origin.x
			var b: float = y + 0.5 - origin.y
			var u: float = b + a * 0.5
			var v: float = b - a * 0.5
			if u >= 0.0 and u < 16.0 and v >= 0.0 and v < 16.0:
				_ink(image, x, y, shade.call(u, v, x, y))

## Vertical cylinder centred on (cu, cv). TOP gets (TOP, nx, ny, z) on the cap
## ellipse; the side gets (SIDE, s, 0, z) with s in -1 (left/lit) .. 1 (right).
static func _cylinder(image: Image, origin: Vector2, cu: float, cv: float, radius: float, z0: float, z1: float, shade: Callable) -> void:
	var half: float = radius * sqrt(2.0)
	var cx: float = origin.x + cu - cv
	var cy: float = origin.y + (cu + cv) * 0.5
	for y in range(maxi(0, int(cy - z1 - half) - 1), mini(image.get_height(), int(cy - z0 + half) + 2)):
		for x in range(maxi(0, int(cx - half) - 1), mini(image.get_width(), int(cx + half) + 2)):
			var a: float = x + 0.5 - cx
			if absf(a) >= half: continue
			var top_dy: float = y + 0.5 - (cy - z1)
			if (a * a) / (half * half) + (top_dy * top_dy) / (half * half * 0.25) <= 1.0:
				_ink(image, x, y, shade.call(TOP, a / half, top_dy / (half * 0.5), z1))
				continue
			var z: float = cy + sqrt(half * half - a * a) * 0.5 - (y + 0.5)
			if z >= z0 and z < z1:
				_ink(image, x, y, shade.call(SIDE, a / half, 0.0, z))

static func _crescent(s: float, z: float, center: Vector2, radius: float) -> bool:
	var point: Vector2 = Vector2(s, z)
	return point.distance_to(center) < radius and point.distance_to(center + Vector2(radius * 0.38, radius * 0.2)) > radius * 0.78

# --- floor ------------------------------------------------------------------------
## Columns (see iso_world.gd): 0-5 flagstone layouts, 6 cracked, 7 worn, 8 mossy,
## 9 engraved, 10 ash, 11 glowing rune, 12-14 void, 15 dais, 16 dais moon seal,
## 17 stairs, 18 dais (quartered slabs).
func _floor_atlas() -> Image:
	var columns: int = 21
	var image: Image = _blank(columns * 32, 32)
	for column in range(columns):
		var cell: Image = _blank(32, 32)
		var origin: Vector2 = Vector2(16, 16)
		match column:
			19, 20:
				# Shallow black-teal water (seamless; banks are drawn by iso_floor_glow.gd).
				_flat(cell, origin, func(u: float, v: float, x: int, y: int) -> Color:
					var ripple: float = fmod(u * 0.62 + v * 0.38 + sin(v * 0.9 + column) * 0.8 + 16.0, 5.0)
					var ink: Color = Color("0c1b28").lerp(Color("0f2431"), (sin(u * 0.4 + column) + 1.0) * 0.5)
					if ripple < 0.45: return Color("1b3c4c")
					if ripple < 0.9: return Color("132e3c")
					if _h(x, y, column) % 47 == 0: return CYAN_DEEP
					return ink)
			0, 1, 2, 3, 4, 5:
				_flat(cell, origin, func(u: float, v: float, _x: int, _y: int) -> Color: return _flagstone(u, v, column, column, 0.0))
			6, 7, 8, 9, 10, 11:
				_flat(cell, origin, func(u: float, v: float, x: int, y: int) -> Color: return _special_floor(column, u, v, x, y))
			12, 13, 14:
				_flat(cell, origin, func(u: float, v: float, x: int, y: int) -> Color: return _void(column, u, v, x, y))
			15, 16, 18:
				_box(cell, origin, Vector3(0, 0, 0), Vector3(16, 16, 6), func(face: int, u: float, v: float, z: float) -> Color: return _dais(face, u, v, z, column))
			17:
				_box(cell, origin, Vector3(0, 0, 0), Vector3(16, 16, 3), func(face: int, u: float, v: float, z: float) -> Color: return _stairs(face, u, v, z))
		image.blit_rect(cell, Rect2i(0, 0, 32, 32), Vector2i(column * 32, 0))
	return image

func _flagstone(u: float, v: float, layout: int, seed_value: int, bias: float) -> Color:
	var stones: Array = layouts[layout % layouts.size()]
	for i in range(stones.size()):
		var rect: Rect2 = stones[i]
		if not rect.has_point(Vector2(u, v)): continue
		var lu: float = u - rect.position.x
		var lv: float = v - rect.position.y
		if lu < 1.0 or lv < 1.0: return JOINT
		var ink: Color = _tone(STONE[_h(i, layout, seed_value) % STONE.size()], bias)
		# Bevel: back edges catch the light, front edges sink into the joint.
		if lu < 2.0 or lv < 2.0: ink = _tone(ink, 0.07)
		elif lu > rect.size.x - 1.5 or lv > rect.size.y - 1.5: ink = _tone(ink, -0.09)
		var noise: int = _h(int(u), int(v), seed_value * 31 + i)
		if noise % 19 == 0: ink = _tone(ink, 0.06)
		elif noise % 11 == 0: ink = _tone(ink, -0.07)
		return ink
	return JOINT

func _special_floor(column: int, u: float, v: float, x: int, y: int) -> Color:
	var noise: int = _h(int(u), int(v), column * 13)
	match column:
		6: # cracked
			var ink: Color = _flagstone(u, v, 4, 6, -0.01)
			var crack: float = 2.5 + u * 0.62 + sin(u * 1.15) * 1.4
			if absf(v - crack) < 0.55: return CRACK
			if v - crack >= 0.55 and v - crack < 1.4: return _tone(ink, 0.07)
			if u > 9.0 and absf(v - (2.5 + 9.0 * 0.62 + sin(9.0 * 1.15) * 1.4 - (u - 9.0) * 0.85)) < 0.5: return CRACK
			return ink
		7: # worn: centre polished by footsteps, chipped corner
			var ink: Color = _flagstone(u, v, 2, 7, 0.0)
			if ink == JOINT: return ink
			var wear: float = 1.0 - clampf(Vector2(u, v).distance_to(Vector2(8, 8)) / 7.0, 0.0, 1.0)
			ink = _tone(ink, wear * 0.06)
			if u + v > 27.0: return JOINT
			return ink
		8: # moss creeping out of the joints
			var ink: Color = _flagstone(u, v, 0, 8, -0.02)
			var reach: float = Vector2(u, v).distance_to(Vector2(11, 5))
			if reach < 4.5 and noise % 3 != 0: return MOSS[noise % 3]
			if ink == JOINT and reach < 9.0: return MOSS[1]
			if reach < 6.0 and noise % 4 == 0: return MOSS[0]
			return ink
		9: # engraved crescent, worn almost flat
			var ink: Color = _flagstone(u, v, 4, 9, 0.0)
			var radius: float = Vector2(u, v).distance_to(Vector2(8, 8))
			if absf(radius - 5.5) < 0.5: return _tone(ink, -0.16)
			if _crescent(u, v, Vector2(8, 8), 3.6): return PURPLE.darkened(0.25) if noise % 4 == 0 else _tone(ink, -0.12)
			return ink
		10: # ash and soot of the Passagem das Cinzas
			var ink: Color = _flagstone(u, v, 3, 10, -0.05)
			if ink == JOINT: return ASH.darkened(0.25)
			var soot: float = sin(u * 0.7 + 1.3) * cos(v * 0.6) + float(noise % 7) / 14.0
			if soot > 0.55: ink = ink.lerp(ASH, 0.6)
			if noise % 29 == 0: ink = Color("3b3e4e")
			return ink
		11: # glowing lunar rune
			var ink: Color = _flagstone(u, v, 4, 11, -0.04)
			var center: Vector2 = Vector2(8, 8)
			var radius_r: float = Vector2(u, v).distance_to(center)
			if absf(radius_r - 5.6) < 0.6: return CYAN
			if _crescent(u, v, center, 3.4): return CYAN_GLOW
			for tick in [Vector2(8, 1.6), Vector2(14.4, 8), Vector2(8, 14.4), Vector2(1.6, 8)]:
				if Vector2(u, v).distance_to(tick) < 0.8: return CYAN
			if absf(radius_r - 5.6) < 1.6 or radius_r < 4.0: return ink.lerp(CYAN_DEEP, 0.45)
			return ink
	return JOINT

func _void(column: int, u: float, v: float, x: int, y: int) -> Color:
	var noise: int = _h(x, y, column)
	var ink: Color = VOID_TONES[(int(u / 5.0) + int(v / 5.0) + column) % 3]
	if noise % 37 == 0: ink = Color("151b31")
	elif noise % 53 == 0: ink = Color("191431")
	if column == 14 and absf(v - (4.0 + u * 0.5 + sin(u) * 1.2)) < 0.5: ink = Color("141a2e")
	return ink

func _dais(face: int, u: float, v: float, z: float, column: int) -> Color:
	if face == TOP:
		var ink: Color = _flagstone(u, v, 4 if column == 15 else 0, 15, 0.06)
		if column == 16:
			var center: Vector2 = Vector2(8, 8)
			var radius: float = Vector2(u, v).distance_to(center)
			if absf(radius - 6.4) < 0.55: return GOLD
			if absf(radius - 6.4) < 1.3: return ink.lerp(GOLD_DEEP, 0.6)
			if _crescent(u, v, center, 4.0): return CYAN
			if radius < 5.2: return ink.lerp(CYAN_DEEP, 0.35)
			for i in range(8):
				var dot: Vector2 = center + Vector2.from_angle(i * PI / 4.0) * 7.4
				if Vector2(u, v).distance_to(dot) < 0.55: return GOLD_DARK
		return ink
	var base: Color = (WALL_L if face == LEFT else WALL_R).lightened(0.05)
	if z >= 5.0: return GOLD_DARK if face == LEFT else GOLD_DEEP
	var s: float = u if face == LEFT else v
	if fmod(s, 8.0) < 1.0 or z < 1.0: return MORTAR
	return _tone(base, -0.18 * (1.0 - z / 5.0))

func _stairs(face: int, u: float, v: float, z: float) -> Color:
	if face == TOP:
		var step: float = fmod(u + v, 8.0)
		var ink: Color = _tone(STONE[2], 0.04)
		if step < 1.0: return JOINT
		if step < 2.2: return _tone(ink, 0.1)
		return ink
	return _tone(WALL_L if face == LEFT else WALL_R, -0.12)

# --- ambient occlusion at wall bases -------------------------------------------
## 16 columns indexed by a wall-neighbour mask: 1 = -x, 2 = -y (tall back walls,
## strong shade), 4 = +x, 8 = +y (low front walls, thin shade). Dithered alpha.
func _shade_atlas() -> Image:
	var image: Image = _blank(16 * 32, 32)
	for mask in range(16):
		var cell: Image = _blank(32, 32)
		_flat(cell, Vector2(16, 16), func(u: float, v: float, x: int, y: int) -> Color:
			var alpha: float = 0.0
			if mask & 1: alpha = maxf(alpha, 0.6 * pow(clampf(1.0 - u / 6.5, 0.0, 1.0), 1.5))
			if mask & 2: alpha = maxf(alpha, 0.6 * pow(clampf(1.0 - v / 6.5, 0.0, 1.0), 1.5))
			if mask & 4: alpha = maxf(alpha, 0.36 * pow(clampf(1.0 - (16.0 - u) / 3.5, 0.0, 1.0), 1.3))
			if mask & 8: alpha = maxf(alpha, 0.36 * pow(clampf(1.0 - (16.0 - v) / 3.5, 0.0, 1.0), 1.3))
			return Color(0.01, 0.012, 0.04, _dither(alpha, x, y, 5.0)))
		image.blit_rect(cell, Rect2i(0, 0, 32, 32), Vector2i(mask * 32, 0))
	return image

# --- decals -------------------------------------------------------------------------
## Columns: 0 cracks, 1 moss, 2 puddle, 3 pebbles, 4 bones, 5 corruption,
## 6 ritual scratches, 7 soot, 8 dust, 9 scattered coins.
func _decal_atlas() -> Image:
	var columns: int = 10
	var image: Image = _blank(columns * 32, 32)
	for column in range(columns):
		var cell: Image = _blank(32, 32)
		_flat(cell, Vector2(16, 16), func(u: float, v: float, x: int, y: int) -> Color: return _decal(column, u, v, x, y))
		image.blit_rect(cell, Rect2i(0, 0, 32, 32), Vector2i(column * 32, 0))
	return image

func _decal(column: int, u: float, v: float, x: int, y: int) -> Color:
	var noise: int = _h(x, y, column * 7 + 3)
	var point: Vector2 = Vector2(u, v)
	match column:
		0:
			var main: float = 3.0 + u * 0.55 + sin(u * 1.4 + 0.5) * 1.3
			if u > 2.0 and u < 14.0 and absf(v - main) < 0.5: return Color(CRACK, 0.9)
			if u > 6.0 and u < 11.0 and absf(v - (main + (u - 6.0) * 1.1)) < 0.45: return Color(CRACK, 0.8)
			if u > 2.0 and u < 14.0 and v - main > 0.5 and v - main < 1.3: return Color(0.55, 0.6, 0.85, 0.08)
		1:
			var radius: float = 4.5 + sin(atan2(v - 8.0, u - 8.0) * 3.0) * 1.2
			var distance: float = point.distance_to(Vector2(8, 8.5))
			if distance < radius and noise % 5 != 0: return Color(MOSS[noise % 3], 0.92)
			if distance < radius + 1.5 and noise % 3 == 0: return Color(MOSS[0], 0.7)
		2:
			var radius_p: float = 4.8 + sin(atan2(v - 8.0, u - 8.0) * 2.0 + 1.0) * 0.9
			var distance_p: float = point.distance_to(Vector2(8, 8))
			if distance_p < radius_p:
				if distance_p > radius_p - 1.0 and (u < 8.0 or v < 7.0): return Color(CYAN_DEEP, 0.75)
				if noise % 31 == 0: return Color(CYAN_GLOW, 0.55)
				return Color(Color("09121f"), 0.82)
		3:
			for i in range(6):
				var at: Vector2 = Vector2(2.5 + float(_h(i, 1, 33) % 110) / 10.0, 2.5 + float(_h(i, 2, 33) % 110) / 10.0)
				var size: float = 0.9 + float(_h(i, 3, 33) % 7) / 10.0
				var offset: Vector2 = point - at
				if offset.length() < size:
					if offset.x + offset.y < -size * 0.6: return Color("4c5784")
					if offset.x + offset.y > size * 0.6: return JOINT
					return Color("3a4366")
				if offset.length() < size + 0.8 and offset.x + offset.y > 0.0: return Color(0.0, 0.0, 0.03, 0.4)
		4:
			for bone in [[Vector2(3, 5), Vector2(8, 6.5)], [Vector2(9, 11), Vector2(12.5, 7.5)], [Vector2(4, 11), Vector2(6, 13.5)]]:
				var a: Vector2 = bone[0]
				var b: Vector2 = bone[1]
				var t: float = clampf((point - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
				var distance_b: float = point.distance_to(a.lerp(b, t))
				if distance_b < (0.95 if t < 0.12 or t > 0.88 else 0.55): return BONE if (point - a).dot(Vector2(-1, -1)) > -6.0 else BONE_DARK
			var skull: Vector2 = point - Vector2(11.5, 3.5)
			if skull.length() < 1.9:
				if (skull - Vector2(-0.6, 0.6)).length() < 0.45 or (skull - Vector2(0.6, -0.6)).length() < 0.45: return NICHE
				return BONE
			if skull.length() < 2.6 and skull.x + skull.y > 0.0: return Color(0.0, 0.0, 0.03, 0.35)
		5:
			var distance_c: float = point.distance_to(Vector2(8, 8))
			var angle: float = atan2(v - 8.0, u - 8.0)
			if distance_c < 1.6: return Color(PURPLE_LIGHT, 0.9)
			if distance_c < 7.0 and absf(sin(angle * 2.5 + distance_c * 0.55)) < 0.16: return Color(PURPLE_MID, 0.9 - distance_c * 0.1)
			if distance_c < 3.2: return Color(PURPLE, 0.7)
		6:
			var distance_r: float = point.distance_to(Vector2(8, 8))
			var angle_r: float = atan2(v - 8.0, u - 8.0)
			if absf(distance_r - 6.3) < 0.45 and fmod(angle_r + PI, PI / 3.0) < 0.8: return Color(PURPLE.darkened(0.2), 0.8)
			if absf(distance_r - 4.0) < 0.4 and fmod(angle_r + PI, PI / 2.0) < 0.5: return Color(PURPLE_MID, 0.55)
		7:
			var soot: float = sin(u * 0.8) * cos(v * 0.7 + 0.4) + float(noise % 9) / 12.0 - point.distance_to(Vector2(8, 8)) / 9.0
			if soot > 0.3: return Color(ASH.darkened(0.2), 0.55)
			if soot > 0.1 and noise % 5 == 0: return Color("3a3d4d")
		8:
			if point.distance_to(Vector2(9, 7)) < 6.0 and noise % 9 == 0: return Color(0.55, 0.58, 0.72, 0.35)
		9:
			for coin in [Vector2(5, 9), Vector2(10, 6), Vector2(11, 11), Vector2(7, 12)]:
				var offset_c: Vector2 = point - coin
				if offset_c.length() < 0.8: return GOLD_LIGHT if offset_c.x + offset_c.y < 0.0 else GOLD_DARK
	return Color.TRANSPARENT

# --- walls ------------------------------------------------------------------------
## Atlas: 16 columns (top-rim connectivity mask: 1 -x, 2 -y, 4 +x, 8 +y neighbour is
## the same kind of wall, so no rim is drawn on that edge) x one row per variant.
func _wall_atlas(height: int, rows: Array[String]) -> Image:
	var cell_height: int = 16 + height
	var image: Image = _blank(16 * 32, rows.size() * cell_height)
	for row in range(rows.size()):
		var kind: String = rows[row]
		for mask in range(16):
			var cell: Image = _blank(32, cell_height)
			var origin: Vector2 = Vector2(16, cell_height - 16)
			if kind == "broken":
				# Collapsed section: lower body, rubble on top. Taller neighbours keep
				# their own visible faces, so the gap reads as real damage.
				var low: float = float(height) * 0.72
				_box(cell, origin, Vector3(0, 0, 0), Vector3(16, 16, low), func(face: int, u: float, v: float, z: float) -> Color:
					if face == TOP:
						var noise: int = _h(int(u * 1.5), int(v * 1.5), row + mask)
						return Color("323a5c") if noise % 3 == 0 else (Color("252c48") if noise % 3 == 1 else WALL_TOP)
					return _wall_shade(face, u, v, z, low + 3.0, mask, "cracked", row))
				for chunk in [[Vector3(2, 3, low), Vector3(7, 8, low + 4.0)], [Vector3(9, 2, low), Vector3(13, 6, low + 2.5)], [Vector3(4, 10, low), Vector3(8, 14, low + 3.0)]]:
					_box(cell, origin, chunk[0], chunk[1], func(face: int, u: float, v: float, z: float) -> Color:
						return _stone(face, u, v, z, -0.02, row + 50))
			else:
				_box(cell, origin, Vector3(0, 0, 0), Vector3(16, 16, height), func(face: int, u: float, v: float, z: float) -> Color:
					return _wall_shade(face, u, v, z, float(height), mask, kind, row))
			image.blit_rect(cell, Rect2i(0, 0, 32, cell_height), Vector2i(mask * 32, row * cell_height))
	return image

func _wall_shade(face: int, u: float, v: float, z: float, height: float, mask: int, kind: String, seed_value: int) -> Color:
	if face == TOP:
		var ink: Color = WALL_TOP
		var noise: int = _h(int(u), int(v), seed_value + 7)
		if noise % 13 == 0: ink = _tone(ink, 0.08)
		elif noise % 7 == 0: ink = _tone(ink, -0.18)
		if u >= 15.0 and not (mask & 4): return RIM
		if v >= 15.0 and not (mask & 8): return RIM.darkened(0.12)
		if u < 1.0 and not (mask & 1): return RIM.darkened(0.42)
		if v < 1.0 and not (mask & 2): return RIM.darkened(0.42)
		return ink
	var s: float = u if face == LEFT else v
	var ink_face: Color = _masonry(s, z, height, seed_value * 7 + face * 101, WALL_L if face == LEFT else WALL_R)
	return _wall_decor(kind, face, s, z, height, seed_value, ink_face)

## Ashlar courses: plinth, 5 px courses with staggered blocks, capstone.
func _masonry(s: float, z: float, height: float, seed_value: int, base: Color) -> Color:
	if z < 4.0:
		if z >= 3.0: return _tone(base, 0.03)
		if s < 1.0 or absf(s - 8.0) < 0.5: return MORTAR
		return _ao(_tone(base, -0.28), z)
	if z >= height - 3.0:
		if z >= height - 1.0: return _tone(base, 0.22)
		return MORTAR.lerp(base, 0.4) if s < 0.6 else _tone(base, 0.13)
	if z >= height - 4.0: return MORTAR
	var row: int = int((z - 4.0) / 5.0)
	var local_z: float = fmod(z - 4.0, 5.0)
	if local_z < 1.0: return _ao(MORTAR, z)
	var pattern: int = _h(row, 3, seed_value) % 4
	var length: float = 16.0 if pattern == 2 else 8.0
	var offset: float = 4.0 if pattern == 1 or pattern == 3 else 0.0
	var along: float = fmod(s + 16.0 - offset, length)
	if along < 1.0 or s < 0.8: return _ao(MORTAR, z)
	var brick: int = int((s + 16.0 - offset) / length)
	var ink: Color = _tone(base, TONES[_h(row, brick, seed_value) % TONES.size()])
	if _h(row, brick, seed_value + 5) % 17 == 0: ink = _tone(ink, -0.2)
	if local_z >= 4.0: ink = _tone(ink, 0.08)
	elif local_z < 2.0: ink = _tone(ink, -0.05)
	if along < 2.0: ink = _tone(ink, 0.03)
	var noise: int = _h(int(s), int(z), seed_value + 9)
	if noise % 23 == 0: ink = _tone(ink, 0.07)
	elif noise % 13 == 0: ink = _tone(ink, -0.07)
	return _ao(ink, z)

static func _ao(ink: Color, z: float) -> Color:
	return ink.darkened(0.3 * clampf(1.0 - z / 14.0, 0.0, 1.0))

func _wall_decor(kind: String, face: int, s: float, z: float, height: float, seed_value: int, ink: Color) -> Color:
	var parts: PackedStringArray = kind.split("_")
	if parts.size() > 1 and face != (LEFT if parts[1] == "L" else RIGHT): return ink
	var noise: int = _h(int(s), int(z), seed_value + 41)
	match parts[0]:
		"pier":
			# Engaged pilaster: gives long walls a rhythm of bays.
			if s >= 4.0 and s < 12.0:
				if z >= height - 8.0 and z < height - 5.0: return GOLD_DEEP if s >= 11.0 else (GOLD_DARK if z >= height - 6.0 else _tone(CAP, -0.05))
				if z < 6.0: return _tone(CAP, -0.15) if z >= 5.0 else _ao(_tone(CAP, -0.3), z)
				var pier: Color = _tone(WALL_L if face == LEFT else WALL_R, 0.09)
				if fmod(z - 6.0, 7.0) < 1.0: pier = _tone(pier, -0.2)
				if s < 5.0: pier = _tone(pier, 0.12)
				elif s >= 11.0: pier = _tone(pier, -0.18)
				if absf(s - 8.0) < 0.6 and absf(z - height * 0.5) < 3.0: return CYAN_DEEP.lightened(0.15)
				return _ao(pier, z)
			if s >= 12.0 and s < 13.0 and z > 6.0 and z < height - 5.0: return _tone(ink, -0.25)
		"quoin":
			# Outer corner: large alternating corner stones and a thin rune line.
			var course: int = int((z - 4.0) / 6.0)
			var reach: float = 9.0 if course % 2 == 0 else 12.0
			if z > 4.0 and z < height - 4.0 and s > reach:
				if fmod(z - 4.0, 6.0) < 1.0 or absf(s - reach) < 0.8: return MORTAR
				if s > 15.0 and int(z) % 3 == 0: return CYAN_DEEP.lightened(0.1)
				return _ao(_tone(ink, 0.1), z)
			var path: float = 5.0 + sin(z * 0.42 + seed_value) * 2.0 + (height - z) * 0.12
			if z > height * 0.25 and z < height - 1.0:
				if absf(s - path) < 0.6: return CRACK
				if s - path >= 0.6 and s - path < 1.5: return _tone(ink, 0.07)
			if z > 4.0 and z < height * 0.4 and absf(s - (12.0 - z * 0.3)) < 0.5: return CRACK
		"mossy":
			var reach: float = 5.0 + float(_h(int(s), 0, seed_value) % 5)
			if z < reach and noise % 3 != 0: return MOSS[noise % 3]
			var drip: int = _h(int(s), 1, seed_value)
			if drip % 4 == 0 and z > height - 3.0 - float(drip % 9) and z < height - 1.0: return MOSS[1 + drip % 2]
		"rune":
			var center: Vector2 = Vector2(8, height * 0.56)
			if _crescent(s, z, center, 4.2): return CYAN
			if absf(s - 8.0) < 0.5 and z > center.y - 11.0 and z < center.y - 5.0 and int(z) % 2 == 0: return CYAN_DEEP.lightened(0.2)
			if Vector2(s, z).distance_to(center) < 6.0: return ink.lerp(CYAN_DEEP, 0.45 * (1.0 - Vector2(s, z).distance_to(center) / 6.0))
		"banner":
			var top: float = height - 5.0
			if z >= top and z < top + 1.0 and s >= 2.5 and s < 13.5: return GOLD if s < 3.5 or s >= 12.5 else GOLD_DARK
			var bottom: float = height - 31.0 + absf(s - 8.0) * 0.9
			if s >= 4.0 and s < 12.0 and z >= bottom and z < top:
				if s < 5.0 or s >= 11.0 or z < bottom + 1.0: return GOLD_DEEP
				if _crescent(s, z, Vector2(8, height - 15.0), 2.9): return GOLD
				var cloth: Color = PURPLE if int(s) % 3 != 0 else PURPLE_DEEP
				return cloth.darkened(0.25 * (1.0 - (z - bottom) / (top - bottom)))
			if s >= 12.0 and s < 13.0 and z >= bottom and z < top: return _tone(ink, -0.25)
		"sconce":
			var flame_base: float = 24.0
			if absf(s - 8.0) < 0.6 and z >= 18.0 and z < 22.0: return IRON
			if s >= 6.0 and s < 10.0 and z >= 22.0 and z < flame_base: return GOLD_DARK if z >= 23.0 else GOLD_DEEP
			if z >= flame_base and z < flame_base + 6.0:
				var spread: float = 2.0 * (1.0 - (z - flame_base) / 6.0) + 0.3
				if absf(s - 8.0) < spread: return CYAN_GLOW if absf(s - 8.0) < spread * 0.45 and z < flame_base + 4.0 else CYAN
			if absf(s - 8.0) < 1.6 and z >= flame_base + 6.0 and z < flame_base + 11.0: return _tone(ink, -0.2)
			var glow: float = Vector2(s, z).distance_to(Vector2(8, flame_base + 2.0))
			if glow < 7.5: return ink.lerp(CYAN_DEEP.lightened(0.15), 0.55 * (1.0 - glow / 7.5))
		"niche":
			var arch: float = 20.0 + sqrt(maxf(0.0, 16.0 - (s - 8.0) * (s - 8.0))) * 0.9
			if z >= 9.0 and z < 10.0 and s >= 3.0 and s < 13.0: return CAP
			if s >= 3.0 and s < 13.0 and z >= 10.0 and z < arch + 1.0 and (s < 4.0 or s >= 12.0 or z >= arch): return _tone(CAP, -0.1)
			if s >= 4.0 and s < 12.0 and z >= 10.0 and z < arch:
				var skull: Vector2 = Vector2((s - 8.0) / 2.2, (z - 14.0) / 2.0)
				if (Vector2(s, z).distance_to(Vector2(7.1, 14.2)) < 0.6) or (Vector2(s, z).distance_to(Vector2(8.9, 14.2)) < 0.6): return NICHE
				if skull.length() < 1.0: return BONE.lightened(0.08) if s < 7.3 and z > 15.0 else BONE
				if s >= 7.0 and s < 9.0 and z >= 11.0 and z < 12.2: return BONE_DARK
				if s >= 10.0 and s < 11.0 and z >= 10.0 and z < 13.0: return BONE
				if absf(s - 10.5) < 0.6 and z >= 13.0 and z < 14.6: return GOLD_LIGHT
				return NICHE.lerp(GOLD_DEEP, 0.18) if Vector2(s, z).distance_to(Vector2(10.5, 13.5)) < 3.0 else NICHE
		# --- stage 4 -----------------------------------------------------------------
		"displaced":
			# Settled masonry: a few blocks pushed out (lit top, shadow under), one
			# fallen out of the course (dark socket with a lit lower lip).
			var brick: Vector4 = _brick(s, z, height, seed_value * 7 + face * 101)
			if brick.x < 0.0: return ink
			var roll: int = _h(int(brick.x), int(brick.y), seed_value * 3 + face + 77) % 9
			if roll == 0:
				if brick.z < 1.0 or brick.w < 1.0: return ink
				if brick.z < 1.8: return _tone(WALL_L if face == LEFT else WALL_R, 0.06)
				return NICHE if brick.z > 2.6 or brick.w > 2.0 else NICHE.lerp(MORTAR, 0.5)
			if roll <= 2:
				if brick.z >= 4.0: return _tone(ink, 0.16)
				if brick.z < 1.4: return _tone(ink, -0.3)
				if brick.w < 1.6: return _tone(ink, 0.08)
				return _tone(ink, 0.04)
			if roll == 3 and brick.z >= 1.0 and absf(brick.w - 3.5) < 0.5: return CRACK
		"scorched":
			# Soot licking up from the floor in tongues; charred bricks; dull embers.
			var tongue: float = maxf(0.0, sin(s * 0.85 + float(seed_value) * 1.7)) * 0.45
			var soot: float = clampf(1.15 - z / height + tongue * (z / height) + float(noise % 5) * 0.04 - 0.1, 0.0, 1.0)
			var charred: Color = ink.lerp(Color("0c0e16"), soot * 0.8)
			if soot > 0.55 and noise % 17 == 0: return Color("2c2a33")
			if z < 7.0 and noise % 53 == 0: return GOLD_DEEP
			return charred
		"relief":
			# Carved Eclipse in a sunken panel: gilded ring, dark disc, lunar rim, rays.
			var center_e: Vector2 = Vector2(8, height * 0.56)
			var p: Vector2 = Vector2(s, z) - center_e
			var radius_e: float = p.length()
			var panel: bool = s > 1.5 and s < 14.5 and z > height * 0.2 and z < height - 6.0
			if panel and (s < 2.5 or s >= 13.5 or z < height * 0.2 + 1.0 or z >= height - 7.0): return _tone(ink, -0.22)
			if absf(radius_e - 5.4) < 0.55: return GOLD_DARK if p.x < 0.0 else GOLD_DEEP
			if radius_e < 3.9:
				if (p - Vector2(1.1, 0.6)).length() > 3.3: return CYAN if p.x < 0.0 else CYAN_DEEP.lightened(0.2)
				return PURPLE_DEEP
			if radius_e > 6.3 and radius_e < 7.6 and fmod(atan2(p.y, p.x) + TAU, PI / 4.0) < 0.22: return GOLD_DEEP
			if panel: return _tone(ink, -0.08)
		"loculi":
			# Funerary wall: two columns of burial slots; some sealed, some holding a skull.
			for column_l in range(2):
				for course_l in range(3):
					var lo_s: float = 2.0 + column_l * 7.0
					var lo_z: float = 7.0 + course_l * 9.5
					if s < lo_s - 1.0 or s >= lo_s + 6.0 or z < lo_z - 1.0 or z >= lo_z + 6.0: continue
					if s < lo_s or z < lo_z: return CAP if z < lo_z else _tone(CAP, -0.12)
					var kind_l: int = _h(column_l, course_l, seed_value + face * 9) % 3
					if kind_l == 0:
						if absf(s - lo_s - 3.0) < 0.6 and absf(z - lo_z - 3.0) < 0.6: return GOLD_DARK
						return _tone(STONE[2], -0.05) if z > lo_z + 0.8 else _tone(STONE[2], 0.08)
					var skull_l: Vector2 = Vector2((s - lo_s - 3.0) / 1.6, (z - lo_z - 2.2) / 1.4)
					if kind_l == 1 and skull_l.length() < 1.0: return NICHE if absf(skull_l.y) < 0.3 and absf(absf(skull_l.x) - 0.45) < 0.25 else BONE
					return NICHE if z > lo_z + 0.8 else _tone(CAP, 0.04)
		"seep":
			# Damp wall: dark wet streaks from the joints, moss at the foot, slime drips.
			var streak: int = _h(int(s / 3.0), 9, seed_value)
			if streak % 3 == 0 and z < height - 2.0 and z > height - 8.0 - float(streak % 23):
				return ink.lerp(Color("0f2a33"), 0.55)
			if z < 4.0 + float(_h(int(s), 2, seed_value) % 5) and noise % 3 != 0: return MOSS[noise % 3]
			if streak % 3 == 0 and noise % 11 == 0: return Color("1b4a4c")
		"inscription":
			# Band of worn lunar glyphs carved above eye level.
			var band_z: float = height * 0.62
			if absf(z - (band_z + 4.0)) < 0.5 or absf(z - (band_z - 4.0)) < 0.5: return _tone(ink, -0.25)
			if z > band_z - 3.5 and z < band_z + 3.5 and s > 1.0 and s < 15.0:
				var slot: int = int((s - 1.0) / 3.5)
				var local: Vector2 = Vector2(fmod(s - 1.0, 3.5) - 1.75, z - band_z)
				var glyph: int = _h(slot, 4, seed_value + face) % 4
				var carved: bool = false
				match glyph:
					0: carved = _crescent(local.x, local.y, Vector2.ZERO, 1.9)
					1: carved = absf(local.length() - 1.5) < 0.45
					2: carved = absf(local.x) < 0.45 and absf(local.y) < 2.2
					3: carved = absf(local.y - local.x * 1.4) < 0.5 and absf(local.x) < 1.4
				if carved: return CYAN_DEEP.lightened(0.12) if _h(slot, 5, seed_value) % 3 else CYAN_DEEP.darkened(0.2)
				return _tone(ink, -0.06)
	return ink

## Brick under (s, z) for _masonry's layout: (course, brick, height in course, distance
## from the brick's start). x = -1 outside the coursed band (plinth / capstone).
func _brick(s: float, z: float, height: float, seed_value: int) -> Vector4:
	if z < 4.0 or z >= height - 4.0: return Vector4(-1, 0, 0, 0)
	var row: int = int((z - 4.0) / 5.0)
	var pattern: int = _h(row, 3, seed_value) % 4
	var length: float = 16.0 if pattern == 2 else 8.0
	var offset: float = 4.0 if pattern == 1 or pattern == 3 else 0.0
	return Vector4(row, int((s + 16.0 - offset) / length), fmod(z - 4.0, 5.0), fmod(s + 16.0 - offset, length))

func _broken_wall(variant: int) -> Image:
	var image: Image = _blank(32, 48)
	var origin: Vector2 = Vector2(16, 32)
	var blocks: Array = [
		[Vector3(0, 0, 0), Vector3(8, 8, 22)], [Vector3(8, 0, 0), Vector3(16, 8, 15)], [Vector3(0, 8, 0), Vector3(8, 16, 12)],
		[Vector3(9.5, 10, 0), Vector3(14, 14, 4)], [Vector3(12, 8.5, 0), Vector3(15, 11, 2.5)],
	] if variant == 0 else [
		[Vector3(0, 0, 0), Vector3(8, 8, 14)], [Vector3(8, 0, 0), Vector3(16, 8, 21)], [Vector3(0, 8, 0), Vector3(8, 16, 8)],
		[Vector3(8, 8, 0), Vector3(16, 16, 11)], [Vector3(2, 12.5, 0), Vector3(5, 15.5, 2.5)],
	]
	for i in range(blocks.size()):
		var lo: Vector3 = blocks[i][0]
		var hi: Vector3 = blocks[i][1]
		_box(image, origin, lo, hi, func(face: int, u: float, v: float, z: float) -> Color:
			if face == TOP:
				var noise: int = _h(int(u * 2.0), int(v * 2.0), i + variant * 9)
				return Color("394166") if noise % 3 else Color("2a3150")
			var s: float = u if face == LEFT else v
			var ink: Color = _masonry(s, z, 40.0, 70 + i + variant * 5, WALL_L if face == LEFT else WALL_R)
			if z >= hi.z - 1.0: ink = _tone(ink, 0.1)
			if variant == 1 and i == 0 and z < 6.0 and _h(int(s), int(z), 4) % 3 != 0: return MOSS[_h(int(s), int(z), 5) % 3]
			return ink)
	return image

# --- architecture -------------------------------------------------------------------

func _stone(face: int, u: float, v: float, z: float, lit: float, seed_value: int) -> Color:
	var noise: int = _h(int(u * 1.5), int(v * 1.5) + int(z) * 3, seed_value)
	var ink: Color = CAP.lightened(lit) if face == TOP else (WALL_L.lightened(lit + 0.04) if face == LEFT else WALL_R.lightened(lit))
	if noise % 17 == 0: ink = _tone(ink, 0.07)
	elif noise % 11 == 0: ink = _tone(ink, -0.08)
	return ink

func _gold(face: int) -> Color:
	return GOLD_LIGHT if face == TOP else (GOLD if face == LEFT else GOLD_DEEP)

func _pillar(cracked: bool) -> Image:
	var image: Image = _blank(32, 72)
	var origin: Vector2 = Vector2(16, 56)
	_box(image, origin, Vector3(1.5, 1.5, 0), Vector3(14.5, 14.5, 4), func(face: int, u: float, v: float, z: float) -> Color:
		if face != TOP and z >= 3.0: return _tone(_stone(face, u, v, z, 0.04, 1), 0.08)
		return _ao(_stone(face, u, v, z, -0.04, 1), z + 4.0))
	_box(image, origin, Vector3(3, 3, 4), Vector3(13, 13, 7), func(face: int, u: float, v: float, z: float) -> Color:
		if face != TOP and z >= 6.0: return GOLD_DARK if face == LEFT else GOLD_DEEP
		return _stone(face, u, v, z, 0.0, 2))
	_cylinder(image, origin, 8, 8, 4.4, 7, 45, func(face: int, s: float, _t: float, z: float) -> Color:
		var lit: Color = Color("404a78").lerp(Color("1b213d"), pow((s + 1.0) * 0.5, 0.85))
		var flute: float = fmod((asin(clampf(s, -1.0, 1.0)) / PI + 0.5) * 7.0, 1.0)
		if flute < 0.18: lit = _tone(lit, -0.16)
		elif flute < 0.32: lit = _tone(lit, 0.05)
		var x: float = s * 4.4 * sqrt(2.0)
		if _crescent(x, z, Vector2(0, 31), 3.2): return CYAN
		if Vector2(x, z).distance_to(Vector2(0, 31)) < 4.6: lit = lit.lerp(CYAN_DEEP, 0.4)
		if absf(x) < 0.6 and ((z > 15.0 and z < 25.0) or (z > 36.0 and z < 42.0)) and int(z) % 2 == 0: return CYAN_DEEP.lightened(0.25)
		if cracked:
			if z > 12.0 and z < 40.0 and absf(x - (2.2 + sin(z * 0.5) * 1.3)) < 0.55: return CRACK
			if z < 13.0 and _h(int(x * 2.0), int(z), 6) % 3 == 0: return MOSS[_h(int(x), int(z), 8) % 3]
		return _ao(lit, z - 4.0))
	_cylinder(image, origin, 8, 8, 5.4, 45, 47.5, func(face: int, s: float, _t: float, _z: float) -> Color:
		return GOLD_LIGHT if face == TOP else GOLD_LIGHT.lerp(GOLD_DEEP, (s + 1.0) * 0.5))
	_box(image, origin, Vector3(2.5, 2.5, 47.5), Vector3(13.5, 13.5, 51), func(face: int, u: float, v: float, z: float) -> Color:
		return _stone(face, u, v, z, 0.05, 3))
	_box(image, origin, Vector3(1.5, 1.5, 51), Vector3(14.5, 14.5, 54), func(face: int, u: float, v: float, z: float) -> Color:
		if face == TOP:
			if cracked and u + v > 24.0: return Color.TRANSPARENT
			return WALL_TOP.lightened(0.05) if u > 2.5 and v > 2.5 and u < 13.5 and v < 13.5 else RIM
		if z < 52.0: return GOLD_DARK if face == LEFT else GOLD_DEEP
		return _stone(face, u, v, z, 0.08, 4))
	return image

func _door_post() -> Image:
	var image: Image = _blank(32, 80)
	var origin: Vector2 = Vector2(16, 64)
	_box(image, origin, Vector3(1.5, 1.5, 0), Vector3(14.5, 14.5, 5), func(face: int, u: float, v: float, z: float) -> Color:
		if face != TOP and z >= 4.0: return _tone(_stone(face, u, v, z, 0.05, 11), 0.06)
		return _ao(_stone(face, u, v, z, -0.04, 11), z + 4.0))
	_box(image, origin, Vector3(3, 3, 5), Vector3(13, 13, 50), func(face: int, u: float, v: float, z: float) -> Color:
		if face == TOP: return WALL_TOP
		var s: float = (u if face == LEFT else v) - 3.0
		var course: int = int((z - 5.0) / 6.0)
		if fmod(z - 5.0, 6.0) < 1.0 or (course % 2 == 0 and absf(s - 5.0) < 0.5): return MORTAR
		if absf(s - 5.0) < 0.7 and z > 12.0 and z < 44.0:
			if int(z) % 4 == 0: return CYAN_GLOW
			return CYAN if int(z) % 2 == 0 else CYAN_DEEP
		var ink: Color = _tone(WALL_L if face == LEFT else WALL_R, TONES[_h(course, 5, face) % TONES.size()] + 0.03)
		if absf(s - 5.0) < 2.2 and z > 10.0 and z < 46.0: ink = ink.lerp(CYAN_DEEP, 0.3)
		return _ao(ink, z))
	_box(image, origin, Vector3(2, 2, 50), Vector3(14, 14, 53), func(face: int, _u: float, _v: float, _z: float) -> Color: return _gold(face))
	_box(image, origin, Vector3(1.5, 1.5, 53), Vector3(14.5, 14.5, 57), func(face: int, u: float, v: float, z: float) -> Color:
		if face == TOP: return WALL_TOP.lightened(0.05) if u > 2.5 and v > 2.5 and u < 13.5 and v < 13.5 else RIM
		return _stone(face, u, v, z, 0.08, 12))
	_box(image, origin, Vector3(6, 6, 57), Vector3(10, 10, 60), func(face: int, _u: float, _v: float, _z: float) -> Color: return _gold(face))
	return image

## Beam resting on two door posts, spanning one passage cell. along_x: the beam runs
## along the grid x axis (passage crossed along y). keystone: crescent on the long face.
func _lintel(along_x: bool, keystone: bool) -> Image:
	var image: Image = _blank(32, 74)
	var origin: Vector2 = Vector2(16, 58)
	var lo: Vector3 = Vector3(0, 4.5, 49) if along_x else Vector3(4.5, 0, 49)
	var hi: Vector3 = Vector3(16, 11.5, 56) if along_x else Vector3(11.5, 16, 56)
	_box(image, origin, lo, hi, func(face: int, u: float, v: float, z: float) -> Color:
		if face == TOP:
			var across: float = (v - lo.y) if along_x else (u - lo.x)
			return RIM.darkened(0.2) if across < 1.0 or across >= 6.0 else WALL_TOP.lightened(0.04)
		var long_face: bool = (face == LEFT) == along_x
		var s: float = u if face == LEFT else v
		if z < 50.0: return GOLD_DARK if face == LEFT else GOLD_DEEP
		if z >= 55.0: return _tone(WALL_L if face == LEFT else WALL_R, 0.16)
		if long_face and keystone:
			if _crescent(s, z, Vector2(8, 52.5), 2.4): return CYAN
			if s >= 5.0 and s < 11.0: return (GOLD_DEEP if s < 6.0 or s >= 10.0 else Color("2a2f52"))
		if long_face and fmod(s + 4.0, 8.0) < 1.0: return MORTAR
		return _tone(WALL_L if face == LEFT else WALL_R, 0.05 + TONES[_h(int((s + 4.0) / 8.0), int(along_x), 21) % TONES.size()]))
	if keystone:
		# Gilded crescent standing on the keystone: the arch reads as a gate, not a beam.
		var top: Vector2 = origin + Vector2(0, 8 - 56)
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var p: Vector2 = Vector2(x + 0.5, y + 0.5) - (top + Vector2(0, -5))
				if _crescent(p.x, p.y, Vector2.ZERO, 4.2): _ink(image, x, y, GOLD if p.x < 0.0 else GOLD_DARK)
				elif absf(p.x) < 1.0 and p.y > 3.0 and p.y < 5.5: _ink(image, x, y, GOLD_DEEP)
	return image

# --- props ----------------------------------------------------------------------------

func _sarcophagus() -> Image:
	var image: Image = _blank(32, 32)
	var origin: Vector2 = Vector2(16, 16)
	_box(image, origin, Vector3(1, 3.5, 0), Vector3(15, 12.5, 9), func(face: int, u: float, v: float, z: float) -> Color:
		var s: float = u if face == LEFT else v
		var low: float = 1.0 if face == LEFT else 3.5
		var high: float = 15.0 if face == LEFT else 12.5
		var ink: Color = Color("3a4264") if face == LEFT else Color("283050")
		if z >= 8.0: return GOLD_DARK if face == LEFT else GOLD_DEEP
		if z < 1.5: return _tone(ink, -0.25)
		if s > low + 1.5 and s < high - 1.5 and z > 2.5 and z < 7.0:
			if (s < low + 2.5 or s > high - 2.5) and (z < 3.5 or z > 6.0): return GOLD_DARK
			return _tone(ink, -0.12)
		return ink)
	_box(image, origin, Vector3(0.5, 3, 9), Vector3(15.5, 13, 12), func(face: int, u: float, v: float, z: float) -> Color:
		if face != TOP:
			return (Color("454e76") if face == LEFT else Color("30385a")) if z >= 9.8 else GOLD_DEEP
		var point: Vector2 = Vector2(u, v)
		if point.distance_to(Vector2(3.4, 8)) < 1.8: return Color("5a6390")
		if point.distance_to(Vector2(1.7, 8)) < 0.8: return GOLD
		if u > 5.0 and u < 13.5 and absf(v - 8.0) < 2.2 - (u - 5.0) * 0.08:
			if absf(u - 8.5) < 0.6 or absf(v - 8.0) < 0.35 and u > 10.0: return Color("39416a")
			return Color("515a86")
		if u < 1.4 or u > 14.6 or v < 3.9 or v > 12.1: return GOLD_DARK
		return Color("444d73"))
	return image

func _chest(open: bool) -> Image:
	var image: Image = _blank(32, 32)
	var origin: Vector2 = Vector2(16, 16)
	var body := func(face: int, u: float, v: float, z: float) -> Color:
		if face == TOP:
			if not open: return WOOD
			var point_t: Vector2 = Vector2(u, v)
			if _h(int(u * 2.0), int(v * 2.0), 77) % 5 == 0: return GOLD_LIGHT if point_t.distance_to(Vector2(8, 8)) < 3.0 else GOLD_DARK
			if point_t.distance_to(Vector2(8, 8)) < 2.4: return CYAN_GLOW
			return Color("0d0a16").lerp(CYAN_DEEP, clampf(1.0 - point_t.distance_to(Vector2(8, 8)) / 5.0, 0.0, 1.0))
		var s: float = u if face == LEFT else v
		var low: float = 3.0 if face == LEFT else 4.5
		var high: float = 13.0 if face == LEFT else 11.5
		var ink: Color = WOOD if face == LEFT else WOOD.darkened(0.3)
		if s < low + 0.8 or s >= high - 0.8: return GOLD if face == LEFT else GOLD_DARK
		if absf(s - (low + (high - low) * 0.3)) < 0.5 or absf(s - (low + (high - low) * 0.7)) < 0.5: return GOLD_DARK if face == LEFT else GOLD_DEEP
		if face == LEFT and absf(s - 8.0) < 1.3 and z >= 3.0 and z < 6.5:
			return CYAN if absf(s - 8.0) < 0.5 and z >= 4.0 and z < 5.5 else GOLD
		if int(z) % 3 == 0: ink = _tone(ink, -0.08)
		return _ao(ink, z + 6.0)
	if open:
		_box(image, origin, Vector3(2.5, 2.5, 7), Vector3(13.5, 4, 17), func(face: int, u: float, _v: float, z: float) -> Color:
			if face == TOP: return GOLD_DARK
			if face == LEFT and (u < 3.3 or u > 12.7 or z > 16.0 or z < 7.8): return GOLD_DARK
			return WOOD.darkened(0.2) if face == LEFT else GOLD_DEEP)
	_box(image, origin, Vector3(3, 4.5, 0), Vector3(13, 11.5, 7), body)
	if not open:
		_box(image, origin, Vector3(2.5, 4, 7), Vector3(13.5, 12, 10.5), func(face: int, u: float, v: float, z: float) -> Color:
			if face == TOP:
				if u < 3.3 or u > 12.7 or v < 4.8 or v > 11.2: return GOLD
				if Vector2(u, v).distance_to(Vector2(8, 8)) < 1.6: return GOLD_LIGHT
				return WOOD.lightened(0.12) if int(u) % 3 else WOOD
			if z < 7.8: return GOLD if face == LEFT else GOLD_DARK
			return WOOD.lightened(0.05) if face == LEFT else WOOD.darkened(0.25))
	return image

func _pedestal() -> Image:
	var image: Image = _blank(32, 44)
	var origin: Vector2 = Vector2(16, 28)
	_box(image, origin, Vector3(2, 2, 0), Vector3(14, 14, 3), func(face: int, u: float, v: float, z: float) -> Color:
		return _ao(_stone(face, u, v, z, 0.0, 31), z + 6.0))
	_box(image, origin, Vector3(4.5, 4.5, 3), Vector3(11.5, 11.5, 16), func(face: int, u: float, v: float, z: float) -> Color:
		if face == TOP: return CAP
		var s: float = u if face == LEFT else v
		if absf(s - 8.0) < 0.6 and z > 5.0 and z < 14.0: return CYAN if int(z) % 2 == 0 else CYAN_DEEP
		return _stone(face, u, v, z, 0.03, 32))
	_box(image, origin, Vector3(3, 3, 16), Vector3(13, 13, 19), func(face: int, u: float, v: float, z: float) -> Color:
		if face != TOP and z < 17.0: return GOLD_DARK if face == LEFT else GOLD_DEEP
		return _stone(face, u, v, z, 0.06, 33))
	# Floating lunar orb above the plinth.
	var center: Vector2 = origin + Vector2(0, 8) - Vector2(0, 25)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var offset: Vector2 = Vector2(x + 0.5, y + 0.5) - center
			if offset.length() < 3.6:
				var light: float = clampf(1.0 - (offset + Vector2(1.2, 1.2)).length() / 4.5, 0.0, 1.0)
				_ink(image, x, y, CYAN_DEEP.lerp(CYAN, light).lerp(CYAN_GLOW, maxf(0.0, light - 0.55) * 2.0))
	return image

func _candles() -> Image:
	var image: Image = _blank(16, 14)
	for y in range(10, 14):
		for x in range(2, 15):
			if Vector2((x + 0.5 - 8.5) / 6.0, (y + 0.5 - 12.0) / 1.6).length() < 1.0: _ink(image, x, y, Color(BONE_DARK, 0.85))
	for candle in [[4, 4], [8, 7], [12, 3]]:
		var cx: int = candle[0]
		var tall: int = candle[1]
		for y in range(12 - tall, 12):
			_ink(image, cx, y, BONE)
			_ink(image, cx + 1, y, BONE_DARK)
		_ink(image, cx, 11 - tall, IRON)
		_ink(image, cx, 10 - tall, CYAN)
		_ink(image, cx, 9 - tall, CYAN_GLOW)
	return image

# --- rock mass ------------------------------------------------------------------------
## The solid rock the catacombs are carved into. 20 columns of 32x56 (base diamond
## centre 8 px above the bottom): ROCK_HEIGHTS (0, 12, 20, 28, 40 px) x 4 variants.
## iso_world.gd picks the tallest height that never covers floor or walls behind it.
func _rock_atlas() -> Image:
	var image: Image = _blank(ROCK_HEIGHTS.size() * 4 * 32, 56)
	for level in range(ROCK_HEIGHTS.size()):
		for variant in range(4):
			var cell: Image = _blank(32, 56)
			var height: float = float(ROCK_HEIGHTS[level])
			var seed_value: int = variant * 17 + level * 3
			_box(cell, Vector2(16, 40), Vector3(0, 0, 0), Vector3(16, 16, height), func(face: int, u: float, v: float, z: float) -> Color:
				return _rock(face, u, v, z, height, seed_value))
			image.blit_rect(cell, Rect2i(0, 0, 32, 56), Vector2i((level * 4 + variant) * 32, 0))
	return image

func _rock(face: int, u: float, v: float, z: float, height: float, seed_value: int) -> Color:
	if face == TOP:
		var ground: bool = height <= 0.0
		var ink: Color = Color("10141f") if ground else Color("171c2c")
		ink = _tone(ink, sin(u * 0.45 + seed_value) * cos(v * 0.5 + seed_value * 0.3) * 0.05)
		var crack_a: float = absf(v - (4.0 + u * 0.45 + sin(u * 0.9 + seed_value) * 1.4))
		var crack_b: float = absf(u - (10.0 + sin(v * 0.8 + seed_value * 2.0) * 1.5 - v * 0.25))
		if crack_a < 0.5 or (crack_b < 0.45 and v > 3.0): return Color("0a0d16")
		if crack_a < 1.3 and v > 4.0 + u * 0.45: return _tone(ink, 0.05)
		var noise: int = _h(int(u * 1.3), int(v * 1.3), seed_value)
		if noise % 19 == 0: return Color("262d45") if not ground else Color("1d2335")
		if noise % 23 == 1: return Color("2f3756") if not ground else Color("202638")
		if noise % 9 == 0: return _tone(ink, -0.12)
		if seed_value % 4 == 3 and noise % 13 == 2: return MOSS[0].darkened(0.3)
		return ink
	var s: float = u if face == LEFT else v
	var base: Color = Color("232a44") if face == LEFT else Color("171d33")
	var strata: float = z + sin(s * 0.7 + seed_value) * 1.3
	var band: int = int(strata / 5.0)
	var ink: Color = _tone(base, TONES[_h(band, seed_value, face) % TONES.size()])
	if fmod(strata + 50.0, 5.0) < 0.9: ink = _tone(ink, -0.25)
	if absf(s - float(3 + seed_value % 9)) < 0.5 and _h(band, 7, seed_value) % 3 == 0: ink = Color("0b0e18")
	if z >= height - 1.0: ink = _tone(base, 0.14)
	return ink.darkened(0.35 * clampf(1.0 - z / 18.0, 0.0, 1.0))

# --- ruins and decor props --------------------------------------------------------------

## Snapped column stump with a fallen drum at its foot.
func _pillar_stump() -> Image:
	var image: Image = _blank(32, 48)
	var origin: Vector2 = Vector2(16, 32)
	_box(image, origin, Vector3(1.5, 1.5, 0), Vector3(14.5, 14.5, 4), func(face: int, u: float, v: float, z: float) -> Color:
		return _ao(_stone(face, u, v, z, -0.04, 41), z + 4.0))
	_box(image, origin, Vector3(3, 3, 4), Vector3(13, 13, 7), func(face: int, u: float, v: float, z: float) -> Color:
		if face != TOP and z >= 6.0: return GOLD_DEEP
		return _stone(face, u, v, z, 0.0, 42))
	var shaft := func(face: int, s: float, _t: float, z: float) -> Color:
		if face == TOP: return Color("343c60") if _h(int(s * 8.0), int(_t * 8.0), 3) % 3 else Color("252c48")
		var lit: Color = Color("3c4672").lerp(Color("1b213d"), pow((s + 1.0) * 0.5, 0.85))
		if fmod((asin(clampf(s, -1.0, 1.0)) / PI + 0.5) * 7.0, 1.0) < 0.18: lit = _tone(lit, -0.16)
		if z < 12.0 and _h(int(s * 6.0), int(z), 43) % 3 == 0: return MOSS[_h(int(s * 4.0), int(z), 44) % 3]
		return _ao(lit, z - 4.0)
	_cylinder(image, origin, 8, 8, 4.4, 7, 19, shaft)
	_cylinder(image, origin, 7, 9, 3.0, 19, 24, shaft)
	_box(image, origin, Vector3(10, 11.5, 0), Vector3(15.5, 15.5, 4), func(face: int, u: float, v: float, z: float) -> Color:
		if face == TOP: return Color("39416a") if fmod(v, 1.6) > 0.35 else Color("262d4a")
		return _stone(face, u, v, z, -0.02, 45))
	return image

## A column lying on the floor (along the grid x axis), fluted, mossy at the ends.
func _fallen_column() -> Image:
	var image: Image = _blank(32, 32)
	_box(image, Vector2(16, 16), Vector3(0.5, 4.5, 0), Vector3(15.5, 11.5, 7), func(face: int, u: float, v: float, z: float) -> Color:
		if face == TOP:
			var curve: float = 1.0 - absf(v - 6.5) / 5.0
			var ink: Color = Color("1e2440").lerp(Color("444e7c"), clampf(curve, 0.0, 1.0))
			if fmod(v, 1.75) < 0.35: ink = _tone(ink, -0.15)
			if (u < 2.5 or u > 13.5) and _h(int(u * 2.0), int(v * 2.0), 51) % 3 == 0: return MOSS[1]
			return ink
		if face == RIGHT:
			var ring: float = Vector2(v - 8.0, z - 3.5).length()
			if ring > 4.6: return Color.TRANSPARENT
			return Color("3a4369") if absf(ring - 2.5) > 0.5 else Color("262d4a")
		return _ao(Color("1b2138"), z + 2.0))
	return image

func _urns() -> Image:
	var image: Image = _blank(32, 32)
	var origin: Vector2 = Vector2(16, 16)
	for urn in [[5.5, 8.5, 2.7, 8.0], [10.5, 6.0, 2.2, 6.0]]:
		var cu: float = urn[0]
		var cv: float = urn[1]
		var radius: float = urn[2]
		var tall: float = urn[3]
		var clay := func(face: int, s: float, _t: float, z: float) -> Color:
			if face == TOP: return Color("0d0a16")
			var ink: Color = Color("57476f").lerp(Color("241c33"), pow((s + 1.0) * 0.5, 0.8))
			if absf(z - tall * 0.55) < 0.7: return GOLD_DARK if s < 0.2 else GOLD_DEEP
			return _ao(ink, z + 3.0)
		_cylinder(image, origin, cu, cv, radius, 0, tall, clay)
		_cylinder(image, origin, cu, cv, radius * 0.62, tall, tall + 1.5, clay)
		_cylinder(image, origin, cu, cv, radius * 0.8, tall + 1.5, tall + 2.5, func(face: int, s: float, _t: float, _z: float) -> Color:
			return Color("120e1c") if face == TOP and absf(s) < 0.6 else Color("6a5a86").lerp(Color("2d2440"), (s + 1.0) * 0.5))
	return image

func _bone_pile() -> Image:
	var image: Image = _blank(32, 28)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var mound: Vector2 = Vector2((x + 0.5 - 16.0) / 12.0, (y + 0.5 - 21.0) / 5.5)
			if mound.length() < 1.0: _ink(image, x, y, Color(0.07, 0.07, 0.1, 0.85))
	for i in range(16):
		var a: Vector2 = Vector2(6 + _h(i, 1, 61) % 20, 13 + _h(i, 2, 61) % 10)
		var angle: float = float(_h(i, 3, 61) % 628) / 100.0
		var length: float = 3.0 + float(_h(i, 4, 61) % 3)
		for step in range(int(length * 2.0) + 1):
			var p: Vector2 = a + Vector2.from_angle(angle) * (step * 0.5)
			_ink(image, int(p.x), int(p.y), BONE if (step + i) % 5 else BONE.lightened(0.15))
		_ink(image, int(a.x), int(a.y) + 1, BONE_DARK)
	for skull in [Vector2(12, 13), Vector2(19.5, 15)]:
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var p: Vector2 = Vector2(x + 0.5, y + 0.5) - skull
				if p.length() < 2.4:
					var eye: bool = (p - Vector2(-0.9, 0.2)).length() < 0.6 or (p - Vector2(0.9, 0.2)).length() < 0.6
					_ink(image, x, y, NICHE if eye else (BONE.lightened(0.1) if p.y < -0.5 else BONE))
	return image

# --- stage 4: ruined arches and the abyss -------------------------------------------------

## Half of a broken lintel, still keyed into the post on one side. `far_side` = the
## stub hangs from the post at the high end of the axis (u or v = 16).
func _lintel_stub(along_x: bool, far_side: bool) -> Image:
	var image: Image = _blank(32, 74)
	var origin: Vector2 = Vector2(16, 58)
	var reach: float = 8.5
	var a: float = 16.0 - reach if far_side else 0.0
	var b: float = 16.0 if far_side else reach
	var lo: Vector3 = Vector3(a, 4.5, 49) if along_x else Vector3(4.5, a, 49)
	var hi: Vector3 = Vector3(b, 11.5, 56) if along_x else Vector3(11.5, b, 56)
	var broken_end: float = a if far_side else b
	_box(image, origin, lo, hi, func(face: int, u: float, v: float, z: float) -> Color:
		var along: float = u if along_x else v
		var from_break: float = absf(along - broken_end)
		var noise: int = _h(int(u * 2.0), int(v * 2.0) + int(z) * 5, 91)
		# Jagged fracture: the last two cells of the beam crumble away irregularly.
		if from_break < 1.6 + sin(z * 1.9 + along) * 1.1 and noise % 3 == 0: return Color.TRANSPARENT
		if face == TOP: return RIM.darkened(0.2) if noise % 4 == 0 else WALL_TOP.lightened(0.03)
		var end_face: bool = (face == RIGHT and along_x and not far_side) or (face == LEFT and not along_x and not far_side)
		if end_face: return Color("2b3150") if noise % 3 else Color("1a1f36")
		if z < 50.0: return GOLD_DARK if face == LEFT else GOLD_DEEP
		if from_break < 3.0 and noise % 2 == 0: return CRACK
		return _tone(WALL_L if face == LEFT else WALL_R, 0.05 + TONES[_h(int(along / 8.0), int(along_x), 21) % TONES.size()]))
	return image

## Cliff strata for the faces of the abyss terraces (iso_abyss.gd maps these strips on
## the hanging faces). 4 strips x 16 px: 0-1 lit (+y) face, 2-3 shaded (+x) face; 128 px
## tall, z grows downward from the terrace lip.
func _abyss_faces() -> Image:
	var image: Image = _blank(64, 128)
	for strip in range(4):
		var lit: bool = strip < 2
		var base: Color = Color("222842") if lit else Color("151a30")
		for z in range(128):
			for s in range(16):
				var strata: float = float(z) + sin(s * 0.6 + strip * 2.1) * 1.6 + sin(s * 0.21 + strip) * 2.5
				var band: int = int(strata / 6.0)
				var ink: Color = _tone(base, TONES[_h(band, strip, 5) % TONES.size()])
				if fmod(strata + 60.0, 6.0) < 1.0: ink = _tone(ink, -0.28)
				# Vertical fissures that run through a few bands.
				var fissure: int = _h(int(s / 4), band / 3, strip + 11)
				if fissure % 5 == 0 and s % 4 == 1: ink = Color("090b14")
				var noise: int = _h(s, z, strip * 7 + 3)
				if noise % 31 == 0: ink = _tone(ink, 0.1)
				elif noise % 17 == 0: ink = _tone(ink, -0.1)
				if z == 0: ink = _tone(base, 0.22)
				elif z == 1: ink = _tone(base, 0.08)
				# Falling into darkness: the faces fade well before their bottom.
				ink = ink.darkened(clampf(float(z) / 96.0, 0.0, 1.0) * 0.75)
				image.set_pixel(strip * 16 + s, z, ink)
	return image
