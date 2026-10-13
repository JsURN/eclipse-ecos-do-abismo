extends Node2D
## Hand-authored connected vertical slice. Atlas cells are 16px.
const TILE: int = 16
const SIZE: Vector2i = Vector2i(70, 36)
const COMBAT: Rect2 = Rect2(464, 128, 336, 336)
const START: Vector2 = Vector2(168, 312)
const CHEST: Vector2 = Vector2(952, 312)
const EXIT: Vector2 = Vector2(1024, 312)
const Gate = preload("res://gate.gd")

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
	ground.tile_set = tiles
	add_child(ground)
	decor = TileMapLayer.new()
	decor.name = "CatacombRelics"
	decor.tile_set = tiles
	add_child(decor)
	for y in range(SIZE.y):
		for x in range(SIZE.x):
			var cell: Vector2i = Vector2i(x, y)
			if floor_cells.has(cell):
				var hash_value: int = (x * 37 + y * 13) % 23
				var variant: int = 0 if hash_value > 6 else hash_value % 6
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
	for p in [Vector2i(4, 13), Vector2i(15, 13), Vector2i(20, 17), Vector2i(25, 17), Vector2i(30, 9), Vector2i(48, 9), Vector2i(30, 27), Vector2i(48, 27), Vector2i(55, 14), Vector2i(64, 14)]:
		_add_torch(p)
	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)
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
	ambient.color = Color(0.79, 0.82, 0.94)
	add_child(ambient)

func _carve(area: Rect2i) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x): floor_cells[Vector2i(x, y)] = true

func _diagonal_floor(cell: Vector2i) -> bool:
	for delta in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		if floor_cells.has(cell + delta): return true
	return false

func _make_tileset() -> TileSet:
	var tiles: TileSet = TileSet.new()
	tiles.tile_size = Vector2i(16, 16)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0, 1)
	var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas.texture = preload("res://assets/catacombs_tiles.png")
	atlas.texture_region_size = Vector2i(16, 16)
	tiles.add_source(atlas, 0)
	for i in range(32):
		var coords: Vector2i = Vector2i(i % 8, i / 8)
		atlas.create_tile(coords)
		if i >= 16 or i == 8 or i == 10:
			var data: TileData = atlas.get_tile_data(coords, 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8,-8), Vector2(8,-8), Vector2(8,8), Vector2(-8,8)]))
	return tiles

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
	var light: PointLight2D = PointLight2D.new()
	light.position = Vector2(cell * 16) + Vector2(8, 4)
	light.texture = _glow_texture()
	light.texture_scale = 3.0
	light.color = Color("5dcaca")
	light.energy = 0.65
	add_child(light)
	torches.append(light)

func _glow_texture() -> ImageTexture:
	var image: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var alpha: float = pow(maxf(0.0, 1.0 - Vector2(x - 32, y - 32).length() / 32.0), 2.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)

func _process(delta: float) -> void:
	time += delta
	for i in range(torches.size()): torches[i].energy = 0.55 + sin(time * 4.0 + i * 2.3) * 0.08

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
