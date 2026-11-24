extends Node2D
## Builds the continuous isometric Catacumbas from catacomb_layout.gd.
##
## Two representations of the same map:
##  * LOGIC (logic_root, hidden): cartesian 16-unit grid with wall/prop collision,
##    sealable passages and an AStarGrid2D. Same scale and API (path_direction,
##    room_name, floor_cells, _glow_texture) as dungeon.gd, so player.gd, enemy.gd
##    and projectile.gd run unchanged on top of it.
##  * VIEW (this node), drawn in this order:
##      FloorDiamonds  stone/void diamonds (themed per area, tinted in patches)
##      FloorDetail    decals: cracks, moss, puddles, bones, soot...
##      WallShade      ambient occlusion where the floor meets a wall
##      RaisedFloor    dais and stairs (own Y-sort)
##      FloorGlow      runes, seal thresholds, contact shadows
##      DepthSorted    every tall element at its projected FOOT/BASE point, so
##                     Godot's Y-sort yields correct painter's order between Kael,
##                     walls, arches, pillars, props and enemies
##      Lights         PointLight2D (sconces, braziers, runes, chest, exit...)
## Visual only: nothing below changes collision, navigation or gameplay rules.
const IsoMath = preload("res://isometric/iso_math.gd")
const Layout = preload("res://isometric/catacomb_layout.gd")
const IsoSeal = preload("res://isometric/iso_seal.gd")
const FloorGlow = preload("res://isometric/iso_floor_glow.gd")

const ART: String = "res://assets/isometric/catacombs/"
const PROPS_DIR: String = "res://assets/environments/props/"
## TileSet sources and floor atlas columns (see tools/build_iso_art.gd).
const SOURCE_FLOOR: int = 0
const SOURCE_SHADE: int = 1
const SOURCE_DECAL: int = 2
const SOURCE_ROCK: int = 3
## Rock mass atlas: ROCK_HEIGHTS levels x ROCK_VARIANTS (32x56 regions).
const ROCK_HEIGHTS: Array[int] = [0, 12, 20, 28, 40]
const ROCK_VARIANTS: int = 4
## Rock fades into shadow with distance from the nearest floor (alternative tiles).
const ROCK_SHADES: Array[Color] = [Color.WHITE, Color(0.8, 0.8, 0.86), Color(0.62, 0.62, 0.7), Color(0.46, 0.46, 0.54), Color(0.32, 0.32, 0.4)]
## Rock this close to the floor is rendered as raised mass; farther away it stays flat.
const ROCK_REACH: int = 7
const FLOOR_PLAIN: Array[int] = [0, 1, 2, 3, 4, 5]
const FLOOR_RUNE: int = 11
const FLOOR_VOID: Array[int] = [12, 13, 14]
const DAIS: Array[int] = [15, 18]
const DAIS_SEAL: int = 16
const STAIRS: int = 17
const FLOOR_WATER: Array[int] = [19, 20]
## Patch tints (alternative tiles) that break up the repetition of the stone.
const TINTS: Array[Color] = [Color.WHITE, Color(0.86, 0.87, 0.93), Color(1.1, 1.1, 1.14), Color(0.97, 0.9, 1.07), Color(0.9, 1.0, 1.03)]
## Wall atlas rows (tools/build_iso_art.gd FULL_ROWS / LOW_ROWS).
const WALL_ROW: Dictionary = {"plain": 0, "cracked": 3, "mossy": 4, "rune": 5, "banner": 7, "sconce": 9, "niche": 11, "pier": 13, "quoin": 15, "broken": 16}
const LOW_ROW: Dictionary = {"plain": 0, "cracked": 2, "mossy": 3, "broken": 4}
const FULL_HEIGHT: int = 56
const LOW_HEIGHT: int = 28
enum WallKind { NONE, LOW, FULL, POST }

