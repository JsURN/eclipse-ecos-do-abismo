extends Control
var game: Node
var labels: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label("brand", "E C L I P S E", Vector2(16, 6), 15, "c4a66b")
	_label("dungeon", "CATACUMBAS DO ECLIPSE", Vector2(212, 7), 10, "61718a")
	_label("room", "", Vector2(212, 22), 12, "dce9ed")
	_label("stats", "", Vector2(16, 26), 10, "b7bcc5")
	_label("enemy", "", Vector2(212, 39), 10, "65dddb")
	_label("corruption", "CORRUPÇÃO  —", Vector2(16, 67), 9, "927aa9")
	_label("weapon", "J", Vector2(20, 292), 12, "c4a66b")
	_label("dash", "SHIFT", Vector2(48, 297), 8, "65dddb")
	_label("help", "WASD mover  •  Mouse mirar  •  J / Espaço atacar  •  Shift dash", Vector2(96, 292), 9, "b7bcc5")
	_label("prompt", "", Vector2(96, 306), 10, "c4a66b")
	_label("notice", "", Vector2(114, 80), 12, "65dddb")
	labels["notice"].size = Vector2(360, 28)
	labels["notice"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label("ending", "", Vector2(90, 135), 18, "dce9ed")
	labels["ending"].size = Vector2(396, 120)
	labels["ending"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _label(key: String, value: String, at: Vector2, font_size: int, ink: String) -> void:
	var label: Label = Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(ink))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	labels[key] = label

func _process(_delta: float) -> void:
	if not is_instance_valid(game.player): return
	var p = game.player
	labels["stats"].text = "KAEL  ·  NV.%d    %d / %d" % [int(p.level), int(p.health), int(p.max_health)]
	labels["room"].text = game.dungeon.room_name(p.position)
	labels["enemy"].text = "ONDA %d / 3   ·   INIMIGOS %d" % [maxi(1, int(game.wave)), get_tree().get_nodes_in_group("enemies").size()]
	labels["notice"].text = game.notice if game.notice_timer > 0.0 else ""
	labels["prompt"].text = game.interaction_prompt()
	labels["ending"].text = game.ending_text
	queue_redraw()

func _frame(rect: Rect2, ink: Color) -> void:
	draw_rect(rect, Color("0b101cee"))
	draw_rect(rect, ink, false, 1.0)
	draw_rect(rect.grow(-2), Color("29364a"), false, 1.0)
	for at in [rect.position, rect.position + Vector2(rect.size.x - 3, 0), rect.end - Vector2(3, 3), rect.position + Vector2(0, rect.size.y - 3)]:
		draw_rect(Rect2(at, Vector2(3, 3)), Color("c4a66b"))

func _draw() -> void:
	_frame(Rect2(8, 4, 190, 79), Color("41516a"))
	_frame(Rect2(204, 4, 264, 57), Color("41516a"))
	_frame(Rect2(476, 4, 92, 79), Color("41516a"))
	_frame(Rect2(8, 285, 560, 35), Color("41516a"))
	_frame(Rect2(14, 289, 25, 27), Color("c4a66b"))
	_frame(Rect2(44, 289, 37, 27), Color("59426c"))
	if not is_instance_valid(game.player): return
	var p = game.player
	_bar(Rect2(16, 43, 174, 8), float(p.health) / float(p.max_health), Color("bd627e"))
	_bar(Rect2(16, 56, 174, 4), float(p.experience) / float(p.experience_to_next), Color("65dddb"))
	# Dungeon plan with a moving player marker, all four spaces visible.
	var origin: Vector2 = Vector2(480, 12)
	for cell in game.dungeon.floor_cells:
		var pos: Vector2 = origin + Vector2(cell) * Vector2(1.15, 1.6)
		draw_rect(Rect2(pos, Vector2(1.15, 1.6)), Color("29364a"))
	draw_rect(Rect2(origin + Vector2(p.position) / 16.0 * Vector2(1.15, 1.6), Vector2(3, 3)), Color("c4a66b"))
	if game.game_finished:
		draw_rect(Rect2(0, 88, 576, 194), Color("0b101ce8"))
		_frame(Rect2(76, 123, 424, 140), Color("c4a66b"))

func _bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect.grow(1), Color("61718a"))
	draw_rect(rect, Color("162032"))
	var fill: Rect2 = rect
	fill.size.x = floor(rect.size.x * clampf(ratio, 0.0, 1.0))
	draw_rect(fill, color)
	if fill.size.x > 0: draw_line(fill.position, fill.position + Vector2(fill.size.x, 0), color.lightened(0.3))
