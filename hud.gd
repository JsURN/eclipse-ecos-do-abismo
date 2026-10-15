extends Control
## Compact HUD, designed for the 384x216 pixel viewport.
var game: Node
var labels: Dictionary = {}
var health_display: float = 1.0
var minimap_texture: ImageTexture

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label("stats", "", Vector2(40, 8), 9, "e6edf2")
	_label("corruption", "CORR —", Vector2(100, 34), 8, "b995d0")
	_label("room", "", Vector2(158, 7), 9, "ddd6c5")
	_label("enemy", "", Vector2(158, 20), 8, "79dedc")
	_label("weapon", "J", Vector2(13, 194), 9, "e8c48b")
	_label("dash", "SHIFT", Vector2(30, 195), 7, "79dedc")
	_label("prompt", "", Vector2(65, 194), 8, "ddd6c5")
	labels["prompt"].size.x = 309
	labels["prompt"].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label("notice", "", Vector2(8, 46), 10, "9ce9e5")
	labels["notice"].size = Vector2(368, 22)
	labels["notice"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels["notice"].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label("ending", "", Vector2(24, 82), 14, "e6edf2")
	labels["ending"].size = Vector2(336, 100)
	labels["ending"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var map_image: Image = Image.create(42, 26, false, Image.FORMAT_RGBA8)
	map_image.fill(Color.TRANSPARENT)
	for cell in game.dungeon.floor_cells:
		var pixel: Vector2i = Vector2i((Vector2(cell) * Vector2(0.6, 0.7)).floor())
		map_image.set_pixelv(pixel, Color("38465d"))
	minimap_texture = ImageTexture.create_from_image(map_image)

func _label(key: String, value: String, at: Vector2, font_size: int, ink: String) -> void:
	var label: Label = Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(ink))
	label.add_theme_color_override("font_shadow_color", Color("080e1c"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	labels[key] = label

func _process(delta: float) -> void:
	if not is_instance_valid(game.player): return
	var p = game.player
	var ratio: float = float(p.health) / float(p.max_health)
	health_display = maxf(ratio, move_toward(health_display, ratio, delta * 0.6))
	labels["stats"].text = "NV.%d   %d / %d" % [int(p.level), int(p.health), int(p.max_health)]
	labels["room"].text = game.dungeon.room_name(p.position)
	labels["enemy"].text = "ONDA %d/3  ·  %d INIMIGOS" % [maxi(1, int(game.wave)), get_tree().get_nodes_in_group("enemies").size()] if game.combat_started else "CATACUMBAS DO ECLIPSE"
	labels["notice"].text = game.notice if game.notice_timer > 0.0 else ""
	labels["notice"].modulate.a = minf(1.0, float(game.notice_timer))
	labels["prompt"].text = game.interaction_prompt()
	labels["ending"].text = game.ending_text
	queue_redraw()

func _frame(rect: Rect2, ink: Color) -> void:
	draw_rect(rect, Color("0b101cea"))
	draw_rect(rect, ink, false, 1.0)
	draw_line(rect.position + Vector2(2, 1), rect.position + Vector2(rect.size.x - 3, 1), Color("41516a"))
	draw_rect(Rect2(rect.position, Vector2(2, 2)), Color("c4a66b"))
	draw_rect(Rect2(rect.end - Vector2(2, 2), Vector2(2, 2)), Color("c4a66b"))

func _draw() -> void:
	_frame(Rect2(6, 5, 140, 40), Color("41516a"))
	_frame(Rect2(331, 5, 47, 32), Color("41516a"))
	_frame(Rect2(6, 191, 18, 18), Color("9d855c"))
	_frame(Rect2(27, 191, 30, 18), Color("59426c"))
	if not is_instance_valid(game.player): return
	var p = game.player
	# Live portrait and delayed health chip are visual only.
	var portrait: Texture2D = preload("res://assets/characters/kael/portrait.png")
	draw_texture_rect(portrait, Rect2(9, 8, 28, 28), false)
	_bar(Rect2(40, 22, 99, 6), health_display, Color("e8c48b"))
	_bar(Rect2(40, 22, 99, 6), float(p.health) / float(p.max_health), Color("d2748f"), false)
	_bar(Rect2(40, 31, 99, 3), float(p.experience) / float(p.experience_to_next), Color("79dedc"))
	draw_rect(Rect2(40, 38, 52, 2), Color("32283e"))
	draw_rect(Rect2(40, 37, 2, 3), Color("b995d0"))
	var cooldown: float = 1.0 - clampf(float(p.dash_cooldown) / 0.9, 0.0, 1.0)
	draw_rect(Rect2(29, 206, floor(26 * cooldown), 1), Color("79dedc"))
	var origin: Vector2 = Vector2(333, 8)
	draw_texture(minimap_texture, origin)
	draw_rect(Rect2((origin + Vector2(p.position) / 16.0 * Vector2(0.6, 0.7)).floor(), Vector2(2, 2)), Color("e8c48b"))
	# Indicators warn about shooters beyond the closer camera's field of view.
	if not game.game_finished:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.enemy_type != "stalker": continue
			var screen: Vector2 = enemy.get_global_transform_with_canvas().origin/scale
			if Rect2(4, 38, 376, 150).has_point(screen): continue
			var at: Vector2 = screen.clamp(Vector2(4, 41), Vector2(380, 185)).round()
			var aim: Vector2 = (screen - Vector2(192,108)).normalized()
			var side: Vector2 = aim.orthogonal() * 2
			draw_colored_polygon(PackedVector2Array([at + aim * 3, at - aim * 2 + side, at - aim * 2 - side]), Color("ffa787"))
	if game.game_finished:
		draw_rect(Rect2(0, 45, 384, 145), Color("080e1cee"))
		_frame(Rect2(16, 68, 352, 109), Color("c4a66b"))

func _bar(rect: Rect2, ratio: float, color: Color, background: bool = true) -> void:
	if background:
		draw_rect(rect.grow(1), Color("41516a"))
		draw_rect(rect, Color("162032"))
	var fill: Rect2 = rect
	fill.size.x = floor(rect.size.x * clampf(ratio, 0.0, 1.0))
	draw_rect(fill, color)
	if fill.size.x > 0: draw_line(fill.position, fill.position + Vector2(fill.size.x, 0), color.lightened(0.3))
