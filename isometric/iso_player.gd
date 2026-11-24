extends "res://player.gd"
## Kael for the isometric prototype. Everything (health, XP, attack, dash timings,
## invulnerability, animations) is inherited from player.gd; only the two
## projection-dependent inputs change:
##  * movement: camera-relative WASD rotated onto the world grid (IsoMath.input_to_world);
##  * aim: the cursor (screen space) is unprojected back into world space.
const IsoMath = preload("res://isometric/iso_math.gd")
## Aim from Kael's chest, not his feet, so the cursor feels centred on him.
const AIM_HEIGHT: float = 14.0

## Set by the prototype once the visual proxy exists.
var view: Node2D

func _movement_input() -> Vector2:
	return IsoMath.input_to_world(super())

func _aim_direction(fallback: Vector2) -> Vector2:
	if not is_instance_valid(view): return fallback
	var screen_delta: Vector2 = get_global_mouse_position() - (view.feet() - Vector2(0, AIM_HEIGHT))
	if screen_delta.length_squared() <= 16.0: return fallback
	return IsoMath.screen_to_world(screen_delta).normalized()
