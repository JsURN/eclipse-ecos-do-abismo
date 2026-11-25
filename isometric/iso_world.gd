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
## Collaborators (stage 4), one responsibility each:
##   iso_region_style.gd   per-area art direction (data)
##   iso_architecture.gd   wall variant selection rules
##   iso_abyss.gd          terraces stepping down into the deep rock (drawn first)
##   iso_lighting.gd       ambient / architectural / interest lights and floor pools
const IsoMath = preload("res://isometric/iso_math.gd")
const Layout = preload("res://isometric/catacomb_layout.gd")
const IsoSeal = preload("res://isometric/iso_seal.gd")
const FloorGlow = preload("res://isometric/iso_floor_glow.gd")
const RegionStyle = preload("res://isometric/iso_region_style.gd")
const Architecture = preload("res://isometric/iso_architecture.gd")
const Abyss = preload("res://isometric/iso_abyss.gd")
const Lighting = preload("res://isometric/iso_lighting.gd")
const Portal = preload("res://isometric/iso_portal.gd")
const Tier = Lighting.Tier

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
const FULL_HEIGHT: int = 56
const LOW_HEIGHT: int = 28
enum WallKind { NONE, LOW, FULL, POST }
## Area art direction lives in iso_region_style.gd (RegionStyle.THEMES).
## Prop table. "block" = isometric sprite whose base diamond sits on the cell (one
## variant picked per cell); otherwise a front-facing billboard reused from the
## top-down slice. Collision: "radius" (circle) or "box" (square side), world units.
const PROPS: Dictionary = {
	"P": {"art": [ART + "pillar_a.png", ART + "pillar_b.png"], "block": true, "radius": 7.0, "occluder": true, "shadow": 11.0},
	"~": {"art": [ART + "wall_broken_a.png", ART + "wall_broken_b.png"], "block": true, "box": 16.0, "occluder": true},
	"X": {"art": [ART + "sarcophagus.png"], "block": true, "box": 14.0, "shadow": 13.0},
	"C": {"art": [ART + "chest_closed.png"], "block": true, "box": 14.0, "shadow": 10.0},
	"Q": {"art": [ART + "pedestal.png"], "block": true, "radius": 6.0, "light": Color("65dddb"), "light_height": 26.0, "shadow": 10.0, "motes": Color("8ff2ea"), "tier": Tier.INTEREST, "pool": 32.0},
	"S": {"art": [ART + "statue.png"], "block": true, "radius": 7.0, "occluder": true, "shadow": 11.0},
	"T": {"art": [ART + "brazier.png"], "block": true, "radius": 4.0, "light": Color("71cfdf"), "light_height": 22.0, "torch": true, "flame": 17.0, "shadow": 6.0, "tier": Tier.ARCHITECTURAL, "pool": 64.0},
	"A": {"art": [ART + "altar.png"], "block": true, "radius": 7.0, "shadow": 12.0, "light": Color("9674d6"), "motes": Color("c7a2e6"), "tier": Tier.INTEREST, "energy": 1.0, "light_scale": 2.8, "pool": 96.0},
	"c": {"art": [ART + "crystal.png"], "block": true, "radius": 5.0, "light": Color("9674d6"), "shadow": 6.0},
	"r": {"art": [ART + "rubble.png"], "block": true, "radius": 5.0, "shadow": 9.0},
	# B (bones) is a walkable floor decal now (see _paint_floor), not a standing sprite.
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
var lights: Lighting
var abyss: Abyss
var architecture: Architecture
## Floor light pools (iso_lighting.gd), between the floor and the depth layer.
var light_pools: Node2D
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
var chest_pool: Sprite2D
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
## Floor torch cell -> wall cell that carries it as a sconce instead (_plan_wall_torches).
var wall_torches: Dictionary = {}
## Arched portals (_plan_portals): post cell / passage cell -> [axis, n, k, ruined],
## k = -1 low pylon, 0..n-1 passage cells, n high pylon (iso_portal.gd).
var portal_posts: Dictionary = {}
var portal_cells: Dictionary = {}
var portal_images: Dictionary = {}
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
	architecture = Architecture.new(self)
	# The abyss is drawn first: every floor, rock and wall layer covers it.
	abyss = Abyss.new()
	abyss.setup(self, _texture(ART + "rock_atlas.png"), _texture(ART + "abyss_faces.png"))
	add_child(abyss)
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
	light_pools = Node2D.new()
	light_pools.name = "LightPools"
	add_child(light_pools)
	depth = Node2D.new()
	depth.name = "DepthSorted"
	depth.y_sort_enabled = true
	add_child(depth)
	lights = Lighting.new()
	lights.setup(_glow_texture(), light_pools)
	add_child(lights)
	_paint_floor()
	_plan_wall_torches()
	_plan_portals()
	_build_walls()
	_build_arches()
	_build_props()
	_build_candles()
	_build_logic()
	_build_area_light()
	var ambient: CanvasModulate = CanvasModulate.new()
	ambient.name = "Ambient"
	# Ambient tier: dark enough that sconces, runes and relics carry the scene (light
	# hierarchy), never so dark that floor and walls stop reading. Kael keeps his own
	# light (player.gd), so he always stays readable.
	ambient.color = Color(0.6, 0.62, 0.8)
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
		chest_light.set_meta("still", true)
	if chest_pool: chest_pool.modulate = Color(Color("65dddb"), 0.1)

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
	return RegionStyle.theme(room_name(IsoMath.cell_center(cell)))

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
	var distances: Dictionary = _floor_distances(ROCK_REACH + Abyss.DEPTHS.size() + 1)
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
				lights.add(IsoMath.cell_to_screen(cell), Color("6e96d3"), 0.5, 1.4, Tier.INTEREST)
			elif symbol == "w":
				_put(ground, cell, FLOOR_WATER[noise % FLOOR_WATER.size()])
				glow.water_cells[cell] = true
			else:
				var special: int = _pick(theme["special"], noise % 100)
				# Built, cared-for areas are paved on a regular checkerboard of two slab
				# layouts; the rest uses random flagstones.
				var plain: int = FLOOR_PLAIN[(noise / 100) % FLOOR_PLAIN.size()]
				if theme["ordered"]: plain = FLOOR_PLAIN[0] if (x + y) % 2 == 0 else FLOOR_PLAIN[4]
				_put(ground, cell, special if special >= 0 else plain, tint)
				var decal: int = _pick(theme["decals"], (noise / 7) % 100)
				if decal >= 0 and symbol == ".": detail.set_cell(cell, SOURCE_DECAL, Vector2i(decal, 0), (noise / 1000) % 4)
				# Bones lie flat on the floor (decal) instead of a front-facing standing sprite.
				if symbol == "B": detail.set_cell(cell, SOURCE_DECAL, Vector2i(4, 0), (noise / 1000) % 4)
			var mask: int = 0
			for bit in range(4):
				if not is_floor(cell + [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1)][bit]): mask |= 1 << bit
			if mask: wall_shade.set_cell(cell, SOURCE_SHADE, Vector2i(mask, 0))
	exit_light = lights.add(IsoMath.world_to_screen(exit_position) - Vector2(0, 10), Color("79dedc"), 1.15, 2.6, Tier.INTEREST)
	lights.add_pool(IsoMath.world_to_screen(exit_position) - Vector2(0, 6), Color("79dedc"), 96.0, 0.22)
	motes.append({"at": IsoMath.world_to_screen(exit_position) - Vector2(0, 6), "color": Color("9ff5ee"), "amount": 14, "radius": 12.0})
	# Moon seals on the chamber dais: the ritual centre of the arena.
	for seal_cell: Vector2i in glow.seal_cells:
		if Layout.char_at(seal_cell) == "O": lights.add_pool(IsoMath.cell_to_screen(seal_cell) - Vector2(0, 6), Color("9fb8f0"), 48.0, 0.14)
	abyss.build()
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
	# Beyond the (irregular) shelf the rock breaks into terraces drawn by iso_abyss.gd.
	var in_front: bool = distance >= 3 and distance <= ROCK_REACH and _in_front_of_hall(cell)
	if abyss.classify(cell, distance, noise, ROCK_REACH, in_front): return
	var shade: int = clampi(distance - 2 + (1 if noise % 5 == 0 else 0), 0, ROCK_SHADES.size() - 1)
	var variant: int = (noise / 3) % ROCK_VARIANTS
	ground.set_cell(cell, SOURCE_ROCK, Vector2i(variant, 0), shade)
	# Raised mass only close to the halls (it frames the walls); farther out the shelf
	# stays low and hands over to the abyss terraces instead of ending in dark towers.
	if _wall_kind(cell) != WallKind.NONE or distance > ROCK_REACH - 3: return
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

