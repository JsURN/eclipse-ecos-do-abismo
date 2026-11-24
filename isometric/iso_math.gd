extends RefCounted
## Coordinate contract of the isometric prototype (see docs/ISOMETRIC_PROTOTYPE.md).
##
## LOGIC / WORLD space — where physics, AI, A* and combat run:
##   a flat cartesian plane, 16 units per cell (same scale as the top-down slice).
##   +x = grid "east"  -> screen down-right
##   +y = grid "south" -> screen down-left
## VIEW / SCREEN space — what is drawn:
##   2:1 diamond projection; one 16x16 world cell becomes a 32x16 diamond.
##   screen = (x - y, (x + y) / 2). The projection is linear, so the same basis
##   converts directions (velocity, aim) as well as positions.
## Heights (raised floors, flying projectiles) are a separate visual offset and
## never enter the logic plane.

const CELL: float = 16.0
const TILE_SIZE: Vector2i = Vector2i(32, 16)
## Basis of the projection: world X -> (1, 0.5), world Y -> (-1, 0.5).
const BASIS: Transform2D = Transform2D(Vector2(1, 0.5), Vector2(-1, 0.5), Vector2.ZERO)
## Godot's DIAMOND_DOWN TileMapLayer centres cell (0,0) at (16, 8); our projection
## puts it at (0, 8). Offsetting the layer by this keeps both in agreement.
const TILEMAP_OFFSET: Vector2 = Vector2(-16, 0)

static func world_to_screen(world: Vector2) -> Vector2:
	return Vector2(world.x - world.y, (world.x + world.y) * 0.5)

static func screen_to_world(screen: Vector2) -> Vector2:
	return Vector2(screen.y + screen.x * 0.5, screen.y - screen.x * 0.5)

static func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL

static func world_to_cell(world: Vector2) -> Vector2i:
	return Vector2i((world / CELL).floor())

static func cell_to_screen(cell: Vector2i) -> Vector2:
	return world_to_screen(cell_center(cell))

## Converts camera-relative input (W = screen up, D = screen right) into a world
## direction. A -45 degree rotation means: single keys move along screen axes and
## key diagonals (W+D, S+A...) move exactly along the grid axes, i.e. parallel to
## corridors and walls. The magnitude is preserved, so normalised input keeps the
## same world speed in all eight directions.
static func input_to_world(input: Vector2) -> Vector2:
	return input.rotated(-PI / 4.0)

## Unit screen direction for a world direction (facing, effects, projectiles).
static func direction_to_screen(direction: Vector2) -> Vector2:
	return world_to_screen(direction).normalized()