## Per-area art direction. special: [floor column, % of cells]; decals: [decal column,
## % of cells]; walls: decorations allowed on back walls facing this area.
## Decals: 0 cracks, 1 moss, 2 puddle, 3 pebbles, 4 bones, 5 corruption,
## 6 ritual scratches, 7 soot, 8 dust, 9 coins. Floor: 6 cracked, 7 worn, 8 mossy,
## 9 engraved, 10 ash.
const THEMES: Dictionary = {
	"Vestíbulo dos Esquecidos": {"special": [[7, 10], [6, 3], [9, 3]], "decals": [[8, 8], [0, 3], [4, 2]], "walls": ["banner", "sconce", "rune", "plain"], "tint": 0, "low": "plain"},
	"Passagem das Cinzas": {"special": [[10, 30], [6, 10]], "decals": [[7, 12], [3, 8], [0, 6]], "walls": ["cracked", "sconce", "plain"], "tint": 0, "low": "cracked", "broken": 12},
	"Câmara do Eclipse": {"special": [[9, 5], [7, 8], [6, 4]], "decals": [[5, 3], [6, 3], [0, 4], [8, 4]], "walls": ["banner", "rune", "sconce", "banner"], "tint": 0, "low": "plain"},
	"Descida do Ossário": {"special": [[6, 8], [8, 5]], "decals": [[4, 6], [3, 6]], "walls": ["niche", "sconce"], "tint": 3, "low": "cracked"},
	"Ossário Lunar": {"special": [[9, 6], [7, 8]], "decals": [[4, 7], [9, 2], [5, 3], [8, 4], [6, 2]], "walls": ["niche", "sconce", "niche", "banner"], "tint": 3, "low": "plain"},
	"Fenda Colapsada": {"special": [[6, 20], [8, 15]], "decals": [[3, 12], [1, 8], [0, 8]], "walls": ["cracked", "mossy"], "tint": 4, "low": "mossy", "broken": 25},
	"Galeria Quebrada": {"special": [[6, 15], [8, 15]], "decals": [[1, 10], [3, 8], [0, 6]], "walls": ["cracked", "mossy", "sconce"], "tint": 4, "low": "mossy", "broken": 20},
	"Ruínas Submersas": {"special": [[8, 25], [6, 12], [7, 8]], "decals": [[1, 8], [2, 8], [0, 6], [3, 5]], "walls": ["mossy", "cracked", "sconce", "rune"], "tint": 4, "low": "mossy", "broken": 18},
}
## Prop table. "block" = isometric sprite whose base diamond sits on the cell (one
## variant picked per cell); otherwise a front-facing billboard reused from the
## top-down slice. Collision: "radius" (circle) or "box" (square side), world units.
const PROPS: Dictionary = {
	"P": {"art": [ART + "pillar_a.png", ART + "pillar_b.png"], "block": true, "radius": 7.0, "occluder": true, "shadow": 11.0},
	"~": {"art": [ART + "wall_broken_a.png", ART + "wall_broken_b.png"], "block": true, "box": 16.0, "occluder": true},
	"X": {"art": [ART + "sarcophagus.png"], "block": true, "box": 14.0, "shadow": 13.0},
	"C": {"art": [ART + "chest_closed.png"], "block": true, "box": 14.0, "shadow": 10.0},
	"Q": {"art": [ART + "pedestal.png"], "block": true, "radius": 6.0, "light": Color("65dddb"), "light_height": 26.0, "shadow": 10.0, "motes": Color("8ff2ea")},
	"S": {"art": [PROPS_DIR + "statue_sword.png"], "radius": 7.0, "occluder": true, "shadow": 10.0},
	"T": {"art": [PROPS_DIR + "torch.png"], "radius": 4.0, "light": Color("71cfdf"), "torch": true, "shadow": 5.0},
	"A": {"art": [PROPS_DIR + "altar.png"], "radius": 7.0, "light": Color("9674d6"), "motes": Color("c7a2e6")},
	"c": {"art": [PROPS_DIR + "crystal.png"], "radius": 5.0, "light": Color("9674d6"), "shadow": 6.0},
	"r": {"art": [PROPS_DIR + "rubble.png"], "radius": 5.0},
	"B": {"art": [PROPS_DIR + "bones.png"]},
	"G": {"art": [ART + "pillar_stump.png"], "block": true, "radius": 7.0, "shadow": 11.0},
	"F": {"art": [ART + "fallen_column.png"], "block": true, "box": 14.0, "shadow": 12.0},
	"U": {"art": [ART + "urns.png"], "block": true, "radius": 6.0, "shadow": 9.0},
	"H": {"art": [ART + "bone_pile.png"], "block": true, "radius": 6.0},
}

var logic_root: Node2D
var floor_cells: Dictionary = {}
var ground: TileMapLayer
var detail: TileMapLayer
var wall_shade: TileMapLayer
var rock: TileMapLayer
var elevation: TileMapLayer
var glow: FloorGlow
var depth: Node2D
var lights: Node2D
var navigation: AStarGrid2D
var seals: Array[IsoSeal] = []
## Flickering lights (braziers, wall sconces, candles).
var torches: Array[PointLight2D] = []
## cell -> Array[CanvasItem] of tall sprites that may hide Kael (used by the fader).
var occluders: Dictionary = {}
var props_by_cell: Dictionary = {}
var arches: Array[Sprite2D] = []
## Hooks for iso_atmosphere.gd: flames get embers, motes rise at key spots,
## mist pools in some areas. Entries: {"at": Vector2 base, "offset": Vector2, "color": Color}.
var flames: Array[Dictionary] = []
var motes: Array[Dictionary] = []
var mist: Array[Dictionary] = []
var chest_light: PointLight2D
var exit_light: PointLight2D
var camera_bounds: Rect2
var start_position: Vector2
var chest_position: Vector2
var exit_position: Vector2
var glow_texture: ImageTexture
var time: float = 0.0
var textures: Dictionary = {}
var used_rects: Dictionary = {}
var wall_kinds: Dictionary = {}
var decorated: Array[Vector2i] = []
var sconces: Array[Vector2i] = []
var broken_cells: Array[Vector2i] = []
## Screen points lit by moonlight shafts (iso_atmosphere.gd).
var shafts: Array[Vector2] = []

