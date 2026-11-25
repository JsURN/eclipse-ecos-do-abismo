extends RefCounted
## Chooses the architectural variant (wall atlas row) of every wall cell. Purely visual
## and deterministic: the same layout always yields the same walls, and nothing here
## touches collision or navigation.
##
## Rules, in priority order, for a BACK wall (full height, facing a room):
##  1. outer corners get carved corner stones (quoin);
##  2. collapsed sections in ruined areas (RegionStyle "broken"), spaced apart;
##  3. walls next to door posts stay plain: junctions with arches read clearly;
##  4. the area's SIGNATURE (relief, inscription, loculi...) on a regular rhythm between
##     pilasters, so it reads as built, not sprinkled;
##  5. other area decorations (banners, sconces, runes...), spaced out;
##  6. pilasters on long walls (RegionStyle "pier");
##  7. damp walls near water seep; then wear (displaced/cracked) and moss by area profile;
##  8. otherwise one of the plain masonry rows.
const IsoMath = preload("res://isometric/iso_math.gd")
const Layout = preload("res://isometric/catacomb_layout.gd")
const RegionStyle = preload("res://isometric/iso_region_style.gd")

## Wall atlas rows (tools/build_iso_art.gd FULL_ROWS / LOW_ROWS). Decorations that sit
## on one face have an _L (+y face) row followed by its _R (+x face) row.
const WALL_ROW: Dictionary = {"plain": 0, "cracked": 3, "mossy": 4, "rune": 5, "banner": 7, "sconce": 9, "niche": 11, "pier": 13, "quoin": 15, "broken": 16,
	"displaced": 17, "scorched": 18, "relief": 19, "loculi": 21, "seep": 23, "inscription": 24}
const FACED: Array[String] = ["rune", "banner", "sconce", "niche", "pier", "relief", "loculi", "inscription"]
const LOW_ROW: Dictionary = {"plain": 0, "cracked": 2, "mossy": 3, "broken": 4, "scorched": 5, "displaced": 6}

var world: Node
var damp: Dictionary = {}
## Wall cells that must carry a sconce (floor torches moved onto the wall, iso_world.gd).
var forced: Dictionary = {}

func _init(world_node: Node) -> void:
	world = world_node
	# Cells within two steps of shallow water count as damp.
	for y in range(Layout.size().y):
		for x in range(Layout.size().x):
			if Layout.char_at(Vector2i(x, y)) != "w": continue
			for dy in range(-2, 3):
				for dx in range(-2, 3): damp[Vector2i(x + dx, y + dy)] = true

func full_row(cell: Vector2i) -> int:
	var noise: int = world._noise(cell)
	var below: bool = world.is_floor(cell + Vector2i(0, 1))
	var right: bool = world.is_floor(cell + Vector2i(1, 0))
	if below and right: return WALL_ROW["quoin"]
	var face: int = 0 if below else (1 if right else -1)
	if forced.has(cell) and face >= 0:
		world.decorated.append(cell)
		world.sconces.append(cell)
		return int(WALL_ROW["sconce"]) + face
	var facing: Vector2i = Vector2i(0, 1) if face == 0 else (Vector2i(1, 0) if face == 1 else Vector2i(1, 1))
	var theme: Dictionary = RegionStyle.theme(world.room_name(IsoMath.cell_center(cell + facing)))
	# Position along the wall run, used for rhythms (bays between pilasters).
	var along: int = cell.x if face == 0 else cell.y
	if face >= 0 and (noise / 13) % 100 < int(theme["broken"]) and not world._near(world.broken_cells, cell, 3) and not world._near(world.decorated, cell, 1):
		world.broken_cells.append(cell)
		return WALL_ROW["broken"]
	if face < 0 or _beside_post(cell): return _surface(cell, theme, noise)
	var pier: int = int(theme["pier"])
	var signature: String = String(theme["signature"])
	var spacing: int = pier if pier > 0 else 5
	if FACED.has(signature) and posmod(along, spacing) == 0 and not world._near(world.decorated, cell, 1):
		world.decorated.append(cell)
		return int(WALL_ROW[signature]) + face
	if noise % 100 < 28 and not world._near(world.decorated, cell, 2):
		var options: Array = theme["walls"]
		var choice: String = String(options[(noise / 100) % options.size()])
		if choice == "sconce" and world._near(world.sconces, cell, 6): choice = "plain"
		if FACED.has(choice):
			world.decorated.append(cell)
			if choice == "sconce": world.sconces.append(cell)
			return int(WALL_ROW[choice]) + face
		if choice != "plain": return WALL_ROW[choice]
	if pier > 0 and posmod(along, pier) == pier / 2 and not world._near(world.decorated, cell, 0):
		return int(WALL_ROW["pier"]) + face
	if not FACED.has(signature) and noise % 100 < 45: return WALL_ROW[signature]
	return _surface(cell, theme, noise)

## Undecorated masonry: damp near water, otherwise worn or mossy by the area profile.
func _surface(cell: Vector2i, theme: Dictionary, noise: int) -> int:
	var roll: int = (noise / 17) % 100
	if damp.has(cell) and roll < 60: return WALL_ROW["seep"] if roll % 2 == 0 else WALL_ROW["mossy"]
	if roll < int(float(theme["wear"]) * 45.0): return WALL_ROW["displaced"] if roll % 3 != 0 else WALL_ROW["cracked"]
	if roll >= 50 and roll < 50 + int(float(theme["moss"]) * 35.0): return WALL_ROW["mossy"] if roll % 2 == 0 else WALL_ROW["seep"]
	return (noise / 7) % 3

func low_row(cell: Vector2i) -> int:
	var noise: int = world._noise(cell)
	var theme: Dictionary = RegionStyle.theme(world.room_name(IsoMath.cell_center(cell - Vector2i(1, 1))))
	if int(theme["broken"]) > 0 and noise % 7 == 0: return LOW_ROW["broken"]
	var style: String = String(theme["low"])
	if style != "plain" and noise % 3 == 0: return LOW_ROW[style]
	if float(theme["wear"]) >= 0.5 and noise % 5 == 1: return LOW_ROW["displaced"]
	if damp.has(cell) and noise % 2 == 0: return LOW_ROW["mossy"]
	return noise % 2

## Wall cells right next to a door post (junctions with arches stay unadorned).
func _beside_post(cell: Vector2i) -> bool:
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if Layout.char_at(cell + offset) == "D": return true
	return false

static func is_broken_row(full: bool, row: int) -> bool:
	return row == (WALL_ROW["broken"] if full else LOW_ROW["broken"])
