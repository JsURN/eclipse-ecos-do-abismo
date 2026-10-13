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
	draw_rect(Rect2(-6, -24, 12, 48), Color(0.06, 0.1, 0.16, amount * 0.7))
	for y in [-27, 23]:
		draw_rect(Rect2(-10, y, 20, 5), Color("263244"))
		draw_rect(Rect2(-9, y, 18, 1), Color("657c91"))
		draw_rect(Rect2(-5, y + 2, 10, 1), Color("c4a66b"))
	for y in range(4):
		var length: float = floor(10.0 * amount)
		draw_rect(Rect2(-5, -22 + y * 12, length, 3), Color("61718a"))
		draw_rect(Rect2(-5, -22 + y * 12, length, 1), Color("b5c1cd"))
		draw_rect(Rect2(-4, -18 + y * 12, 1, 2), Color("ff947f") if amount > 0.5 else Color("79dedc"))
	if amount > 0.6:
		draw_rect(Rect2(-2, -4, 4, 8), Color("c4a66b"))
		draw_rect(Rect2(-1, -2, 2, 4), Color("cf7794"))
