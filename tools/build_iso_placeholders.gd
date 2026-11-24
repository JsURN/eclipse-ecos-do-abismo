extends SceneTree
## Generates the clearly-labelled isometric PLACEHOLDER art used by the prototype.
## Run:  godot --headless --path . --script tools/build_iso_placeholders.gd
## then: godot --headless --path . --editor --quit   (imports the PNGs)
##
## Conventions every replacement asset must keep (see docs/ISOMETRIC_PROTOTYPE.md):
## - 2:1 diamonds, one logical cell = 32x16 px on screen.
## - Floor atlas: 32x32 regions, ground diamond occupies the BOTTOM 16 rows.
## - Blocks: 32 px wide, base diamond occupies the bottom 16 rows; height grows upward.
const OUT: String = "res://assets/isometric/placeholders/"

const STONE: Color = Color("2b3250")
const STONE_ALT: Color = Color("283049")
const JOINT: Color = Color("171c30")
const STONE_LIGHT: Color = Color("39426a")
const CRACK: Color = Color("10142a")
const MOSS: Color = Color("2f4d4a")
const MOSS_LIGHT: Color = Color("3c6359")
const CYAN: Color = Color("65dddb")
const CYAN_GLOW: Color = Color("b7f6ee")
const CYAN_DEEP: Color = Color("285779")
const GOLD: Color = Color("c4a66b")
const GOLD_DARK: Color = Color("9d855c")
const PURPLE: Color = Color("59426c")
const PURPLE_LIGHT: Color = Color("b995d0")
const VOID: Color = Color("0b0e1a")
const WALL_LEFT: Color = Color("2a3354")
const WALL_RIGHT: Color = Color("1e2541")
const WALL_TOP: Color = Color("151a2c")
const WALL_RIM: Color = Color("3e4a72")
const MORTAR: Color = Color("10142a")

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var results: Array[Error] = []
	results.append(_save(_floor_atlas(), "placeholder_floor_atlas.png"))
	results.append(_save(_wall(40, false), "placeholder_wall_full.png"))
	results.append(_save(_wall(12, false), "placeholder_wall_low.png"))
	results.append(_save(_wall(20, true), "placeholder_wall_broken.png"))
	results.append(_save(_pillar(), "placeholder_pillar.png"))
	results.append(_save(_door_post(), "placeholder_door_post.png"))
	results.append(_save(_sarcophagus(), "placeholder_sarcophagus.png"))
	results.append(_save(_chest(false), "placeholder_chest_closed.png"))
	results.append(_save(_chest(true), "placeholder_chest_open.png"))
	var failed: bool = results.any(func(e: Error) -> bool: return e != OK)
	print("Isometric placeholders written to ", OUT, "; failed=", failed)
	quit(1 if failed else 0)

func _save(image: Image, file: String) -> Error:
	return image.save_png(ProjectSettings.globalize_path(OUT + file))

# --- primitives -------------------------------------------------------------

static func _hash(x: int, y: int, seed_value: int) -> int:
	return ((x * 73856093) ^ (y * 19349663) ^ (seed_value * 83492791)) & 0x7fffffff

static func _put(image: Image, x: int, y: int, ink: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, ink)

## Iso-local slab coordinates of a pixel relative to a diamond whose TOP vertex is `apex`.
## Returns (u, v) in 0..2*hh along the two grid axes, or (-1,-1) when outside.
static func _diamond_uv(fx: float, fy: float, apex: Vector2, hw: float) -> Vector2:
	var dx: float = (fx - apex.x) * (16.0 / hw)
	var dy: float = (fy - apex.y) * (16.0 / hw)
	var u: float = dy + dx * 0.5
	var v: float = dy - dx * 0.5
	if u < 0.0 or v < 0.0 or u >= 16.0 or v >= 16.0: return Vector2(-1, -1)
	return Vector2(u, v)

