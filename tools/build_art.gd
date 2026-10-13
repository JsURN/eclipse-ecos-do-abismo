extends SceneTree
## Offline, deterministic pixel art baker. Runtime uses the saved PNGs.

const COLORS: Dictionary = {
	"void": "0b101c", "seam": "162032", "stone": "29364a", "edge": "41516a",
	"light": "61718a", "bone": "b7bcc5", "white": "dce9ed", "blue": "25355b",
	"purple": "59426c", "cyan": "65dddb", "ice": "b7f6ee", "gold": "c4a66b",
	"rust": "6c5260", "moss": "34564f", "dark": "101522", "blood": "bd627e"
}
var img: Image
var offset: Vector2i = Vector2i.ZERO

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets")
	_tiles()
	_actor("kael")
	_actor("crawler")
	_actor("archer")
	_actor("guardian")
	_props()
	print("ART: baked tiles, Kael, 3 enemies and props into assets/")
	quit()

func _canvas(w: int, h: int) -> void:
	img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

func _rect(x: int, y: int, w: int, h: int, ink: String) -> void:
	img.fill_rect(Rect2i(offset + Vector2i(x, y), Vector2i(w, h)), Color(String(COLORS.get(ink, ink))))

func _line(a: Vector2i, b: Vector2i, ink: String) -> void:
	var steps: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
	for n in range(steps + 1):
		var p: Vector2i = Vector2i(Vector2(a).lerp(Vector2(b), float(n) / float(maxi(1, steps))).round())
		_rect(p.x, p.y, 1, 1, ink)

func _tiles() -> void:
	_canvas(128, 64)
	for tile in range(32):
		offset = Vector2i(tile % 8 * 16, tile / 8 * 16)
		_rect(0, 0, 16, 16, "seam")
		if tile < 8:
			_rect(1, 1, 14, 7, "stone")
			_rect(1, 9, 7, 6, "stone")
			_rect(9, 9, 6, 6, "stone")
			_line(Vector2i(2, 1), Vector2i(13, 1), "edge")
			_line(Vector2i(1, 10), Vector2i(6, 10), "edge")
			for p in range(8):
				_rect((p * 7 + tile * 3) % 14 + 1, (p * 5 + tile * 2) % 13 + 2, 1, 1, "edge")
			if tile == 2 or tile == 3:
				_line(Vector2i(9, 2), Vector2i(7, 6), "dark")
				_line(Vector2i(7, 6), Vector2i(11, 11), "dark")
				_line(Vector2i(8, 7), Vector2i(4, 8), "dark")
			if tile == 4 or tile == 5:
				for p in range(14):
					_rect(p % 6 + 1, (p * 3) % 5 + 10, 2, 1, "moss")
			if tile == 6:
				_line(Vector2i(8, 3), Vector2i(4, 6), "gold")
				_line(Vector2i(4, 6), Vector2i(4, 10), "gold")
				_line(Vector2i(4, 10), Vector2i(8, 13), "gold")
				_rect(10, 6, 2, 4, "cyan")
			if tile == 7:
				_rect(2, 3, 12, 2, "edge")
				_rect(2, 7, 12, 2, "edge")
				_rect(2, 11, 12, 2, "edge")
		elif tile < 16:
			# Transparent decor tiles sit on a separate TileMapLayer.
			_rect(0, 0, 16, 16, "00000000")
			match tile:
				8, 9:
					_rect(2, 12, 12, 4, "dark")
					_rect(3, 10, 10, 4, "stone")
					_rect(5, 2, 6, 10, "edge")
					_rect(5, 2, 2, 10, "light")
					_rect(3, 0, 10, 3, "light")
					_rect(7, 4, 1, 5, "stone")
					if tile == 9:
						_rect(7, 1, 6, 4, "00000000")
						_line(Vector2i(5, 9), Vector2i(9, 7), "dark")
				10:
					_rect(3, 4, 10, 12, "dark")
					_rect(2, 2, 10, 12, "edge")
					_rect(3, 3, 8, 9, "stone")
					_rect(6, 5, 2, 6, "gold")
					_rect(4, 7, 6, 1, "gold")
				11:
					_rect(3, 6, 5, 5, "bone")
					_rect(4, 7, 1, 2, "dark")
					_rect(7, 7, 1, 2, "dark")
					_line(Vector2i(8, 12), Vector2i(13, 14), "bone")
					_line(Vector2i(12, 9), Vector2i(10, 14), "bone")
				12:
					_rect(5, 8, 6, 6, "gold")
					_rect(7, 4, 2, 7, "ice")
					_rect(4, 3, 7, 5, "cyan")
					_rect(6, 0, 3, 6, "blue")
					_rect(7, 2, 2, 6, "ice")
				13:
					for p in range(7):
						_rect((p * 3) % 12 + 1, (p * 7) % 9 + 5, 3, 2, "edge")
				14:
					_line(Vector2i(4, 3), Vector2i(4, 12), "cyan")
					_line(Vector2i(4, 3), Vector2i(9, 1), "cyan")
					_line(Vector2i(4, 12), Vector2i(9, 14), "cyan")
					_rect(10, 5, 2, 6, "gold")
				15:
					_rect(2, 6, 12, 8, "dark")
					_rect(3, 4, 10, 8, "edge")
					_rect(5, 2, 6, 3, "light")
		else:
			var mask: int = tile - 16
			_rect(0, 0, 16, 16, "dark")
			_rect(1, 1, 14, 14, "stone")
			_rect(1, 1, 14, 2, "edge")
			_rect(1, 8, 14, 1, "dark")
			_rect(7, 1, 1, 7, "dark")
			_rect(3, 9, 1, 6, "dark")
			_rect(12, 9, 1, 6, "dark")
			if mask & 1: _rect(0, 0, 16, 3, "light")
			if mask & 2: _rect(13, 0, 3, 16, "light")
			if mask & 4:
				_rect(0, 10, 16, 6, "edge")
				_rect(0, 10, 16, 2, "light")
				_rect(0, 15, 16, 1, "dark")
			if mask & 8: _rect(0, 0, 3, 16, "light")
	img.save_png("res://assets/catacombs_tiles.png")