## Tile-aligned crack decals along a path of cells (see _build_floor_features).
func _fault_line(path: Array, seep: int) -> void:
	var visited: Dictionary = {}
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		for k in range(int(a.distance_to(b) * 2.0) + 1):
			var cell: Vector2i = Vector2i(a.lerp(b, k / maxf(1.0, a.distance_to(b) * 2.0)).floor())
			if visited.has(cell) or Layout.char_at(cell) != ".": continue
			visited[cell] = true
			var decal: int = seep if visited.size() % 3 == 0 else 0
			detail.set_cell(cell, SOURCE_DECAL, Vector2i(decal, 0), _noise(cell) % 4)

## True when a hall lies behind `cell` on screen (same probe as _rock_level's cut rule).
func _in_front_of_hall(cell: Vector2i) -> bool:
	for rows_up in range(1, 13):
		for column in range(-2, 3):
			if (rows_up + column) % 2 != 0: continue
			if is_floor(cell + Vector2i((column - rows_up) / 2, (-rows_up - column) / 2)): return true
	return false

## Points of interest painted on the floor: lunar mosaic, gilded ring around the dais,
## glowing fissures, plus the moonlight shafts used by iso_atmosphere.gd.
func _build_floor_features() -> void:
	var start_cell: Vector2i = Layout.find("K")
	glow.inlays.append({"center": IsoMath.cell_center(start_cell), "radius": 30.0, "kind": "mosaic"})
	glow.inlays.append({"center": Vector2(37, 15) * IsoMath.CELL, "radius": 78.0, "kind": "ring"})
	# Eclipse corona engraved around the dais: the ritual heart of the arena.
	glow.inlays.append({"center": Vector2(37, 15) * IsoMath.CELL, "radius": 70.0, "kind": "corona"})
	glow.inlays.append({"center": Vector2(35.5, 39.5) * IsoMath.CELL, "radius": 40.0, "kind": "ring"})
	# Fault lines: instead of long free-hand strokes (which read as scribbles), the
	# cells along each path get tile-aligned crack decals, with a mark of what seeps out
	# every few cells (corruption in the rift and the chamber, soot in the ash corridor).
	for entry in [
		[[Vector2(41.5, 39.3), Vector2(43.5, 40.4), Vector2(46.0, 39.5), Vector2(48.5, 40.5), Vector2(50.5, 39.6)], 5],
		[[Vector2(19.2, 13.6), Vector2(21.5, 12.7), Vector2(23.8, 13.9), Vector2(25.2, 13.2)], 7],
		[[Vector2(38.2, 21.6), Vector2(40.0, 23.0), Vector2(42.6, 22.3), Vector2(44.5, 23.4)], 5],
	]:
		_fault_line(entry[0], int(entry[1]))
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
				WallKind.FULL: rows[cell_r] = architecture.full_row(cell_r)
				WallKind.LOW: rows[cell_r] = architecture.low_row(cell_r)
	# Pass 2: sprites. Top rims are drawn only on edges that do not continue into the
	# same kind of intact wall, so runs of walls read as one continuous mass.
	for y in range(Layout.size().y):
		for x in range(Layout.size().x):
			var cell: Vector2i = Vector2i(x, y)
			var kind: int = _wall_kind(cell)
			if kind == WallKind.NONE: continue
			var sprite: Sprite2D
			if kind == WallKind.POST:
				# Door posts are the pylons of their portal (a lone post keeps the old art).
				sprite = _portal_piece(cell, portal_posts[cell]) if portal_posts.has(cell) else _block(cell, ART + "door_post.png", true)
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