func _ready() -> void:
	name = "CatacumbasIsometricas"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for y in range(Layout.size().y):
		for x in range(Layout.size().x):
			var cell: Vector2i = Vector2i(x, y)
			if is_floor(cell): floor_cells[cell] = true
	start_position = IsoMath.cell_center(Layout.find("K"))
	chest_position = IsoMath.cell_center(Layout.find("C"))
	exit_position = IsoMath.cell_center(Layout.find("E"))
	_compute_camera_bounds()
	var tiles: TileSet = build_tileset()
	ground = _tile_layer("FloorDiamonds", tiles, false)
	detail = _tile_layer("FloorDetail", tiles, false)
	wall_shade = _tile_layer("WallShade", tiles, false)
	# Solid rock the halls are carved into; Y-sorted among itself, always drawn
	# before walls and actors (heights are chosen so it never needs to cover them).
	rock = _tile_layer("RockMass", tiles, true)
	elevation = _tile_layer("RaisedFloor", tiles, true)
	glow = FloorGlow.new()
	glow.name = "FloorGlow"
	add_child(glow)
	depth = Node2D.new()
	depth.name = "DepthSorted"
	depth.y_sort_enabled = true
	add_child(depth)
	lights = Node2D.new()
	lights.name = "Lights"
	add_child(lights)
	_paint_floor()
	_build_walls()
	_build_arches()
	_build_props()
	_build_candles()
	_build_logic()
	_build_area_light()
	var ambient: CanvasModulate = CanvasModulate.new()
	ambient.name = "Ambient"
	# Darker than the first prototype so sconces, runes and the relics carry the scene;
	# Kael keeps his own light (player.gd), so he always stays readable.
	ambient.color = Color(0.64, 0.66, 0.84)
	add_child(ambient)

# --- queries (same contract as dungeon.gd where applicable) -------------------

static func is_floor(cell: Vector2i) -> bool:
	var symbol: String = Layout.char_at(cell)
	return symbol != "#" and symbol != "D"

static func is_walkable(cell: Vector2i) -> bool:
	var symbol: String = Layout.char_at(cell)
	return is_floor(cell) and not Layout.PROP_OBSTACLES.contains(symbol)

func height_at(world: Vector2) -> float:
	return float(Layout.HEIGHTS.get(Layout.char_at(IsoMath.world_to_cell(world)), 0.0))

func room_name(world: Vector2) -> String:
	var cell: Vector2i = IsoMath.world_to_cell(world)
	for region in Layout.REGIONS:
		if Rect2i(region["cells"]).has_point(cell): return String(region["name"])
	return "Catacumbas do Eclipse"

func path_direction(from: Vector2, to: Vector2) -> Vector2:
	var a: Vector2i = IsoMath.world_to_cell(from)
	var b: Vector2i = IsoMath.world_to_cell(to)
	if not navigation.is_in_boundsv(a) or not navigation.is_in_boundsv(b): return Vector2.ZERO
	if navigation.is_point_solid(a) or navigation.is_point_solid(b): return from.direction_to(to)
	var path: PackedVector2Array = navigation.get_point_path(a, b)
	if path.size() > 1: return from.direction_to(path[1])
	return from.direction_to(to)

func set_seals(closed: bool) -> void:
	for seal in seals:
		seal.set_closed(closed)
		for cell in seal.cells: navigation.set_point_solid(cell, closed)

## Swaps the chest art and calms its golden beacon (called by the prototype).
func open_chest() -> void:
	var chest: Sprite2D = props_by_cell.get(IsoMath.world_to_cell(chest_position))
	if chest: chest.texture = _texture(ART + "chest_open.png")
	if chest_light:
		chest_light.color = Color("65dddb")
		chest_light.energy = 0.45

