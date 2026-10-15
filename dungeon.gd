extends Node2D
## Hand-authored connected vertical slice. Atlas cells are 16px.
const TILE: int = 16
const SIZE: Vector2i = Vector2i(70, 36)
const COMBAT: Rect2 = Rect2(464, 128, 336, 336)
const START: Vector2 = Vector2(168, 312)
const CHEST: Vector2 = Vector2(952, 312)
const EXIT: Vector2 = Vector2(1024, 312)
const Gate = preload("res://gate.gd")
const Atmosphere = preload("res://atmosphere.gd")

var floor_cells: Dictionary = {}
var obstacles: Dictionary = {}
var ground: TileMapLayer
var decor: TileMapLayer
var actors: Node2D
var navigation: AStarGrid2D
var gates: Array[Gate] = []
var gates_closed: Array[bool] = [false, true]
var gate_positions: Array[Vector2] = [Vector2(456, 296), Vector2(824, 296)]
var torches: Array[PointLight2D] = []
var time: float = 0.0
var glow_texture: ImageTexture
var torch_cells: Array[Vector2i] = []
var rune_points: Array[Vector2] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_carve(Rect2i(3, 12, 14, 14))
	_carve(Rect2i(17, 17, 12, 3))
	_carve(Rect2i(29, 8, 21, 21))
	_carve(Rect2i(50, 17, 4, 3))
	_carve(Rect2i(54, 13, 12, 13))
	var tiles: TileSet = _make_tileset()
	ground = TileMapLayer.new()
	ground.name = "StoneAndWalls"
	ground.scale = Vector2(0.5,0.5)
	ground.tile_set = tiles
	add_child(ground)
	decor = TileMapLayer.new()
	decor.name = "CatacombRelics"
	decor.scale = Vector2(0.5,0.5)
	decor.tile_set = tiles
	add_child(decor)
	for y in range(SIZE.y):
		for x in range(SIZE.x):
			var cell: Vector2i = Vector2i(x, y)
			if floor_cells.has(cell):
				# Seeded cell mixing avoids long repeating diagonal bands.
				var hash_value: int = ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff
				var floors: Array[int] = [0, 0, 1, 32, 33, 35, 36, 37, 2, 34]
				var variant: int = floors[hash_value % floors.size()]
				if x < 7 or x > 62: variant = 4 if hash_value % 4 == 0 else variant
				if x >= 54 and y % 3 == 0: variant = 38 + hash_value % 2
				_put(ground, cell, variant)
			else:
				var mask: int = 0
				if floor_cells.has(cell + Vector2i.UP): mask |= 1
				if floor_cells.has(cell + Vector2i.RIGHT): mask |= 2
				if floor_cells.has(cell + Vector2i.DOWN): mask |= 4
				if floor_cells.has(cell + Vector2i.LEFT): mask |= 8
				# Keep unseen void empty; adjoining wall tiles carry collision.
				if mask > 0 or _diagonal_floor(cell): _put(ground, cell, 16 + mask)
	for p in [Vector2i(33, 12), Vector2i(44, 12), Vector2i(33, 24), Vector2i(44, 24)]:
		_put(decor, p, 8)
		obstacles[p] = true
	for p in [Vector2i(6, 14), Vector2i(13, 14), Vector2i(6, 23), Vector2i(13, 23), Vector2i(57, 15), Vector2i(62, 15)]:
		_put(decor, p, 10)
		obstacles[p] = true
	for p in [Vector2i(35, 10), Vector2i(42, 27), Vector2i(10, 16), Vector2i(59, 23)]: _put(decor, p, 11)
	for p in [Vector2i(31, 25), Vector2i(47, 11), Vector2i(56, 23)]: _put(decor, p, 9)
	for p in [Vector2i(32, 16), Vector2i(46, 22), Vector2i(8, 24), Vector2i(61, 24)]: _put(decor, p, 13)
	for p in [Vector2i(10, 20), Vector2i(39, 18), Vector2i(60, 19)]:
		_put(ground, p, 6)
		_put(decor, p + Vector2i.UP, 14)
		rune_points.append(Vector2(p * 16) + Vector2(8, -8))
	# A restrained 32px moon seal establishes the chamber's center.
	for dy in range(2):
		for dx in range(2): _put(ground, Vector2i(38 + dx, 17 + dy), 52 + dx + dy * 2)
	for p in [Vector2i(4, 20), Vector2i(15, 22), Vector2i(30, 23), Vector2i(48, 15)]: _put(decor, p, 40)
	for p in [Vector2i(6, 16), Vector2i(13, 16), Vector2i(57, 17), Vector2i(62, 17)]: _put(decor, p, 42)
	for p in [Vector2i(34, 9), Vector2i(45, 9)]: _put(decor, p, 43)
	for p in [Vector2i(4, 13), Vector2i(15, 13), Vector2i(20, 17), Vector2i(25, 17), Vector2i(30, 9), Vector2i(48, 9), Vector2i(30, 27), Vector2i(48, 27), Vector2i(55, 14), Vector2i(64, 14)]:
		_add_torch(p)
	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)
	for cell in torch_cells:
		decor.erase_cell(cell)
		_fixture(cell,8)
	for cell in obstacles:
		_fixture(cell, 1 if decor.get_cell_atlas_coords(cell) == Vector2i(0, 1) else 2)
	for p in [Vector2i(4, 15), Vector2i(15, 15), Vector2i(30, 11), Vector2i(48, 25)]: _fixture(p, 0)
	for p in [Vector2i(4, 24), Vector2i(48, 10), Vector2i(30, 26), Vector2i(64, 24)]:
		_fixture(p, 3)
		_add_light(Vector2(p * 16) + Vector2(8, 0), Color("9674d6"), 0.8, 2.0)
	for p in [Vector2i(55, 24), Vector2i(65, 15)]: _fixture(p, 4)
	_fixture(Vector2i(60, 14), 5)
	for at in rune_points: _add_light(at, Color("6e96d3"), 0.45, 1.6)
	var atmosphere: Atmosphere = Atmosphere.new()
	atmosphere.configure(floor_cells, torch_cells, rune_points)
	add_child(atmosphere)
	move_child(atmosphere, actors.get_index())
	_create_gates()
	navigation = AStarGrid2D.new()
	navigation.region = Rect2i(Vector2i.ZERO, SIZE)
	navigation.cell_size = Vector2(TILE, TILE)
	navigation.offset = Vector2(8, 8)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for y in range(SIZE.y):
		for x in range(SIZE.x):
			var p: Vector2i = Vector2i(x, y)
			navigation.set_point_solid(p, not floor_cells.has(p) or obstacles.has(p))
	set_gate(1, true)
	var ambient: CanvasModulate = CanvasModulate.new()
	ambient.color = Color(0.82,0.84,0.93)
	add_child(ambient)