## Draws a right prism (iso box). `base` is the centre of the bottom diamond.
## Faces get brick courses; `bricks` = 0 disables them.
static func _prism(image: Image, base: Vector2, hw: float, height: float, top: Color, left: Color, right: Color, bricks: int = 8, rim: Color = WALL_RIM) -> void:
	var hh: float = hw * 0.5
	var top_center: Vector2 = base - Vector2(0, height)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var fx: float = x + 0.5
			var fy: float = y + 0.5
			var ink: Color = Color.TRANSPARENT
			var edge: float = absf(fx - top_center.x) / hw + absf(fy - top_center.y) / hh
			if edge <= 1.0:
				ink = top
				if edge > 0.82: ink = rim
				elif _hash(x, y, 3) % 23 == 0: ink = top.lightened(0.08)
			elif fx >= base.x - hw and fx < base.x:
				var top_edge: float = top_center.y + (fx - base.x + hw) * hh / hw
				var v: float = fy - top_edge
				if v >= 0.0 and v < height:
					ink = left.darkened(0.28 * v / maxf(1.0, height))
					if bricks > 0:
						var course: int = int(v) / (bricks / 2 + 2)
						var u: int = int(fx - base.x + hw + (course % 2) * 4)
						if int(v) % (bricks / 2 + 2) == bricks / 2 + 1 or u % bricks == 0: ink = MORTAR
					if v < 1.0: ink = rim
					if fx >= base.x - 1.0: ink = rim.darkened(0.1)
			elif fx >= base.x and fx < base.x + hw:
				var top_edge_r: float = top_center.y + hh - (fx - base.x) * hh / hw
				var v_r: float = fy - top_edge_r
				if v_r >= 0.0 and v_r < height:
					ink = right.darkened(0.28 * v_r / maxf(1.0, height))
					if bricks > 0:
						var course_r: int = int(v_r) / (bricks / 2 + 2)
						var u_r: int = int(fx - base.x + (course_r % 2) * 4)
						if int(v_r) % (bricks / 2 + 2) == bricks / 2 + 1 or u_r % bricks == 0: ink = MORTAR
					if v_r < 1.0: ink = rim.darkened(0.25)
			if ink.a > 0.0: image.set_pixel(x, y, ink)