func _glow_texture() -> ImageTexture:
	if glow_texture: return glow_texture
	var image: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var alpha: float = pow(maxf(0.0, 1.0 - Vector2(x - 32, y - 32).length() / 32.0), 2.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	glow_texture = ImageTexture.create_from_image(image)
	return glow_texture

## Diamond TileSet with three atlas sources (floor, wall shade, decals). All regions
## are 32x32 with the ground diamond in the bottom half, hence texture_origin (0, 8).
## Floor tiles also get tinted alternatives (TINTS) for large-scale variation.
static func build_tileset() -> TileSet:
	var tiles: TileSet = TileSet.new()
	tiles.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tiles.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tiles.tile_size = IsoMath.TILE_SIZE
	var files: Array[String] = ["floor_atlas.png", "floor_shade.png", "floor_decals.png"]
	for source in range(files.size()):
		var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
		atlas.texture = load(ART + files[source]) as Texture2D
		atlas.texture_region_size = Vector2i(32, 32)
		tiles.add_source(atlas, source)
		for column in range(atlas.texture.get_width() / 32):
			var coords: Vector2i = Vector2i(column, 0)
			atlas.create_tile(coords)
			atlas.get_tile_data(coords, 0).texture_origin = Vector2i(0, 8)
			if source == SOURCE_DECAL:
				# Mirrored copies (alternatives 1-3) so repeated decals never line up.
				for alternative in range(1, 4):
					atlas.create_alternative_tile(coords, alternative)
					var flipped: TileData = atlas.get_tile_data(coords, alternative)
					flipped.texture_origin = Vector2i(0, 8)
					flipped.flip_h = (alternative & 1) != 0
					flipped.flip_v = (alternative & 2) != 0
			if source != SOURCE_FLOOR: continue
			for alternative in range(1, TINTS.size()):
				atlas.create_alternative_tile(coords, alternative)
				var data: TileData = atlas.get_tile_data(coords, alternative)
				data.texture_origin = Vector2i(0, 8)
				data.modulate = TINTS[alternative]
	# Rock mass: 32x56 regions, base diamond centre 8 px above the bottom (origin 0, 20);
	# alternatives darken it with distance from the halls.
	var rock_atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	rock_atlas.texture = load(ART + "rock_atlas.png") as Texture2D
	rock_atlas.texture_region_size = Vector2i(32, 56)
	tiles.add_source(rock_atlas, SOURCE_ROCK)
	for column in range(rock_atlas.texture.get_width() / 32):
		var coords_r: Vector2i = Vector2i(column, 0)
		rock_atlas.create_tile(coords_r)
		rock_atlas.get_tile_data(coords_r, 0).texture_origin = Vector2i(0, 20)
		for shade in range(1, ROCK_SHADES.size()):
			rock_atlas.create_alternative_tile(coords_r, shade)
			var shaded: TileData = rock_atlas.get_tile_data(coords_r, shade)
			shaded.texture_origin = Vector2i(0, 20)
			shaded.modulate = ROCK_SHADES[shade]
	return tiles

# --- construction: floor ------------------------------------------------------------

func _tile_layer(layer_name: String, tiles: TileSet, sorted: bool) -> TileMapLayer:
	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tiles
	layer.position = IsoMath.TILEMAP_OFFSET
	layer.y_sort_enabled = sorted
	add_child(layer)
	return layer

func _compute_camera_bounds() -> void:
	var bounds: Rect2 = Rect2(IsoMath.cell_to_screen(floor_cells.keys()[0]), Vector2.ZERO)
	for cell in floor_cells: bounds = bounds.expand(IsoMath.cell_to_screen(cell))
	# Room for diamond extents, back-wall height and a little surrounding darkness.
	camera_bounds = Rect2(bounds.position - Vector2(40, 72), bounds.size + Vector2(80, 104))

func _theme(cell: Vector2i) -> Dictionary:
	return THEMES.get(room_name(IsoMath.cell_center(cell)), THEMES["Vestíbulo dos Esquecidos"])

static func _pick(table: Array, roll: int) -> int:
	var total: int = 0
	for entry in table:
		total += int(entry[1])
		if roll < total: return int(entry[0])
	return -1

func _paint_floor() -> void:
	var size: Vector2i = Layout.size()
	var patches: FastNoiseLite = FastNoiseLite.new()
	patches.seed = 11
	patches.frequency = 0.09
	# Void beyond the map is painted far enough to cover the whole camera range, so
	# the catacomb never reads as a floating island.
	var margin: int = 30
	var covered: Rect2 = camera_bounds.grow(32)
	var distances: Dictionary = _floor_distances(ROCK_REACH + 2)
	for y in range(-margin, size.y + margin):
		for x in range(-margin, size.x + margin):
			var cell: Vector2i = Vector2i(x, y)
			var noise: int = _noise(cell)
			var symbol: String = Layout.char_at(cell)
			if not is_floor(cell):
				if covered.has_point(IsoMath.cell_to_screen(cell)): _paint_rock(cell, int(distances.get(cell, 99)), noise)
				continue
			if float(Layout.HEIGHTS.get(symbol, 0.0)) > 0.0:
				var column: int = DAIS[noise % DAIS.size()]
				if symbol == "=": column = STAIRS
				elif symbol == "O" or symbol == "E": column = DAIS_SEAL
				_put(elevation, cell, column)
				if symbol == "O" or symbol == "E":
					glow.seal_cells.append(cell)
					glow.heights[cell] = Layout.HEIGHTS[symbol]
				continue
			var theme: Dictionary = _theme(cell)
			var tint: int = int(theme["tint"])
			var patch: float = patches.get_noise_2d(x, y)
			if patch < -0.32: tint = 1
			elif patch > 0.4: tint = 2
			if symbol == "R":
				_put(ground, cell, FLOOR_RUNE, tint)
				glow.rune_cells.append(cell)
				_add_light(IsoMath.cell_to_screen(cell), Color("6e96d3"), 0.5, 1.4)
			elif symbol == "w":
				_put(ground, cell, FLOOR_WATER[noise % FLOOR_WATER.size()])
				glow.water_cells[cell] = true
			else:
				var special: int = _pick(theme["special"], noise % 100)
				_put(ground, cell, special if special >= 0 else FLOOR_PLAIN[(noise / 100) % FLOOR_PLAIN.size()], tint)
				var decal: int = _pick(theme["decals"], (noise / 7) % 100)
				if decal >= 0 and symbol == ".": detail.set_cell(cell, SOURCE_DECAL, Vector2i(decal, 0), (noise / 1000) % 4)
			var mask: int = 0
			for bit in range(4):
				if not is_floor(cell + [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1)][bit]): mask |= 1 << bit
			if mask: wall_shade.set_cell(cell, SOURCE_SHADE, Vector2i(mask, 0))
	exit_light = _add_light(IsoMath.world_to_screen(exit_position) - Vector2(0, 10), Color("79dedc"), 1.15, 2.6)
	motes.append({"at": IsoMath.world_to_screen(exit_position) - Vector2(0, 6), "color": Color("9ff5ee"), "amount": 14, "radius": 12.0})
	_build_floor_features()

