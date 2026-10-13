extends Camera2D
## Smooth follow with a quantized render position; no fractional pixel zoom.
var target: Node2D
var world_bounds: Rect2 = Rect2(32, 112, 1040, 368)
var follow_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	position_smoothing_enabled = false
	limit_left = int(world_bounds.position.x)
	limit_top = int(world_bounds.position.y)
	limit_right = int(world_bounds.end.x)
	limit_bottom = int(world_bounds.end.y)
	snap_to_target()

func snap_to_target() -> void:
	if is_instance_valid(target):
		follow_position = target.global_position
		_apply_position()
		force_update_scroll()

func _process(delta: float) -> void:
	if not is_instance_valid(target): return
	follow_position = follow_position.lerp(target.global_position, 1.0 - exp(-10.0 * delta))
	_apply_position()

func _apply_position() -> void:
	var half_view: Vector2 = get_viewport_rect().size / zoom / 2.0
	global_position = follow_position.round().clamp(world_bounds.position + half_view, world_bounds.end - half_view)