## Most floor torches become wall sconces: a free-standing torch only stays where it
## frames something (within 2 cells of the relic chest, the altar or a door post).
## Each moved torch hangs on the nearest back wall that faces the room (not a corner,
## not beside a door post); its cell keeps a waystone, so collision is unchanged.
func _plan_wall_torches() -> void:
	for y in range(Layout.size().y):
		for x in range(Layout.size().x):
			var torch: Vector2i = Vector2i(x, y)
			if Layout.char_at(torch) != "T" or _frames_feature(torch): continue
			var best: Vector2i = Vector2i(-1, -1)
			var best_score: int = 1 << 30
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var wall: Vector2i = torch + Vector2i(dx, dy)
					if _wall_kind(wall) != WallKind.FULL or architecture._beside_post(wall) or architecture.forced.has(wall): continue
					var below: bool = is_floor(wall + Vector2i(0, 1))
					var right: bool = is_floor(wall + Vector2i(1, 0))
					if below == right: continue
					var score: int = (absi(dx) + absi(dy)) * 100 + _noise(wall) % 100
					if score < best_score:
						best_score = score
						best = wall
			if best.x < 0: continue
			architecture.forced[best] = true
			wall_torches[torch] = best

func _frames_feature(cell: Vector2i) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if "CAD".contains(Layout.char_at(cell + Vector2i(dx, dy))): return true
	return false