## Chebyshev distance (in cells) from every nearby cell to the closest floor cell.
func _floor_distances(reach: int) -> Dictionary:
	var distances: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for cell: Vector2i in floor_cells:
		distances[cell] = 0
		frontier.append(cell)
	for step in range(1, reach + 1):
		var next: Array[Vector2i] = []
		for cell in frontier:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var other: Vector2i = cell + Vector2i(dx, dy)
					if not distances.has(other):
						distances[other] = step
						next.append(other)
		frontier = next
	return distances

## Solid rock around the halls. Raised as a mass near the floor and darkening with
## distance, so the edges of the map read as rock fading into shadow, not a void.
func _paint_rock(cell: Vector2i, distance: int, noise: int) -> void:
	var shade: int = clampi(distance - 2 + (1 if noise % 5 == 0 else 0), 0, ROCK_SHADES.size() - 1)
	var variant: int = (noise / 3) % ROCK_VARIANTS
	ground.set_cell(cell, SOURCE_ROCK, Vector2i(variant, 0), shade)
	if _wall_kind(cell) != WallKind.NONE or distance > ROCK_REACH: return
	var level: int = _rock_level(cell)
	if level > 0: rock.set_cell(cell, SOURCE_ROCK, Vector2i(level * ROCK_VARIANTS + variant, 0), shade)

## Tallest rock level that never hides gameplay. Two rules, both in screen space:
##  * the rock prism must not reach the base diamond of any floor or wall cell behind
##    it (rock is drawn before the depth layer, so it could not sort in front);
##  * rock in front of a hall (floor above it on screen) is cut to the low-wall height,
##    continuing the cutaway plane of the lowered front walls.
## Rock behind the halls rises to full wall height, so walls read as carved into it.
func _rock_level(cell: Vector2i) -> int:
	var limit: float = 999.0
	var cut: bool = false
	for rows_up in range(1, 13):
		for column in range(-2, 3):
			if (rows_up + column) % 2 != 0: continue
			var other: Vector2i = cell + Vector2i((column - rows_up) / 2, (-rows_up - column) / 2)
			var floor_here: bool = is_floor(other)
			if not floor_here and _wall_kind(other) == WallKind.NONE: continue
			# Screen offset of `other`: dx = 16 * column, dy = -8 * rows_up.
			if absi(column) <= 1 and rows_up <= 7: limit = minf(limit, 8.0 * rows_up - 16.0 + 8.0 * absi(column))
			if floor_here: cut = true
	if cut: limit = minf(limit, float(ROCK_HEIGHTS[1]) + 1.0)
	var level: int = 0
	for k in range(ROCK_HEIGHTS.size()):
		if float(ROCK_HEIGHTS[k]) < limit: level = k
	# Organic dips in the back mass.
	if level == ROCK_HEIGHTS.size() - 1 and _noise(cell) % 6 == 0: level -= 1
	return level

## Points of interest painted on the floor: lunar mosaic, gilded ring around the dais,
## glowing fissures, plus the moonlight shafts used by iso_atmosphere.gd.
func _build_floor_features() -> void:
	var start_cell: Vector2i = Layout.find("K")
	glow.inlays.append({"center": IsoMath.cell_center(start_cell), "radius": 30.0, "kind": "mosaic"})
	glow.inlays.append({"center": Vector2(37, 15) * IsoMath.CELL, "radius": 78.0, "kind": "ring"})
	glow.inlays.append({"center": Vector2(35.5, 39.5) * IsoMath.CELL, "radius": 40.0, "kind": "ring"})
	for path in [
		[Vector2(41.5, 39.3), Vector2(43.5, 40.4), Vector2(46.0, 39.5), Vector2(48.5, 40.5), Vector2(50.5, 39.6)],
		[Vector2(19.2, 13.6), Vector2(21.5, 12.7), Vector2(23.8, 13.9), Vector2(25.2, 13.2)],
		[Vector2(38.2, 21.6), Vector2(40.0, 23.0), Vector2(42.6, 22.3), Vector2(44.5, 23.4)],
	]:
		var points: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in path: points.append(IsoMath.world_to_screen(point * IsoMath.CELL).round())
		glow.cracks.append(points)
	for spot: Vector2 in [Vector2(start_cell) + Vector2(0.5, 0.5), Vector2(37, 15), Vector2(35.5, 39.5), Vector2(53.5, 41.5)]:
		shafts.append(IsoMath.world_to_screen(spot * IsoMath.CELL))

# --- construction: walls and arches ---------------------------------------------------

func _wall_kind(cell: Vector2i) -> int:
	if wall_kinds.has(cell): return wall_kinds[cell]
	var kind: int = WallKind.NONE
	if not is_floor(cell) and _touches_floor(cell):
		if Layout.char_at(cell) == "D": kind = WallKind.POST
		# A wall is a BACK wall (full height) when floor lies in front of it on
		# screen (+x, +y). Front walls are lowered (classic cutaway) so they never
		# hide the room; back walls fade contextually instead.
		elif is_floor(cell + Vector2i(1, 0)) or is_floor(cell + Vector2i(0, 1)) or is_floor(cell + Vector2i(1, 1)): kind = WallKind.FULL
		else: kind = WallKind.LOW
	wall_kinds[cell] = kind
	return kind

