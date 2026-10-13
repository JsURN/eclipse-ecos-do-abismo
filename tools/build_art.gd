extends SceneTree
## Original, deterministic pixel assets. The baked PNGs are the runtime assets.
const COLORS: Dictionary = {
	"void": "090e19", "seam": "182231", "stone": "263244", "edge": "3e5065",
	"light": "657c91", "bone": "b5c1cd", "white": "e2edf1", "blue": "285779",
	"purple": "735585", "cyan": "79dedc", "ice": "c4f4ed", "gold": "c4a66b",
	"rust": "795f68", "moss": "3c5752", "dark": "101725", "blood": "cf7794",
	"hair": "afc5d8", "skin": "ba999b", "cape": "286185", "cape_light": "4d94b1"
}
var img: Image
var offset: Vector2i = Vector2i.ZERO

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets")
	_tiles()
	for kind in ["kael", "crawler", "archer", "guardian"]: _actor(kind)
	_environment()
	_props()
	print("ART: 64 tiles, four 6-frame/6-state actors, environment and props baked")
	quit()

func _canvas(w: int, h: int) -> void:
	img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

func _rect(x: int, y: int, w: int, h: int, ink: String) -> void:
	if w <= 0 or h <= 0: return
	img.fill_rect(Rect2i(offset + Vector2i(x, y), Vector2i(w, h)), Color(String(COLORS.get(ink, ink))))

func _line(a: Vector2i, b: Vector2i, ink: String) -> void:
	var steps: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
	for n in range(steps + 1):
		var p: Vector2i = Vector2i(Vector2(a).lerp(Vector2(b), float(n) / float(maxi(1, steps))).round())
		_rect(p.x, p.y, 1, 1, ink)

func _poly(points: Array[Vector2i], ink: String) -> void:
	var polygon: PackedVector2Array = PackedVector2Array()
	for point in points: polygon.append(Vector2(point))
	var bounds: Rect2 = Rect2(polygon[0], Vector2.ZERO)
	for point in polygon: bounds = bounds.expand(point)
	for y in range(int(bounds.position.y), int(bounds.end.y) + 1):
		for x in range(int(bounds.position.x), int(bounds.end.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), polygon): _rect(x, y, 1, 1, ink)

func _tiles() -> void:
	_canvas(128, 128)
	for tile in range(64):
		offset = Vector2i(tile % 8 * 16, tile / 8 * 16)
		if tile < 8 or (tile >= 32 and tile < 40):
			_floor(tile)
		elif tile >= 16 and tile < 32:
			_wall(tile - 16)
		else:
			_decor(tile)
	img.save_png("res://assets/catacombs_tiles.png")

func _floor(tile: int) -> void:
	var variant: int = tile if tile < 8 else tile - 26
	var shades: Array[String] = ["263244", "283546", "293544", "243040", "293740", "27353e", "2b3647", "243143"]
	_rect(0, 0, 16, 16, shades[variant % 8])
	# Low-contrast, irregular slab seams; no identical bright box around every tile.
	var joint: int = 6 + variant % 4
	_line(Vector2i(0, joint), Vector2i(15, joint), "202b3a")
	_line(Vector2i(0, joint + 1), Vector2i(13, joint + 1), "304052")
	_line(Vector2i(5 + variant % 3, 0), Vector2i(5 + variant % 3, joint), "202b3a")
	_line(Vector2i(11 - variant % 3, joint), Vector2i(11 - variant % 3, 15), "202b3a")
	for n in range(4):
		_rect((n * 7 + variant * 5) % 16, (n * 3 + variant * 2) % 16, 1, 1, "304052")
	if tile == 2 or tile == 3 or tile == 34:
		_line(Vector2i(12, 0), Vector2i(9, 5), "182231")
		_line(Vector2i(9, 5), Vector2i(11, 9), "182231")
		_line(Vector2i(11, 9), Vector2i(6, 13), "182231")
	if tile == 4 or tile == 5:
		for n in range(9): _rect(n % 4, (n * 3) % 6 + 9, 2, 1, "moss")
	if tile == 6:
		_line(Vector2i(8, 3), Vector2i(4, 6), "gold")
		_line(Vector2i(4, 6), Vector2i(4, 10), "gold")
		_line(Vector2i(4, 10), Vector2i(8, 13), "gold")
		_rect(10, 6, 2, 4, "cyan")
	if tile == 7:
		for n in range(3):
			_rect(0, 3 + n * 5, 16, 2, "edge")
			_rect(0, 5 + n * 5, 16, 1, "dark")
	if tile == 38 or tile == 39:
		_line(Vector2i(1, 2), Vector2i(14, 2), "3b4557")
		_line(Vector2i(1, 2), Vector2i(1, 13), "3b4557")
		_rect(3, 4, 1, 1, "gold")

