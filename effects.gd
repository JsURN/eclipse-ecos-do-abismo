extends Node2D
## Bounded, short-lived visual feedback. No gameplay timing/hitbox changes.
var particles: Array[Dictionary] = []
var age: float = 0.0
var life: float = 0.3
var ink: Color = Color("79dedc")
var kind: String = "impact"
var direction: Vector2 = Vector2.RIGHT
var ghost: Texture2D
var flipped: bool = false
var caption: String = ""

func _ready() -> void:
	add_to_group("visual_effects")
	z_index = 8
	var count: int = 8
	match kind:
		"attack": life = 0.16; count = 4
		"dash": life = 0.22; count = 3
		"death": life = 0.6; count = 16
		"hurt": life = 0.24; count = 8
		"collect": life = 0.35; count = 5
		"gate": life = 0.5; count = 12
		"number": life = 0.55; count = 0
	for i in range(count):
		var angle: float = TAU * float(i) / float(maxi(1, count)) + i * 0.31
		particles.append({"velocity": Vector2.from_angle(angle) * float(14 + i % 4 * 12), "size": 1 + i % 2})

func _process(delta: float) -> void:
	age += delta
	modulate.a = pow(maxf(0.0, 1.0 - age / life), 1.2)
	queue_redraw()
	if age >= life: queue_free()

func _draw() -> void:
	if kind == "number":
		var font: Font = ThemeDB.fallback_font
		var at: Vector2 = Vector2(-5, -29 - age * 16).round()
		draw_string(font, at + Vector2(1, 1), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("080e19"))
		draw_string(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, ink)
		return
	if kind == "dash" and ghost:
		if flipped: draw_set_transform(Vector2.ZERO, 0, Vector2(-1, 1))
		draw_texture_rect(ghost, Rect2(-40,-70,80,80), false, Color(0.55,0.65,1.0,0.48))
		draw_set_transform(Vector2.ZERO)
		for i in range(3):
			var at: Vector2 = (-direction * (6 + i * 4) + Vector2(0, i * 3 - 10)).round()
			draw_line(at, at - direction * 7, Color("79dedc"), 1)
		return
	for p in particles:
		var pos: Vector2 = Vector2(p["velocity"]) * age
		if kind == "collect": pos.y = -age * 28 - float(p["size"]) * 2
		if kind == "death": pos.y += age * age * 40
		var point: Vector2 = pos.round() - Vector2(0, 8)
		draw_rect(Rect2(point + Vector2.ONE, Vector2.ONE * float(p["size"])), ink.darkened(0.5))
		draw_rect(Rect2(point, Vector2.ONE * float(p["size"])), ink)
	if kind == "attack":
		draw_set_transform(Vector2(0,-8),direction.angle())
		draw_texture_rect(preload("res://assets/effects/sword_arc.png"),Rect2(-12,-16,48,32),false,Color(1,1,1,0.5))
	elif kind == "impact" or kind == "hurt":
		draw_texture_rect(preload("res://assets/effects/impact.png"),Rect2(-12,-24,24,16),false)
		var extent: float = maxf(1, 7 - age * 20)
		draw_line(Vector2(-extent, -8), Vector2(extent, -8), ink, 1)
		draw_line(Vector2(0, -8 - extent), Vector2(0, -8 + extent), ink, 1)
	elif kind == "death":
		draw_texture_rect(preload("res://assets/effects/corruption.png"),Rect2(-24,-10,48,32),false,Color(1,1,1,0.4))
		var radius: float = 4 + age * 16
		for i in range(8):
			var at: Vector2 = (Vector2.from_angle(i * TAU / 8) * radius).round()
			draw_rect(Rect2(at - Vector2(0, 6), Vector2.ONE), ink)