func _build_walls() -> void:
	# Pass 1: choose every wall's atlas row (decor, pilasters, collapsed sections).
	var rows: Dictionary = {}
	for y in range(Layout.size().y):
		for x in range(Layout.size().x):
			var cell_r: Vector2i = Vector2i(x, y)
			match _wall_kind(cell_r):
				WallKind.FULL: rows[cell_r] = _full_wall_row(cell_r)
				WallKind.LOW: rows[cell_r] = _low_wall_row(cell_r)
	# Pass 2: sprites. Top rims are drawn only on edges that do not continue into the
	# same kind of intact wall, so runs of walls read as one continuous mass.
	for y in range(Layout.size().y):
		for x in range(Layout.size().x):
			var cell: Vector2i = Vector2i(x, y)
			var kind: int = _wall_kind(cell)
			if kind == WallKind.NONE: continue
			var sprite: Sprite2D
			if kind == WallKind.POST:
				sprite = _block(cell, ART + "door_post.png", true)
				glow.shadows.append([sprite.position, 12.0])
			else:
				var full: bool = kind == WallKind.FULL
				var row: int = rows[cell]
				var mask: int = 0
				for bit in range(4):
					var other: Vector2i = cell + [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1)][bit]
					if _wall_kind(other) == kind and not _is_broken(kind, rows.get(other, -1)) and not _is_broken(kind, row): mask |= 1 << bit
				var height: int = FULL_HEIGHT if full else LOW_HEIGHT
				sprite = _atlas_block(cell, ART + ("wall_full.png" if full else "wall_low.png"), Rect2(mask * 32, row * height, 32, height))
				sprite.set_meta("wall_row", row)
			sprite.name = "Wall_%d_%d" % [x, y]
			if kind != WallKind.LOW: _register_occluder(cell, sprite)
			if kind == WallKind.FULL and sconces.has(cell): _add_sconce(cell, sprite)

## Chooses the atlas row of a back wall: decorations face the room they overlook,
## follow the area theme and are spaced out so they stay special.
func _full_wall_row(cell: Vector2i) -> int:
	var noise: int = _noise(cell)
	var face: int = -1
	if is_floor(cell + Vector2i(0, 1)): face = 0
	elif is_floor(cell + Vector2i(1, 0)): face = 1
	# Outer corner (room on both visible faces): carved corner stones.
	if is_floor(cell + Vector2i(0, 1)) and is_floor(cell + Vector2i(1, 0)): return WALL_ROW["quoin"]
	var facing: Vector2i = Vector2i(0, 1) if face == 0 else (Vector2i(1, 0) if face == 1 else Vector2i(1, 1))
	var theme: Dictionary = _theme(cell + facing)
	# Collapsed sections break long runs in the ruined areas.
	if face >= 0 and (noise / 13) % 100 < int(theme.get("broken", 0)) and not _near(broken_cells, cell, 3) and not _near(decorated, cell, 1):
		broken_cells.append(cell)
		return WALL_ROW["broken"]
	if face >= 0 and noise % 100 < 30 and not _near(decorated, cell, 2):
		var options: Array = theme["walls"]
		var choice: String = String(options[(noise / 100) % options.size()])
		if choice == "sconce" and _near(sconces, cell, 6): choice = "plain"
		if choice != "plain":
			decorated.append(cell)
			if choice == "sconce": sconces.append(cell)
			if choice == "cracked" or choice == "mossy": return WALL_ROW[choice]
			return int(WALL_ROW[choice]) + face
	# Pilasters every few cells give long straight walls a rhythm of bays.
	if (face == 0 and posmod(cell.x, 5) == 2) or (face == 1 and posmod(cell.y, 5) == 2):
		if not _near(decorated, cell, 0): return int(WALL_ROW["pier"]) + face
	if theme["walls"].has("mossy") and noise % 5 == 0: return WALL_ROW["mossy"]
	if theme["walls"].has("cracked") and noise % 6 == 1: return WALL_ROW["cracked"]
	return (noise / 7) % 3

func _low_wall_row(cell: Vector2i) -> int:
	var noise: int = _noise(cell)
	var theme: Dictionary = _theme(cell - Vector2i(1, 1))
	if int(theme.get("broken", 0)) > 0 and noise % 7 == 0: return LOW_ROW["broken"]
	var style: String = String(theme["low"])
	if style != "plain" and noise % 3 == 0: return LOW_ROW[style]
	return noise % 2

static func _is_broken(kind: int, row: int) -> bool:
	return (kind == WallKind.FULL and row == WALL_ROW["broken"]) or (kind == WallKind.LOW and row == LOW_ROW["broken"])

## Wall-mounted lunar flame: light, flicker and embers (iso_atmosphere.gd).
func _add_sconce(cell: Vector2i, wall: Sprite2D) -> void:
	var on_left: bool = int(wall.get_meta("wall_row")) % 2 == 1
	var flame: Vector2 = Vector2(-8.0 if on_left else 8.0, -22.0)
	torches.append(_add_light(wall.position + flame + Vector2(-1.0 if on_left else 1.0, 2.0), Color("71cfdf"), 0.8, 2.0))
	flames.append({"at": wall.position, "offset": flame, "color": Color("9ff5ee")})

