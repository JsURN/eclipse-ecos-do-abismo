extends Node2D
## Small, deterministic pixel bursts; no external particle textures.
var particles: Array[Dictionary] = []
var age: float = 0.0
var life: float = 0.45
var ink: Color = Color("65dddb")
var kind: String = "impact"
var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	z_index = 8
	for i in range(12):
		var angle: float = TAU * float(i) / 12.0
		particles.append({"velocity": Vector2.from_angle(angle) * float(20 + i % 4 * 14), "size": 1 + i % 2})

func _process(delta: float) -> void:
	age += delta
	modulate.a = maxf(0.0, 1.0 - age / life)
	queue_redraw()
	if age >= life: queue_free()

func _draw() -> void:
	for p in particles:
		var pos: Vector2 = Vector2(p["velocity"]) * age
		draw_rect(Rect2(pos.round(), Vector2.ONE * float(p["size"])), ink)
	if kind == "attack":
		for i in range(8):
			var angle: float = direction.angle() - 0.8 + float(i) * 0.2
			draw_rect(Rect2((Vector2.from_angle(angle) * (9 + age * 25)).round(), Vector2(2, 2)), ink)