func _wall(mask: int) -> void:
	_rect(0, 0, 16, 16, "dark")
	_rect(0, 0, 16, 10, "3c485e")
	_rect(1, 1, 14, 2, "657589")
	_rect(1, 4, 6, 4, "4a596e")
	_rect(8, 4, 7, 4, "435266")
	_rect(7, 3, 1, 6, "dark")
	_rect(0, 9, 16, 1, "172231")
	if mask & 4:
		# Lit coping above a dark three-course vertical face.
		_rect(0, 8, 16, 2, "light")
		_rect(0, 10, 16, 2, "edge")
		_rect(0, 12, 16, 3, "263143")
		_rect(0, 15, 16, 1, "void")
		_rect(5, 11, 1, 4, "dark")
		_rect(13, 10, 1, 5, "dark")
	if mask & 1:
		_rect(0, 0, 16, 2, "light")
		_rect(0, 2, 16, 1, "edge")
	if mask & 2:
		_rect(13, 0, 1, 16, "light")
		_rect(14, 0, 2, 16, "edge")
	if mask & 8:
		_rect(0, 0, 2, 16, "edge")
		_rect(2, 0, 1, 16, "light")
	_line(Vector2i(11, 3), Vector2i(10, 6), "stone")

func _decor(tile: int) -> void:
	match tile:
		8, 9:
			_rect(2, 12, 12, 4, "0b101ca0")
			_rect(3, 11, 10, 3, "stone")
			_rect(4, 10, 8, 2, "edge")
		10:
			_rect(1, 3, 14, 13, "101725b0")
			_rect(2, 5, 12, 8, "stone")
		11:
			_rect(3, 6, 5, 5, "bone")
			_rect(4, 7, 1, 2, "dark")
			_rect(7, 7, 1, 2, "dark")
			_line(Vector2i(8, 12), Vector2i(13, 14), "bone")
			_line(Vector2i(12, 9), Vector2i(10, 14), "bone")
		12, 48, 49, 50:
			var phase: int = maxi(0, tile - 47)
			_rect(5, 9, 6, 6, "dark")
			_rect(6, 10, 4, 3, "gold")
			_rect(7, 4, 3, 6, "cape")
			_rect(5 + phase % 2, 3, 5, 6, "cyan")
			_rect(7, 2 - phase % 2, 2, 6, "ice")
		13:
			for n in range(6):
				_rect((n * 3) % 12 + 1, (n * 7) % 9 + 5, 4, 3, "dark")
				_rect((n * 3) % 12 + 1, (n * 7) % 9 + 4, 3, 2, "edge")
		14:
			_line(Vector2i(4, 3), Vector2i(4, 12), "cyan")
			_line(Vector2i(4, 3), Vector2i(9, 1), "cyan")
			_line(Vector2i(4, 12), Vector2i(9, 14), "cyan")
			_rect(10, 5, 2, 6, "gold")
		15:
			_rect(2, 6, 12, 8, "dark")
			_rect(3, 4, 10, 8, "edge")
			_rect(5, 2, 6, 3, "light")
		40:
			_line(Vector2i(0, 2), Vector2i(5, 9), "moss")
			_line(Vector2i(5, 9), Vector2i(1, 15), "moss")
			_line(Vector2i(5, 9), Vector2i(10, 11), "moss")
		41:
			_rect(3, 11, 10, 4, "dark")
			_poly([Vector2i(7, 1), Vector2i(11, 10), Vector2i(7, 13), Vector2i(4, 9)], "purple")
			_line(Vector2i(7, 2), Vector2i(7, 11), "ice")
			_line(Vector2i(8, 5), Vector2i(10, 10), "cyan")
		42:
			_rect(6, 7, 3, 7, "bone")
			_rect(7, 4, 1, 3, "gold")
			_rect(6, 4, 3, 2, "ice")
		43:
			_rect(3, 0, 10, 14, "purple")
			_rect(4, 0, 8, 2, "gold")
			_line(Vector2i(6, 4), Vector2i(6, 10), "gold")
			_rect(7, 5, 3, 4, "edge")
		44:
			_rect(3, 4, 9, 8, "293044")
			_line(Vector2i(3, 4), Vector2i(11, 4), "edge")
			_line(Vector2i(3, 4), Vector2i(3, 11), "edge")
		45:
			_line(Vector2i(2, 7), Vector2i(13, 7), "purple")
			_line(Vector2i(7, 2), Vector2i(7, 13), "purple")
			_rect(6, 6, 3, 3, "cyan")
		46, 47:
			_rect(2, 9, 12, 5, "dark")
			_rect(3, 8, 9, 3, "rust")
			_rect(4, 7, 5, 1, "gold")
		52, 53, 54, 55:
			_floor(35)
			var quadrant: Vector2i = Vector2i((tile - 52) % 2, (tile - 52) / 2) * 16
			for y in range(16):
				for x in range(16):
					var p: Vector2 = Vector2(Vector2i(x, y) + quadrant) - Vector2(15.5, 15.5)
					if absf(p.length() - 13.5) < 0.7: _rect(x, y, 1, 1, "445368")
					if p.length() < 8.0 and (p - Vector2(4, -3)).length() > 7.0: _rect(x, y, 1, 1, "5c586d")