func _actor(kind: String) -> void:
	_canvas(96, 144)
	for state in range(6):
		for frame in range(4):
			offset = Vector2i(frame * 24, state * 24)
			var bob: int = 1 if frame % 2 == 1 and state < 2 else 0
			if state == 5:
				var fall: int = mini(frame, 2) * 3
				_rect(5, 10 + fall, 13, 10 - fall, "dark")
				_rect(7, 11 + fall, 10, 7 - fall, "purple" if kind == "kael" else "edge")
				_rect(5 - mini(frame, 2), 7 + fall, 5, 4, "light")
				_rect(17, 18, 4, 1, "gold")
				if frame == 3: _rect(6, 17, 11, 2, "stone")
				continue
			_rect(5, 21, 14, 2, "0b101ca0")
			if kind == "kael":
				# Torn plum cape, steel pauldrons, moon visor and a pale blade.
				_rect(6, 10 + bob, 11, 10, "dark")
				_rect(5, 10 + bob, 10, 9, "purple")
				_rect(5, 14 + bob, 2, 7, "rust")
				_rect(8, 10 + bob, 9, 7, "stone")
				_rect(8, 11 + bob, 2, 5, "light")
				_rect(6, 9 + bob, 5, 3, "light")
				_rect(15, 9 + bob, 4, 3, "edge")
				_rect(9, 3 + bob, 8, 7, "dark")
				_rect(10, 3 + bob, 6, 5, "light")
				_rect(8, 6 + bob, 9, 2, "stone")
				_rect(11, 7 + bob, 5, 1, "cyan")
				_rect(12, 4 + bob, 1, 2, "gold")
				_rect(8, 17, 4, 4 + bob, "dark")
				_rect(14, 17, 3, 4 - bob, "dark")
				_rect(8, 17, 8, 1, "gold")
				if state == 2:
					_line(Vector2i(16, 12), Vector2i(22, 4 + frame * 4), "white")
					_rect(17, 11, 4, 2, "gold")
				else:
					_rect(19, 6 + bob, 2, 10, "white")
					_rect(17, 14 + bob, 5, 1, "gold")
				if state == 3:
					_line(Vector2i(frame % 2, 12), Vector2i(3 + frame, 12), "cyan")
					_line(Vector2i(0, 15 + frame % 2), Vector2i(5, 15 + frame % 2), "purple")
			elif kind == "crawler":
				_rect(5, 11 + bob, 14, 7, "dark")
				_rect(6, 10 + bob, 11, 6, "purple")
				_rect(10, 8 + bob, 6, 4, "rust")
				_rect(15, 13 + bob, 4, 2, "cyan")
				for leg in range(3):
					_line(Vector2i(6 + leg * 4, 16), Vector2i(3 + leg * 6 + bob, 20), "edge")
					_line(Vector2i(6 + leg * 4, 11), Vector2i(3 + leg * 6 - bob, 8), "edge")
			elif kind == "archer":
				_rect(7, 8 + bob, 9, 12, "blue")
				_rect(5, 14 + bob, 13, 4, "purple")
				_rect(9, 3 + bob, 7, 7, "blue")
				_rect(10, 5 + bob, 5, 4, "bone")
				_rect(10, 6 + bob, 5, 1, "cyan")
				_rect(8, 18, 2, 3 - bob, "cyan")
				_rect(13, 18, 2, 3 + bob, "cyan")
				_line(Vector2i(18, 6), Vector2i(21, 12), "gold")
				_line(Vector2i(21, 12), Vector2i(18, 19), "gold")
				_line(Vector2i(18, 6), Vector2i(18, 19), "bone")
			else:
				_rect(4, 9 + bob, 16, 10, "dark")
				_rect(5, 8 + bob, 14, 9, "stone")
				_rect(5, 8 + bob, 4, 8, "light")
				_rect(9, 2 + bob, 8, 7, "edge")
				_rect(10, 5 + bob, 6, 1, "purple")
				_rect(11, 5 + bob, 4, 1, "cyan")
				_rect(11, 10 + bob, 2, 6, "purple")
				_rect(12, 12 + bob, 2, 2, "cyan")
				_rect(5, 17, 5, 4 + bob, "edge")
				_rect(14, 17, 5, 4 - bob, "edge")
			if state == 4:
				_rect(7 - frame % 2, 11 + frame % 2, 10, 1, "white" if frame % 2 == 0 else "blood")
	img.save_png("res://assets/%s.png" % kind)

func _props() -> void:
	_canvas(96, 32)
	for frame in range(4):
		offset = Vector2i(frame * 24, 0)
		if frame < 2:
			_rect(3, 23, 18, 3, "dark")
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