## Stone lintels between every pair of door posts: the passages read as arches.
func _build_arches() -> void:
	for y in range(Layout.size().y):
		for x in range(Layout.size().x):
			var post: Vector2i = Vector2i(x, y)
			if Layout.char_at(post) != "D": continue
			for axis: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				for span in range(2, 6):
					var other: Vector2i = post + axis * span
					if Layout.char_at(other) == "D":
						for step in range(1, span):
							var cell: Vector2i = post + axis * step
							var key: bool = step == span / 2
							var art: String = "lintel_%s%s.png" % ["x" if axis.x == 1 else "y", "_key" if key else ""]
							var lintel: Sprite2D = _block(cell, ART + art, true)
							lintel.name = "Arch_%d_%d" % [cell.x, cell.y]
							_register_occluder(cell, lintel)
							arches.append(lintel)
						break
					if not is_floor(other): break

# --- construction: props -------------------------------------------------------------

func _build_props() -> void:
	for y in range(Layout.size().y):
		for x in range(Layout.size().x):
			var cell: Vector2i = Vector2i(x, y)
			var symbol: String = Layout.char_at(cell)
			if not PROPS.has(symbol): continue
			var data: Dictionary = PROPS[symbol]
			var lift: float = float(Layout.HEIGHTS.get(symbol, 0.0))
			var variants: Array = data["art"]
			var art: String = String(variants[_noise(cell) % variants.size()])
			var sprite: Sprite2D
			if data.get("block", false):
				sprite = _block(cell, art, data.get("occluder", false))
			else:
				sprite = Sprite2D.new()
				sprite.texture = _texture(art)
				sprite.scale = Vector2(0.5, 0.5)
				sprite.position = IsoMath.cell_to_screen(cell)
				# Billboard feet (same pivot as dungeon.gd fixtures) on the cell centre.
				sprite.offset = Vector2(0, -48.0 - lift * 2.0)
				depth.add_child(sprite)
			sprite.name = "Prop_%s_%d_%d" % [symbol, x, y]
			props_by_cell[cell] = sprite
			if data.has("shadow"): glow.shadows.append([sprite.position - Vector2(0, lift), float(data["shadow"])])
			if data.get("occluder", false): _register_occluder(cell, sprite)
			var light_at: Vector2 = sprite.position - Vector2(0, float(data.get("light_height", 26.0)) + lift)
			if data.has("light"):
				var light: PointLight2D = _add_light(light_at, data["light"], 0.8, 2.4)
				if data.get("torch", false):
					torches.append(light)
					flames.append({"at": sprite.position, "offset": Vector2(0, -27), "color": Color("9ff5ee")})
			if data.has("motes"): motes.append({"at": light_at, "color": data["motes"], "amount": 8, "radius": 8.0})
	chest_light = _add_light(IsoMath.world_to_screen(chest_position) - Vector2(0, 12), Color("e0bf7a"), 0.75, 1.8)
	motes.append({"at": IsoMath.world_to_screen(chest_position) - Vector2(0, 10), "color": Color("e6d29c"), "amount": 6, "radius": 7.0})

## Small votive candles beside sarcophagi and statues (decor only, walkable).
func _build_candles() -> void:
	var placed: int = 0
	for y in range(Layout.size().y):
		for x in range(Layout.size().x):
			var cell: Vector2i = Vector2i(x, y)
			if placed >= 10 or Layout.char_at(cell) != "." or _noise(cell) % 3 != 0: continue
			var beside: bool = false
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if "XS".contains(Layout.char_at(cell + offset)): beside = true
			if not beside: continue
			var noise: int = _noise(cell)
			var candles: Sprite2D = Sprite2D.new()
			candles.name = "Candles_%d_%d" % [x, y]
			candles.texture = _texture(ART + "candles.png")
			candles.centered = false
			candles.offset = Vector2(-8, -12)
			candles.position = IsoMath.cell_to_screen(cell) + Vector2(float(noise % 7) - 3.0, float((noise / 7) % 5) - 2.0)
			depth.add_child(candles)
			torches.append(_add_light(candles.position - Vector2(0, 6), Color("bfeff0"), 0.35, 0.7))
			placed += 1

## Large, faint coloured fills give each area its own mood without hiding anything.
func _build_area_light() -> void:
	var moods: Dictionary = {
		"Câmara do Eclipse": [Color("5b4b9a"), 0.35],
		"Ossário Lunar": [Color("6a4a8c"), 0.4],
		"Ruínas Submersas": [Color("2f7d85"), 0.4],
		"Passagem das Cinzas": [Color("43507a"), 0.25],
	}
	for region in Layout.REGIONS:
		var area: String = String(region["name"])
		var cells: Rect2i = region["cells"]
		var center: Vector2 = IsoMath.world_to_screen((Vector2(cells.position) + Vector2(cells.size) * 0.5) * IsoMath.CELL)
		if moods.has(area): _add_light(center, moods[area][0], moods[area][1], 9.0).name = "Mood_" + area
		if area == "Ruínas Submersas" or area == "Ossário Lunar" or area == "Fenda Colapsada":
			mist.append({"at": center, "color": Color("4fb3b0") if area != "Ossário Lunar" else Color("7d5aa6"), "size": Vector2(cells.size) * 6.0})

# --- helpers ------------------------------------------------------------------------

func _texture(path: String) -> Texture2D:
	if not textures.has(path): textures[path] = load(path) as Texture2D
	return textures[path]

