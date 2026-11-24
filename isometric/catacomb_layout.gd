extends RefCounted
## Hand-authored data for the first continuous isometric area: Catacumbas do Eclipse.
## Pure data — no nodes. Each character is one LOGIC cell (16x16 world units);
## rows are +y (screen down-left), columns are +x (screen down-right).
## To expand the world, widen the rows/add rows and register new regions below.
##
## Legend
##   #  solid rock / wall (rendered as a wall only when it touches floor)
##   .  stone floor          R  floor with lunar rune (light)
##   K  player start         B  bones (decor, walkable)
##   ^  raised dais (+6 px)  =  stairs (+3 px)
##   O  moon seal on dais    A  altar on dais (obstacle)
##   E  exit seal on dais    C  relic chest (obstacle)
##   P  pillar               S  statue
##   T  blue-flame brazier   X  sarcophagus
##   r  rubble               c  abyssal crystal
##   ~  collapsed wall stump D  door post flanking a passage (solid)
##   Q  lunar pedestal (orb)    w  shallow water (walkable, -2 px)
##   G  broken column stump     F  fallen column
##   U  funerary urns           H  bone pile

const ROWS: Array[String] = [
	"############################################################",
	"############################################################",
	"############################################################",
	"#####.......U###############################################",
	"####..........##############################################",
	"###..S..R...S..###############U.............################",
	"###..........T.D#############................###############",
	"###..................#######..T.....R......T..##############",
	"###.T...K............######....................#############",
	"###..................######....P..........P....#############",
	"###..........T.D##...######....................#############",
	"###..S....B.S..###...#####D....................#############",
	"####..........####..........B.....^^^^^^.......#############",
	"#####........#####................^^^^^^......D#############",
	"##################U..............=^^AO^^............########",
	"##########################D..R...=^^OO^^....R.......########",
	"###########################.......^^^^^^.............#######",
	"###########################.......^^^^^^......D###...#######",
	"###########################.........==.........###...#######",
	"###########################..................B.###...#######",
	"###########################....................##.....######",
	"###########################....P..........P....##.....######",
	"###########################.............r......##.......####",
	"############################..T.....R......T..###.......G###",
	"#############################................###.www...T..##",
	"##############################..............####.ww..c....##",
	"##################################D...D#########..~~......##",
	"###################################...##########..........##",
	"###################################...##########..r.......##",
	"###################################...##########.......~..##",
	"###################################...##########....r..~F.##",
	"#################################.....##########..wwww....##",
	"#################################.....##########..wwww..c.##",
	"#################################.....##########.~~.......##",
	"##############################...........#######......R...##",
	"#############################U............######..wwwww...##",
	"############################..S.........S..#####...www..~.##",
	"############################...X...R...X...#####.c........##",
	"############################..............D#####G.....r...##",
	"############################.....B...........r.....Q===Q..##",
	"############################.B.....................^^^^^..##",
	"############################...X.......X..D#####...^^E^^..##",
	"############################.....T.C.T.....#####.T.^^^^^..##",
	"#############################.........B..H#######..^^^^^.###",
	"##############################...........#########......####",
	"############################################################",
	"############################################################",
]

## Characters a body can stand on (collision is added for everything else).
const WALKABLE: String = ".KR^=OBEw"
## Characters that are walkable cells but carry a blocking prop.
const PROP_OBSTACLES: String = "APSTXrc~CQGFUH"
## Visual floor height, in screen pixels, per character.
const HEIGHTS: Dictionary = {"^": 6.0, "O": 6.0, "E": 6.0, "A": 6.0, "=": 3.0, "w": -2.0}

## Named areas (cell rects) for the HUD and future streaming/encounters. First match wins.
const REGIONS: Array[Dictionary] = [
	{"name": "Vestíbulo dos Esquecidos", "cells": Rect2i(3, 3, 12, 11)},
	{"name": "Passagem das Cinzas", "cells": Rect2i(15, 6, 12, 10)},
	{"name": "Câmara do Eclipse", "cells": Rect2i(27, 5, 20, 21)},
	{"name": "Descida do Ossário", "cells": Rect2i(33, 26, 5, 8)},
	{"name": "Ossário Lunar", "cells": Rect2i(28, 34, 15, 11)},
	{"name": "Fenda Colapsada", "cells": Rect2i(43, 39, 5, 2)},
	{"name": "Galeria Quebrada", "cells": Rect2i(47, 13, 6, 8)},
	{"name": "Ruínas Submersas", "cells": Rect2i(48, 20, 10, 25)},
]

## Entering this rect (inner chamber, away from the doors) starts the encounter.
const COMBAT_TRIGGER: Rect2i = Rect2i(29, 7, 16, 17)
## Passages sealed while the encounter runs.
const SEALS: Array = [
	[Vector2i(26, 12), Vector2i(26, 13), Vector2i(26, 14)],
	[Vector2i(35, 26), Vector2i(36, 26), Vector2i(37, 26)],
	[Vector2i(47, 14), Vector2i(47, 15), Vector2i(47, 16)],
]
## Enemy spawn cells inside the chamber (cycled per wave).
const SPAWNS: Array[Vector2i] = [
	Vector2i(33, 9), Vector2i(41, 11), Vector2i(32, 20), Vector2i(41, 20),
	Vector2i(37, 8), Vector2i(37, 22), Vector2i(44, 13),
]

static func size() -> Vector2i:
	return Vector2i(ROWS[0].length(), ROWS.size())

static func char_at(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= ROWS.size() or cell.x < 0 or cell.x >= ROWS[cell.y].length(): return "#"
	return ROWS[cell.y][cell.x]

static func find(symbol: String) -> Vector2i:
	for y in range(ROWS.size()):
		var x: int = ROWS[y].find(symbol)
		if x >= 0: return Vector2i(x, y)
	return Vector2i(-1, -1)