# --- floor ------------------------------------------------------------------
## Atlas columns (32x32 each): 0 stone A, 1 stone B, 2 cracked, 3 moss, 4 rune,
## 5 void, 6 dais block, 7 dais moon seal, 8 stairs, 9 void B.
func _floor_atlas() -> Image:
	var image: Image = Image.create(320, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for column in range(10):
		var cell: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		cell.fill(Color.TRANSPARENT)
		match column:
			0, 1, 2, 3, 4: _slab(cell, Vector2(16, 16), column, 0)
			5, 9: _void(cell, column)
			6, 7:
				_prism(cell, Vector2(16, 24), 16, 6, STONE, WALL_LEFT, WALL_RIGHT, 0, GOLD_DARK)
				_slab(cell, Vector2(16, 10), 7 if column == 7 else 1, 1)
			8:
				_prism(cell, Vector2(16, 24), 16, 3, STONE, WALL_LEFT, WALL_RIGHT, 0)
				_slab(cell, Vector2(16, 13), 8, 2)
		image.blit_rect(cell, Rect2i(0, 0, 32, 32), Vector2i(column * 32, 0))
	return image

func _slab(image: Image, apex: Vector2, style: int, seed_value: int) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var uv: Vector2 = _diamond_uv(x + 0.5, y + 0.5, apex, 16.0)
			if uv.x < 0.0: continue
			var noise: int = _hash(x, y, style * 7 + seed_value)
			var ink: Color = STONE if (int(uv.x) / 8 + int(uv.y) / 8) % 2 == 0 else STONE_ALT
			if style == 1: ink = STONE_ALT.lightened(0.03)
			if noise % 17 == 0: ink = ink.lightened(0.1)
			elif noise % 13 == 0: ink = ink.darkened(0.15)
			var joint: bool = uv.x < 1.0 or uv.y < 1.0 or absf(uv.x - 8.0) < 0.5 or absf(uv.y - 8.0) < 0.5
			if joint: ink = JOINT
			elif uv.x < 2.0 or uv.y < 2.0: ink = ink.lightened(0.06)
			if style == 2 and (absf(uv.y - (4.0 + uv.x * 0.45 + sin(uv.x * 1.7) * 1.2)) < 0.6): ink = CRACK
			if style == 3 and noise % 5 == 0 and (Vector2(uv.x, uv.y) - Vector2(11, 5)).length() < 5.0: ink = MOSS if noise % 3 else MOSS_LIGHT
			if style == 4 or style == 7:
				var radius: float = (uv - Vector2(8, 8)).length()
				var ring: float = 5.5 if style == 4 else 6.5
				if absf(radius - ring) < 0.65: ink = CYAN if style == 4 else GOLD
				elif style == 4 and (uv - Vector2(9.5, 7)).length() < 3.0 and (uv - Vector2(7.5, 7.5)).length() > 2.6: ink = CYAN_GLOW
				elif style == 7 and (uv - Vector2(9, 7.5)).length() < 4.0 and (uv - Vector2(6.8, 7.8)).length() > 3.6: ink = CYAN
				elif style == 7 and absf(radius - ring) < 1.4: ink = CYAN_DEEP
			if style == 8 and (int(uv.x) % 5 == 0): ink = JOINT
			image.set_pixel(x, y, ink)

func _void(image: Image, seed_value: int) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if _diamond_uv(x + 0.5, y + 0.5, Vector2(16, 16), 16.0).x < 0.0: continue
			var ink: Color = VOID
			var noise: int = _hash(x, y, seed_value)
			if noise % 29 == 0: ink = Color("121829")
			elif noise % 41 == 0: ink = Color("0f1222")
			image.set_pixel(x, y, ink)

# --- blocks -----------------------------------------------------------------

func _wall(height: int, broken: bool) -> Image:
	var image: Image = Image.create(32, 16 + height + (8 if broken else 0), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var base: Vector2 = Vector2(16, image.get_height() - 8)
	_prism(image, base, 16, height, WALL_TOP, WALL_LEFT, WALL_RIGHT)
	if broken:
		# Fallen masonry on top of the stump keeps the silhouette irregular.
		_prism(image, base - Vector2(5, height - 1), 6, 5, WALL_TOP, WALL_LEFT, WALL_RIGHT, 0)
		_prism(image, base - Vector2(-6, height + 1), 5, 7, WALL_TOP, WALL_LEFT, WALL_RIGHT, 0)
		for i in range(10):
			var at: Vector2i = Vector2i(4 + _hash(i, 1, 9) % 24, image.get_height() - 18 - _hash(i, 2, 9) % 10)
			_put(image, at.x, at.y, CRACK)
	else:
		# Lunar rune course on the lit face.
		for i in range(5):
			_put(image, 5 + i * 2, int(image.get_height() - 8 - height * 0.55 + i), CYAN_DEEP)
	return image

func _pillar() -> Image:
	var image: Image = Image.create(32, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var base: Vector2 = Vector2(16, 56)
	_prism(image, base, 11, 5, WALL_TOP, WALL_LEFT, WALL_RIGHT, 0)
	_prism(image, base - Vector2(0, 5), 7, 38, STONE, WALL_LEFT.lightened(0.05), WALL_RIGHT, 0)
	_prism(image, base - Vector2(0, 43), 10, 5, GOLD_DARK, GOLD_DARK, GOLD_DARK.darkened(0.35), 0, GOLD)
	for y in range(20, 44, 3): _put(image, 12, y, CYAN)
	_put(image, 12, 18, CYAN_GLOW)
	return image

func _door_post() -> Image:
	var image: Image = Image.create(32, 72, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var base: Vector2 = Vector2(16, 64)
	_prism(image, base, 12, 6, WALL_TOP, WALL_LEFT, WALL_RIGHT, 0)
	_prism(image, base - Vector2(0, 6), 9, 50, WALL_TOP, WALL_LEFT, WALL_RIGHT, 6)
	_prism(image, base - Vector2(0, 56), 12, 4, GOLD_DARK, GOLD_DARK, GOLD_DARK.darkened(0.35), 0, GOLD)
	for y in range(22, 50, 4):
		_put(image, 11, y, CYAN)
		_put(image, 11, y + 1, CYAN_DEEP)
	return image

func _sarcophagus() -> Image:
	var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var base: Vector2 = Vector2(16, 24)
	_prism(image, base, 14, 10, STONE_LIGHT, Color("333b5c"), Color("262d4a"), 0)
	_prism(image, base - Vector2(0, 10), 15, 3, Color("3a4366"), Color("2f3757"), Color("232a45"), 0, GOLD_DARK)
	for i in range(4): _put(image, 15 + i, 8 + (i % 2), GOLD)
	return image

func _chest(open: bool) -> Image:
	var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var base: Vector2 = Vector2(16, 24)
	_prism(image, base, 11, 9, Color("0d0a16") if open else Color("4a3868"), Color("3b2d55"), Color("2c2142"), 0, GOLD)
	for x in range(5, 27):
		var left: bool = x < 16
		var top_edge: float = (base.y - 9) + ((x + 0.5 - base.x + 11) * 0.5 if left else 5.5 - (x + 0.5 - base.x) * 0.5)
		_put(image, x, int(top_edge + 4), GOLD_DARK)
	if open:
		for i in range(6): _put(image, 13 + i, 14 + i % 2, CYAN_GLOW if i % 2 else CYAN)
	else:
		_put(image, 16, 21, GOLD)
		_put(image, 16, 22, GOLD_DARK)
	return image