## Block sprite whose base diamond centre (8 px above the image bottom) sits on the
## cell centre. `crop` trims transparent margins (tight occluder rects for the fader).
func _block(cell: Vector2i, art: String, crop: bool = false) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = _texture(art)
	sprite.centered = false
	sprite.offset = Vector2(-16, -(sprite.texture.get_height() - 8))
	if crop:
		if not used_rects.has(art): used_rects[art] = sprite.texture.get_image().get_used_rect()
		var used: Rect2i = used_rects[art]
		sprite.region_enabled = true
		sprite.region_rect = Rect2(used)
		sprite.offset += Vector2(used.position)
	sprite.position = IsoMath.cell_to_screen(cell)
	depth.add_child(sprite)
	return sprite

func _atlas_block(cell: Vector2i, art: String, region: Rect2) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = _texture(art)
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.offset = Vector2(-16, -(region.size.y - 8))
	sprite.position = IsoMath.cell_to_screen(cell)
	depth.add_child(sprite)
	return sprite

func _register_occluder(cell: Vector2i, item: CanvasItem) -> void:
	if not occluders.has(cell): occluders[cell] = []
	occluders[cell].append(item)

func _build_logic() -> void:
	var walls: StaticBody2D = StaticBody2D.new()
	walls.name = "WallCollision"
	walls.collision_layer = 1
	walls.collision_mask = 0
	logic_root.add_child(walls)
	# Solid cells merged into horizontal runs: far fewer shapes, no seams.
	for y in range(Layout.size().y):
		var run_start: int = -1
		for x in range(Layout.size().x + 1):
			var solid: bool = x < Layout.size().x and not is_floor(Vector2i(x, y))
			if solid and run_start < 0: run_start = x
			elif not solid and run_start >= 0:
				_add_box(walls, Vector2((run_start + x) * 0.5, y + 0.5) * IsoMath.CELL, Vector2((x - run_start) * IsoMath.CELL, IsoMath.CELL))
				run_start = -1
	var props: StaticBody2D = StaticBody2D.new()
	props.name = "PropCollision"
	props.collision_layer = 1
	props.collision_mask = 0
	logic_root.add_child(props)
	for cell in props_by_cell:
		var data: Dictionary = PROPS[Layout.char_at(cell)]
		if data.has("box"):
			_add_box(props, IsoMath.cell_center(cell), Vector2.ONE * float(data["box"]))
		elif data.has("radius"):
			var shape: CollisionShape2D = CollisionShape2D.new()
			var circle: CircleShape2D = CircleShape2D.new()
			circle.radius = float(data["radius"])
			shape.shape = circle
			shape.position = IsoMath.cell_center(cell)
			props.add_child(shape)
	for seal_cells in Layout.SEALS:
		var seal: IsoSeal = IsoSeal.new()
		seal.name = "Seal%d" % seals.size()
		logic_root.add_child(seal)
		seal.setup(seal_cells, depth)
		seals.append(seal)
		glow.thresholds.append(seal.threshold())
	navigation = AStarGrid2D.new()
	navigation.region = Rect2i(Vector2i.ZERO, Layout.size())
	navigation.cell_size = Vector2(IsoMath.CELL, IsoMath.CELL)
	navigation.offset = Vector2(IsoMath.CELL, IsoMath.CELL) * 0.5
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for y in range(Layout.size().y):
		for x in range(Layout.size().x):
			navigation.set_point_solid(Vector2i(x, y), not is_walkable(Vector2i(x, y)))

func _add_box(body: StaticBody2D, center: Vector2, size: Vector2) -> void:
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	shape.position = center
	body.add_child(shape)

func _add_light(at: Vector2, ink: Color, energy: float, radius_scale: float) -> PointLight2D:
	var light: PointLight2D = PointLight2D.new()
	light.position = at
	light.texture = _glow_texture()
	light.texture_scale = radius_scale
	light.color = ink
	light.energy = energy
	lights.add_child(light)
	return light

func _touches_floor(cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if is_floor(cell + Vector2i(dx, dy)): return true
	return false

static func _near(cells: Array[Vector2i], cell: Vector2i, distance: int) -> bool:
	for other in cells:
		if absi(other.x - cell.x) <= distance and absi(other.y - cell.y) <= distance: return true
	return false

func _put(layer: TileMapLayer, cell: Vector2i, column: int, alternative: int = 0) -> void:
	layer.set_cell(cell, SOURCE_FLOOR, Vector2i(column, 0), alternative)

static func _noise(cell: Vector2i) -> int:
	return ((cell.x * 73856093) ^ (cell.y * 19349663)) & 0x7fffffff

func _process(delta: float) -> void:
	time += delta
	for i in range(torches.size()):
		var light: PointLight2D = torches[i]
		if not light.has_meta("base"): light.set_meta("base", light.energy)
		light.energy = float(light.get_meta("base")) * (1.0 + sin(time * 4.0 + i * 2.3) * 0.08 + sin(time * 11.0 + i) * 0.03)
	if chest_light and chest_light.color != Color("65dddb"): chest_light.energy = 0.7 + sin(time * 2.2) * 0.15
	if exit_light: exit_light.energy = 1.1 + sin(time * 1.6) * 0.12