func _carve(area: Rect2i) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x): floor_cells[Vector2i(x, y)] = true

func _diagonal_floor(cell: Vector2i) -> bool:
	for delta in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		if floor_cells.has(cell + delta): return true
	return false

func _make_tileset() -> TileSet:
	return load("res://assets/tilesets/catacombs/catacombs.tres") as TileSet

func _put(layer: TileMapLayer, cell: Vector2i, tile: int) -> void:
	layer.set_cell(cell, 0, Vector2i(tile % 8, tile / 8))

func _create_gates() -> void:
	for i in range(2):
		var body: Gate = Gate.new()
		body.position = gate_positions[i]
		body.collision_layer = 1
		body.collision_mask = 0
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rectangle: RectangleShape2D = RectangleShape2D.new()
		rectangle.size = Vector2(12, 48)
		shape.shape = rectangle
		body.add_child(shape)
		add_child(body)
		gates.append(body)
	set_gate(0, false)

func set_gate(index: int, closed: bool) -> void:
	gates_closed[index] = closed
	gates[index].set_closed(closed)
	var shape: CollisionShape2D = gates[index].get_child(0) as CollisionShape2D
	shape.set_deferred("disabled", not closed)
	if navigation:
		for y in range(17, 20): navigation.set_point_solid(Vector2i(28 if index == 0 else 51, y), closed)
	queue_redraw()

func _add_torch(cell: Vector2i) -> void:
	_put(decor, cell, 12)
	torch_cells.append(cell)
	var light: PointLight2D = _add_light(Vector2(cell*16)+Vector2(8,-14),Color("71cfdf"),0.8,2.5)
	torches.append(light)

func _add_light(at: Vector2, ink: Color, energy: float, radius_scale: float) -> PointLight2D:
	var light: PointLight2D = PointLight2D.new()
	light.position = at
	light.texture = _glow_texture()
	light.texture_scale = radius_scale
	light.color = ink
	light.energy = energy
	add_child(light)
	return light

func _fixture(cell: Vector2i, frame: int) -> void:
	var root: Node2D = Node2D.new()
	root.position = Vector2(cell * 16) + Vector2(8, 8)
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = preload("res://assets/environments/props/details_atlas.png")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(frame*64,0,64,112)
	sprite.scale = Vector2(0.5,0.5)
	sprite.position = Vector2(0,-24)
	root.add_child(sprite)
	actors.add_child(root)

func _glow_texture() -> ImageTexture:
	if glow_texture: return glow_texture
	var image: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var alpha: float = pow(maxf(0.0, 1.0 - Vector2(x - 32, y - 32).length() / 32.0), 2.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	glow_texture = ImageTexture.create_from_image(image)
	return glow_texture

func _process(delta: float) -> void:
	time += delta
	for i in range(torches.size()): torches[i].energy = 0.82 + sin(time * 4.0 + i * 2.3) * 0.07

func _draw() -> void:
	# Void belongs to the dungeon silhouette, not to the traversable stone floor.
	draw_rect(Rect2(32, 112, 1040, 368), Color("090e19"))
	for y in range(7, 30):
		for x in range(2, 67):
			var cell: Vector2i = Vector2i(x, y)
			if not floor_cells.has(cell) and (x * 7 + y * 11) % 17 == 0:
				draw_rect(Rect2(Vector2(cell * 16) + Vector2(3, 9), Vector2(2, 1)), Color("101725"))

func room_name(at: Vector2) -> String:
	if at.x < 272: return "Vestíbulo dos Esquecidos"
	if at.x < 464: return "Passagem das Cinzas"
	if at.x < 816: return "Câmara do Eclipse"
	return "Relicário Lunar"

func path_direction(from: Vector2, to: Vector2) -> Vector2:
	var a: Vector2i = Vector2i((from / 16).floor())
	var b: Vector2i = Vector2i((to / 16).floor())
	if not navigation.is_in_boundsv(a) or not navigation.is_in_boundsv(b): return Vector2.ZERO
	if navigation.is_point_solid(a) or navigation.is_point_solid(b): return from.direction_to(to)
	var path: PackedVector2Array = navigation.get_point_path(a, b)
	if path.size() > 1: return from.direction_to(path[1])
	return from.direction_to(to)
