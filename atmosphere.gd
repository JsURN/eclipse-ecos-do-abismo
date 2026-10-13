extends Node2D
## One small draw batch: contact shade, rune glints, torch tongues and 32 motes.
var floor_cells: Dictionary = {}
var torch_cells: Array[Vector2i] = []
var rune_points: Array[Vector2] = []
var motes: Array[Vector2] = []
var time: float = 0.0

func configure(floor_data: Dictionary, torch_data: Array[Vector2i], rune_data: Array[Vector2]) -> void:
	floor_cells = floor_data
	torch_cells = torch_data
	rune_points = rune_data
	var keys: Array = floor_cells.keys()
	for i in range(32): motes.append(Vector2(keys[(i * 97 + 13) % keys.size()]) * 16 + Vector2(8, 8))

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	for cell in floor_cells:
		var at: Vector2 = Vector2(cell) * 16
		if not floor_cells.has(cell + Vector2i.UP): draw_rect(Rect2(at, Vector2(16, 4)), Color("080e1948"))
		if not floor_cells.has(cell + Vector2i.LEFT): draw_rect(Rect2(at, Vector2(3, 16)), Color("080e1932"))
	for i in range(torch_cells.size()):
		var at: Vector2 = Vector2(torch_cells[i] * 16) + Vector2(8, 2)
		var phase: int = int(time * 7.0 + i) % 3
		draw_rect(Rect2(at + Vector2(phase - 1, -phase), Vector2(1, 3)), Color("c4f4ed"))
		draw_rect(Rect2(at + Vector2(-3, -4 - fmod(time * 10 + i, 8)), Vector2.ONE), Color("79dedc80"))
	for i in range(rune_points.size()):
		var at: Vector2 = rune_points[i]
		var alpha: float = 0.2 + (sin(time * 2.0 + i) + 1.0) * 0.12
		draw_circle(at, 8.0, Color(0.3, 0.6, 0.8, alpha * 0.18))
		draw_rect(Rect2(at + Vector2(3, -2), Vector2(1, 4)), Color(0.7, 0.9, 1.0, alpha))
	for i in range(motes.size()):
		var drift: Vector2 = Vector2(sin(time * 0.4 + i) * 3, cos(time * 0.3 + i * 2) * 4)
		var alpha: float = (0.5 + sin(time + i) * 0.5) * 0.22
		draw_rect(Rect2((motes[i] + drift).round(), Vector2.ONE), Color(0.6, 0.65, 0.85, alpha))