## Variant rules live in iso_architecture.gd; this only tells broken rows apart.
static func _is_broken(kind: int, row: int) -> bool:
	if kind != WallKind.FULL and kind != WallKind.LOW: return false
	return Architecture.is_broken_row(kind == WallKind.FULL, row)

## Wall-mounted lunar flame: light, flicker, embers (iso_atmosphere.gd) and a pool of
## light on the floor in front of the wall it hangs on.
func _add_sconce(cell: Vector2i, wall: Sprite2D) -> void:
	var on_left: bool = int(wall.get_meta("wall_row")) % 2 == 1
	var flame: Vector2 = Vector2(-8.0 if on_left else 8.0, -27.0)
	# Animated flame over the bracket; the light sits just in front of it so it washes
	# the stone around the sconce and the floor at the foot of the wall.
	lights.add_flame(wall, Vector2(-8.0 if on_left else 8.0, -19.0), false)
	torches.append(lights.add(wall.position + flame + Vector2(-2.0 if on_left else 2.0, 4.0), Color("71cfdf"), 0.95, 2.3, Tier.ARCHITECTURAL))
	var front: Vector2i = cell + (Vector2i(0, 1) if on_left else Vector2i(1, 0))
	lights.add_pool(IsoMath.cell_to_screen(front), Color("71cfdf"), 64.0, 0.14)
	flames.append({"at": wall.position, "offset": flame, "color": Color("9ff5ee")})

## Every pair of door posts facing each other across a passage becomes an arched
## portal (iso_portal.gd geometry, sprites from portal_{x,y}.png): the posts are its
## pylons and each passage cell gets the slice of the voussoir ring above it, so the
## ring is one continuous arch while every slice still y-sorts with the actors. In
## areas that are falling apart (RegionStyle "broken" > 0) the ring has collapsed and
## only the springers remain; the entrance gate stays intact.
func _plan_portals() -> void:
	for y in range(Layout.size().y):
		for x in range(Layout.size().x):
			var post: Vector2i = Vector2i(x, y)
			if Layout.char_at(post) != "D": continue
			for axis: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				for span in range(2, 6):
					var other: Vector2i = post + axis * span
					if Layout.char_at(other) == "D":
						var n: int = span - 1
						if not Portal.SPANS.has(n): break
						var ruined: bool = _ruined_arch(post + axis * (span / 2), axis)
						portal_posts[post] = [axis, n, -1, ruined]
						portal_posts[other] = [axis, n, n, ruined]
						for step in range(1, span): portal_cells[post + axis * step] = [axis, n, step - 1, ruined]
						break
					if not is_floor(other): break