func _actor(kind: String) -> void:
	_canvas(192, 192)
	for state in range(6):
		for frame in range(6):
			offset = Vector2i(frame * 32, state * 32)
			var bob: int = 1 if frame % 3 == 1 and state < 2 else 0
			var step: int = (1 if frame < 3 else -1) if state == 1 else 0
			if state == 5:
				var fall: int = mini(frame, 4) * 3
				_rect(5, 18 + fall / 3, 23, 8, "dark")
				_rect(7, 17 + fall / 3, 18, 6, "cape" if kind == "kael" else "purple")
				_rect(6 - mini(frame, 3), 8 + fall, 7, 6, "hair" if kind == "kael" else "edge")
				_line(Vector2i(22, 27), Vector2i(30, 22), "light")
				continue
			_rect(6, 29, 22, 2, "080e1970")
			if kind == "kael": _kael(frame, state, bob, step)
			elif kind == "crawler": _crawler(frame, bob, step)
			elif kind == "archer": _archer(frame, bob)
			else: _guardian(frame, bob, step)
			if state == 4:
				_line(Vector2i(6, 12 + frame % 3), Vector2i(25, 12 + frame % 3), "white" if frame % 2 == 0 else "blood")
	img.save_png("res://assets/%s.png" % kind)

func _kael(frame: int, state: int, bob: int, step: int) -> void:
	var flutter: int = frame % 3
	# A broad blue cape and silver hair read independently of the stone palette.
	_poly([Vector2i(9, 11), Vector2i(19, 12), Vector2i(17, 27), Vector2i(3 + flutter, 28), Vector2i(6, 18)], "dark")
	_poly([Vector2i(9, 12), Vector2i(17, 13), Vector2i(15, 25), Vector2i(4 + flutter, 26), Vector2i(7, 18)], "cape")
	_line(Vector2i(9, 14), Vector2i(7 + flutter, 24), "cape_light")
	_line(Vector2i(13, 15), Vector2i(12, 24), "blue")
	_rect(11, 24 - step, 4, 5 + step, "dark")
	_rect(18, 24 + step, 4, 5 - step, "dark")
	_rect(11, 27 - step, 5, 2, "edge")
	_rect(18, 27 + step, 5, 2, "edge")
	_rect(11, 12 + bob, 11, 12, "dark")
	_rect(12, 13 + bob, 9, 9, "edge")
	_rect(12, 14 + bob, 3, 7, "light")
	_line(Vector2i(16, 15 + bob), Vector2i(18, 21 + bob), "stone")
	_rect(9, 12 + bob, 6, 4, "light")
	_rect(10, 12 + bob, 4, 1, "white")
	_rect(20, 13 + bob, 4, 3, "light")
	_rect(12, 22 + bob, 10, 2, "gold")
	_rect(14, 23 + bob, 2, 3, "purple")
	_rect(21, 17 + bob, 3, 5, "skin")
	_rect(12, 3 + bob, 10, 10, "dark")
	_rect(14, 6 + bob, 7, 6, "skin")
	_rect(14, 10 + bob, 5, 2, "rust")
	_rect(18, 7 + bob, 3, 1, "ice")
	_rect(20, 8 + bob, 2, 2, "skin")
	# Chunked fringe, crown and swept silver locks instead of a helmet.
	_rect(11, 4 + bob, 11, 4, "hair")
	_rect(13, 2 + bob, 7, 2, "white")
	_rect(11, 6 + bob, 3, 5, "light")
	_rect(14, 4 + bob, 3, 5, "white")
	_rect(20, 4 + bob, 3, 2, "hair")
	_rect(10, 9 + bob, 3, 3, "hair")
	if state == 2:
		var sword_tip: Array[Vector2i] = [Vector2i(22,2), Vector2i(27,4), Vector2i(30,12), Vector2i(29,21), Vector2i(25,27), Vector2i(24,22)]
		var tip: Vector2i = sword_tip[frame]
		_line(Vector2i(23, 17), tip, "white")
		_line(Vector2i(24, 17), tip + Vector2i(1, 0), "ice")
		_rect(21, 16, 5, 2, "gold")
	else:
		_rect(25, 6 + bob, 2, 17, "dark")
		_rect(25, 6 + bob, 1, 12, "white")
		_rect(26, 8 + bob, 1, 10, "ice")
		_rect(23, 18 + bob, 6, 2, "gold")
		_rect(25, 20 + bob, 2, 3, "rust")
	if state == 3:
		_line(Vector2i(1 + frame % 2, 17), Vector2i(7, 17), "cyan")
		_line(Vector2i(0, 22), Vector2i(4 + frame % 3, 22), "cape_light")

