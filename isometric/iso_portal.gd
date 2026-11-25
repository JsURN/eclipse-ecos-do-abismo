extends RefCounted
## Geometry of the arched portals (a passage between two door posts `D`), shared by the
## art generator (tools/build_iso_art.gd renders the sprites from it), the world
## (iso_world.gd places them) and the seals (iso_seal.gd fits the curtain to the opening).
##
## Portal space: s runs along the span (0 at the low post's inner face, W = 16 n at the
## high post's), c runs across the passage (0..16 inside the cell), z is height in px.
## The opening of n cells is spanned by a semi-elliptical voussoir ring that springs
## from the imposts at SPRING: a true semicircle up to 3 cells, flattened (basket
## handle) beyond, so wide spans do not tower over the walls. In 2:1 isometry this
## curve is what keeps reading as an arch: a low rise (the old 13 px) is sheared into
## a sloping beam on screen.
const SPANS: Array[int] = [2, 3, 4]
## Impost height: where the arch springs from the pylons (Kael is ~33 px tall; the
## opening still clears him at the centre of every passage cell, see clearance()).
const SPRING: float = 22.0
## Radial depth of the voussoir ring.
const RING: float = 7.0
## Rise of the intrados above the impost: at least MIN_RISE (a narrow opening gets a
## stilted, slightly gothic arch instead of a squat one hidden between its pylons) and
## at most MAX_RISE (a semicircle up to 3 cells, flattened beyond).
const MIN_RISE: float = 22.0
const MAX_RISE: float = 24.0
## Depth of the ring and of the pylon bodies across the passage (c range). The ring is
## set back from the pylon faces, so the pylons read as the supports it rests on.
const RING_C: Vector2 = Vector2(3.5, 12.5)
const PYLON_C: Vector2 = Vector2(1.5, 14.5)
## Atlas layout (assets/isometric/catacombs/portal_{x,y}.png): one 32x96 cell per
## piece, base diamond centre 8 px above the bottom; rows = SPANS x (intact, collapsed),
## columns = low pylon, passage cells 0..n-1, high pylon.
const CELL_SIZE: Vector2i = Vector2i(32, 96)

static func half_span(n: int) -> float:
	return 8.0 * n

static func rise(n: int) -> float:
	return clampf(half_span(n), MIN_RISE, MAX_RISE)

## Height of the opening (the intrados) at `s` along the span; SPRING at the posts.
static func intrados(n: int, s: float) -> float:
	var a: float = half_span(n)
	var x: float = clampf((s - a) / a, -1.0, 1.0)
	return SPRING + rise(n) * sqrt(1.0 - x * x)

## Height of the ring's outer curve (extrados) at `s`, or SPRING outside it.
static func extrados(n: int, s: float) -> float:
	var a: float = half_span(n) + RING
	var x: float = (s - half_span(n)) / a
	if absf(x) >= 1.0: return SPRING
	return SPRING + (rise(n) + RING) * sqrt(1.0 - x * x)

## Top of the pylons: the cornice meets the extrados where the ring leaves the pylon's
## inner face, so the arch visibly grows out of its supports.
static func pylon_top(n: int) -> float:
	return roundf(extrados(n, 0.0))

## Free height under the arch at the centre of the passage cell nearest a post.
static func clearance(n: int) -> float:
	return intrados(n, 8.0)

## Atlas region of one piece: k = -1 low pylon, 0..n-1 passage cells, n high pylon.
static func region(n: int, k: int, ruined: bool) -> Rect2i:
	var row: int = SPANS.find(n) * 2 + (1 if ruined else 0)
	return Rect2i((k + 1) * CELL_SIZE.x, row * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y)