func _build_arches() -> void:
	var rings: Dictionary = {}
	for cell: Vector2i in portal_cells:
		var info: Array = portal_cells[cell]
		var piece: Sprite2D = _portal_piece(cell, info)
		if piece == null: continue  # collapsed crown: nothing left above this cell
		piece.name = "Arch_%d_%d" % [cell.x, cell.y]
		piece.set_meta("portal", {"n": info[1], "k": info[2], "ruined": info[3]})
		_register_occluder(cell, piece)
		arches.append(piece)
		var low_post: Vector2i = cell - Vector2i(info[0]) * (int(info[2]) + 1)
		if not rings.has(low_post): rings[low_post] = []
		rings[low_post].append(piece)
	# The slices of one ring fade together (iso_occlusion_fader.gd), so the arch never
	# shows a half-transparent seam while Kael walks under it.
	for low_post: Vector2i in rings:
		for piece: Sprite2D in rings[low_post]: piece.set_meta("fade_group", rings[low_post])

## Sprite of one portal piece, cropped to its opaque pixels (tight occluder rect).
## Returns null when the piece is empty (above the gap of a collapsed ring).
func _portal_piece(cell: Vector2i, info: Array) -> Sprite2D:
	var art: String = ART + ("portal_x.png" if Vector2i(info[0]).x == 1 else "portal_y.png")
	var region: Rect2i = Portal.region(int(info[1]), int(info[2]), bool(info[3]))
	var key: String = "%s %s" % [art, region]
	if not used_rects.has(key):
		if not portal_images.has(art): portal_images[art] = _texture(art).get_image()
		used_rects[key] = (portal_images[art] as Image).get_region(region).get_used_rect()
	var used: Rect2i = used_rects[key]
	if used.size.x == 0 or used.size.y == 0: return null
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = _texture(art)
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Rect2i(region.position + used.position, used.size))
	sprite.offset = Vector2(-16, -(region.size.y - 8)) + Vector2(used.position)
	sprite.position = IsoMath.cell_to_screen(cell)
	depth.add_child(sprite)
	return sprite

## Fits each seal curtain to its arch: the energy fills the opening up to just under
## the intrados instead of a flat 34 px pane that would poke through the voussoirs.
## A seal standing one cell before or after its arch (the gallery's) takes the shape
## of that arch as well, so it reads as the opening's lunar membrane.
func _fit_seal(seal: IsoSeal) -> void:
	var tops: Array = []
	var across: Vector2i = Vector2i(seal.along.y, seal.along.x)
	for cell: Vector2i in seal.cells:
		var samples: PackedFloat32Array = PackedFloat32Array()
		var info: Array = portal_cells.get(cell, portal_cells.get(cell - across, portal_cells.get(cell + across, [])))
		for j in range(9):
			if info.is_empty(): samples.append(IsoSeal.CURTAIN_HEIGHT)
			else: samples.append(Portal.intrados(int(info[1]), 16.0 * int(info[2]) + j * 2.0) - 2.0)
		tops.append(samples)
	seal.fit_opening(tops)