func _crawler(frame: int, bob: int, step: int) -> void:
	_poly([Vector2i(5,14), Vector2i(11,10), Vector2i(23,12), Vector2i(29,19), Vector2i(23,25), Vector2i(8,23)], "dark")
	_poly([Vector2i(8,14+bob), Vector2i(13,12+bob), Vector2i(23,14+bob), Vector2i(25,20+bob), Vector2i(10,21+bob)], "purple")
	for n in range(3):
		_line(Vector2i(9 + n*5, 18), Vector2i(3 + n*8 + step, 27), "bone")
		_line(Vector2i(9 + n*5, 14), Vector2i(3 + n*8 - step, 8), "rust")
		_rect(11 + n*4, 13 + bob, 2, 3, "blood")
	_rect(22, 17 + bob, 6, 5, "dark")
	_rect(23, 18 + bob, 4, 1, "ice")
	_rect(25, 22 + bob, 3, 1, "bone")
	_rect(10, 11 + bob, 2, 2, "bone")
	_rect(5 + frame % 2, 22, 3, 2, "rust")

func _archer(frame: int, bob: int) -> void:
	_poly([Vector2i(12,5+bob), Vector2i(21,5+bob), Vector2i(25,26), Vector2i(20,28-frame%2), Vector2i(10,27), Vector2i(6,23)], "dark")
	_poly([Vector2i(12,12+bob), Vector2i(20,12+bob), Vector2i(22,25), Vector2i(18,27-frame%2), Vector2i(9,25)], "735585")
	_line(Vector2i(13,15+bob), Vector2i(11,24), "b995d0")
	_rect(11, 3 + bob, 12, 11, "purple")
	_rect(13, 5 + bob, 8, 7, "dark")
	_rect(14, 7 + bob, 6, 4, "bone")
	_rect(15, 8 + bob, 5, 1, "cyan")
	_rect(16, 11 + bob, 3, 1, "dark")
	_rect(10, 15, 11, 1, "gold")
	_rect(11, 27, 2, 2 - frame % 2, "cyan")
	_rect(19, 27, 2, 1 + frame % 2, "cyan")
	_line(Vector2i(26,6), Vector2i(30,16), "gold")
	_line(Vector2i(30,16), Vector2i(26,27), "gold")
	_line(Vector2i(26,6), Vector2i(26,27), "bone")
	_line(Vector2i(19,17+bob), Vector2i(29,17+bob), "ice")

