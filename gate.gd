extends StaticBody2D
var amount: float = 0.0
var gate_tween: Tween

func _ready() -> void:
	z_index = 2

func set_closed(closed: bool) -> void:
	if gate_tween and gate_tween.is_running(): gate_tween.kill()
	gate_tween = create_tween()
	gate_tween.tween_property(self, "amount", 1.0 if closed else 0.0, 0.35)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-7, -24, 14, 48), Color("162032"))
	draw_rect(Rect2(-7, -25, 14, 3), Color("c4a66b"))
	draw_rect(Rect2(-7, 23, 14, 3), Color("c4a66b"))
	for y in range(4):
		var length: float = floor(10.0 * amount)
		draw_rect(Rect2(-5, -22 + y * 12, length, 3), Color("61718a"))
		draw_rect(Rect2(-4, -18 + y * 12, 2, 2), Color("bd627e") if amount > 0.5 else Color("65dddb"))