func _ruined_arch(middle: Vector2i, axis: Vector2i) -> bool:
	if int(_theme(middle)["broken"]) <= 0: return false
	var across: Vector2i = Vector2i(axis.y, axis.x)
	for side: Vector2i in [across, -across]:
		if room_name(IsoMath.cell_center(middle + side)) == RegionStyle.DEFAULT: return false
	return true

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
			# A floor torch moved onto the wall leaves a carved waystone (same collision).
			var moved_torch: bool = symbol == "T" and wall_torches.has(cell)
			if moved_torch: art = ART + "marker.png"
			var sprite: Sprite2D
			if data.get("block", false):
				sprite = _block(cell, art, data.get("occluder", false))
				sprite.offset.y -= lift
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
			if data.has("light") and not moved_torch:
				# Braziers are architectural light; altar and pedestals are points of
				# interest (stronger, slow pulse, floor pool in their signature colour).
				var tier: int = int(data.get("tier", Tier.AMBIENT))
				var light: PointLight2D = lights.add(light_at, data["light"], float(data.get("energy", 0.8)), float(data.get("light_scale", 2.4)), tier)
				if data.has("pool"): lights.add_pool(sprite.position - Vector2(0, lift), data["light"], float(data["pool"]), 0.16 if tier == Tier.INTEREST else 0.11)
				if data.get("torch", false):
					torches.append(light)
					var bowl: float = float(data.get("flame", 17.0))
					lights.add_flame(sprite, Vector2(0, -bowl), true)
					flames.append({"at": sprite.position, "offset": Vector2(0, -bowl - 10.0), "color": Color("9ff5ee")})
			if data.has("motes"): motes.append({"at": light_at, "color": data["motes"], "amount": 8, "radius": 8.0})
	chest_light = lights.add(IsoMath.world_to_screen(chest_position) - Vector2(0, 12), Color("e0bf7a"), 0.75, 1.8, Tier.INTEREST)
	chest_pool = lights.add_pool(IsoMath.world_to_screen(chest_position), Color("e0bf7a"), 48.0, 0.18)
	motes.append({"at": IsoMath.world_to_screen(chest_position) - Vector2(0, 10), "color": Color("e6d29c"), "amount": 6, "radius": 7.0})

## Small votive candles beside sarcophagi and statues (decor only, walkable).
func _build_candles() -> void:
	# Budget per area (RegionStyle "candles"): the crypt glows with votives, the
	# corridors of fire and ruin have none.
	var placed: Dictionary = {}
	for y in range(Layout.size().y):
		for x in range(Layout.size().x):
			var cell: Vector2i = Vector2i(x, y)
			if Layout.char_at(cell) != "." or _noise(cell) % 3 != 0: continue
			var area: String = room_name(IsoMath.cell_center(cell))
			if int(placed.get(area, 0)) >= int(RegionStyle.theme(area)["candles"]): continue
			var beside: bool = false
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if "XS".contains(Layout.char_at(cell + offset)): beside = true
			if not beside: continue
			var noise: int = _noise(cell)
			var candles: Sprite2D = Sprite2D.new()
			candles.name = "Candles_%d_%d" % [x, y]
			candles.texture = _texture(ART + "candles.png")
			candles.hframes = 4
			lights.animate(candles, 4, 6.0)
			candles.centered = false
			candles.offset = Vector2(-8, -12)
			candles.position = IsoMath.cell_to_screen(cell) + Vector2(float(noise % 7) - 3.0, float((noise / 7) % 5) - 2.0)
			depth.add_child(candles)
			torches.append(lights.add(candles.position - Vector2(0, 6), Color("bfeff0"), 0.35, 0.7, Tier.ARCHITECTURAL))
			lights.add_pool(candles.position, Color("bfeff0"), 16.0, 0.08)
			placed[area] = int(placed.get(area, 0)) + 1

## Ambient tier: one large, faint coloured fill per area (RegionStyle "mood") gives each
## area its own temperature without lighting it evenly; ground fog where it is damp;
## and a few slow banks of haze over the deep terraces of the abyss.
func _build_area_light() -> void:
	for region in Layout.REGIONS:
		var area: String = String(region["name"])
		var cells: Rect2i = region["cells"]
		var style: Dictionary = RegionStyle.theme(area)
		var center: Vector2 = IsoMath.world_to_screen((Vector2(cells.position) + Vector2(cells.size) * 0.5) * IsoMath.CELL)
		if style["mood"] != null: lights.add(center, style["mood"][0], float(style["mood"][1]), 9.0, Tier.AMBIENT).name = "Mood_" + area
		if style["mist"] != null: mist.append({"at": center, "color": style["mist"], "size": Vector2(cells.size) * 6.0})
	var banks: int = 0
	for cell: Vector2i in abyss.steps:
		if banks >= 6 or int(abyss.steps[cell]) < 4 or _noise(cell) % 89 != 0: continue
		mist.append({"at": IsoMath.cell_to_screen(cell) + Vector2(0, abyss.depth(cell)), "color": Color("3a4a86"), "size": Vector2(110, 110)})
		banks += 1

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
		_fit_seal(seal)
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

## Flicker and pulses are animated by iso_lighting.gd (Lights node).