func _guardian(frame: int, bob: int, step: int) -> void:
	_rect(4, 11 + bob, 25, 14, "dark")
	_rect(6, 10 + bob, 20, 13, "stone")
	_rect(5, 11 + bob, 5, 10, "light")
	_rect(24, 11 + bob, 5, 10, "edge")
	_rect(7, 24 - step, 6, 6, "edge")
	_rect(21, 24 + step, 6, 6 - maxi(0, step), "edge")
	_rect(10, 2 + bob, 15, 11, "dark")
	_rect(11, 2 + bob, 12, 9, "edge")
	_rect(12, 3 + bob, 8, 2, "light")
	_rect(12, 7 + bob, 10, 2, "dark")
	_rect(14, 7 + bob, 7, 1, "cyan")
	_rect(15, 17 + bob, 6, 4, "purple")
	_rect(17, 17 + bob, 2, 3, "ice" if frame % 3 == 0 else "cyan")
	_line(Vector2i(21,12+bob), Vector2i(18,17+bob), "purple")
	_line(Vector2i(18,21+bob), Vector2i(20,24), "purple")
	_rect(4, 10 + bob, 6, 2, "bone")
	_rect(24, 10 + bob, 5, 2, "bone")

func _environment() -> void:
	_canvas(192, 48)
	for frame in range(6):
		offset = Vector2i(frame * 32, 0)
		_rect(3, 40, 26, 6, "080e1980")
		match frame:
			0: # Weathered funerary statue, sword and broken crown.
				_rect(6, 38, 21, 6, "stone")
				_rect(8, 35, 17, 4, "light")
				_poly([Vector2i(13,13), Vector2i(21,13), Vector2i(24,34), Vector2i(9,34)], "edge")
				_line(Vector2i(13,17), Vector2i(12,31), "light")
				_rect(12, 6, 10, 8, "edge")
				_rect(13, 5, 7, 3, "bone")
				_rect(13, 10, 7, 1, "dark")
				_rect(17, 19, 2, 15, "gold")
				_rect(13, 23, 9, 2, "light")
			1: # Tall column with fluted shaft and blue reflected edges.
				_rect(5, 38, 23, 7, "stone")
				_rect(6, 36, 21, 3, "light")
				_rect(10, 10, 14, 26, "edge")
				_rect(10, 10, 3, 26, "light")
				_rect(17, 11, 2, 24, "stone")
				_rect(22, 11, 2, 24, "dark")
				_rect(6, 6, 21, 5, "light")
				_rect(8, 4, 17, 3, "edge")
				_line(Vector2i(15,15), Vector2i(19,19), "dark")
				_line(Vector2i(19,19), Vector2i(15,24), "dark")
			2: # Raised sarcophagus lid, chipped sides and effigy.
				_rect(5, 21, 22, 22, "dark")
				_rect(5, 18, 20, 21, "edge")
				_rect(6, 19, 18, 2, "light")
				_rect(7, 22, 16, 14, "stone")
				_rect(13, 23, 5, 4, "light")
				_rect(14, 28, 3, 7, "light")
				_rect(10, 30, 11, 1, "gold")
				_rect(6, 38, 18, 2, "dark")
			3: # Lunar crystal cluster.
				_poly([Vector2i(7,37), Vector2i(4,29), Vector2i(8,24), Vector2i(13,37)], "purple")
				_poly([Vector2i(12,38), Vector2i(11,20), Vector2i(17,9), Vector2i(22,23), Vector2i(19,38)], "purple")
				_line(Vector2i(17,12), Vector2i(16,35), "ice")
				_line(Vector2i(18,17), Vector2i(21,23), "cyan")
				_poly([Vector2i(22,38), Vector2i(21,29), Vector2i(27,21), Vector2i(28,34)], "blue")
				_line(Vector2i(26,24), Vector2i(24,34), "cyan")
			4: # Roots embracing broken stone.
				_rect(8, 34, 17, 8, "edge")
				_rect(10, 31, 9, 3, "light")
				_line(Vector2i(8,19), Vector2i(13,31), "moss")
				_line(Vector2i(13,31), Vector2i(6,40), "moss")
				_line(Vector2i(14,31), Vector2i(24,40), "moss")
			5: # Lunar altar; bright ornament is restricted to room edges.
				_rect(6, 33, 21, 10, "stone")
				_rect(4, 30, 25, 5, "edge")
				_rect(5, 30, 23, 1, "light")
				_rect(8, 34, 2, 8, "light")
				_rect(23, 34, 2, 8, "light")
				_line(Vector2i(16,12), Vector2i(11,16), "gold")
				_line(Vector2i(11,16), Vector2i(11,23), "gold")
				_line(Vector2i(11,23), Vector2i(16,26), "gold")
				_rect(19, 16, 3, 7, "cyan")
	img.save_png("res://assets/environment.png")

func _props() -> void:
	_canvas(96, 32)
	for frame in range(4):
		offset = Vector2i(frame * 24, 0)
		if frame < 2:
			_rect(3, 23, 18, 3, "080e1980")
			_rect(4, 13, 16, 10, "gold")
			_rect(5, 15, 14, 6, "rust")
			_rect(7, 15, 2, 6, "gold")
			_rect(16, 15, 2, 6, "gold")
			_rect(11, 16, 3, 3, "ice")
			if frame == 0:
				_rect(4, 10, 16, 5, "gold")
				_rect(5, 11, 14, 2, "edge")
			else:
				_rect(4, 6, 16, 5, "gold")
				_rect(5, 7, 14, 3, "dark")
				_rect(5, 12, 14, 3, "dark")
				_rect(8, 12, 7, 2, "cyan")
		else:
			_rect(3, 5, 4, 21, "edge")
			_rect(18, 5, 4, 21, "edge")
			_rect(5, 3, 15, 4, "light")
			_rect(7, 8, 11, 17, "purple" if frame == 2 else "cyan")
			_rect(9, 10, 7, 14, "blue")
			_rect(11, 14, 3, 6, "ice")
	img.save_png("res://assets/props.png")
