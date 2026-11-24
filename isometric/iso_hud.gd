extends Control
## HUD of the isometric Catacumbas (the top-down slice keeps its own hud.gd).
## Drawn on a 384x216 logical canvas scaled 2x, the same pixel size as the world.
##
## Layout and hierarchy:
##   top-left     player plate: octagonal portrait, level gem, health, echoes (XP), corruption
##   top-centre   area name (serif) + one objective line (wave pips while fighting)
##   top-right    isometric minimap, revealed as Kael explores
##   bottom-left  action sockets (attack / dash with cooldown fill)
##   bottom-centre contextual prompt (only when something can be done) or fading hints
##   centre       banners (waves, relic, seals), area title cards, ending panel
## Purely presentational: reads game/player state, never changes it.
const IsoMath = preload("res://isometric/iso_math.gd")
const Layout = preload("res://isometric/catacomb_layout.gd")
const PORTRAIT: Texture2D = preload("res://assets/characters/kael/portrait.png")
const CANVAS: Vector2 = Vector2(384, 216)

const SHADE: Color = Color(0.02, 0.025, 0.055)
const GOLD: Color = Color("c4a66b")
const GOLD_DARK: Color = Color("9d855c")
const GOLD_DEEP: Color = Color("6b5838")
const CYAN: Color = Color("65dddb")
const CYAN_DEEP: Color = Color("285779")
const PURPLE: Color = Color("59426c")
const PURPLE_LIGHT: Color = Color("b995d0")
const PARCHMENT: Color = Color("e6dcc6")
const HEALTH: Color = Color("c4506c")
const HEALTH_LIGHT: Color = Color("f08aa0")
const CHIP: Color = Color("e8c48b")
const DANGER: Color = Color("ff8f7a")

const MAP_PIXELS: Vector2i = Vector2i(116, 72)
const MAP_FRAME: Rect2 = Rect2(318, 4, 62, 40)
const MAP_ORIGIN: Vector2 = Vector2(320, 6)
const REVEAL_RADIUS: int = 6
const HINT_SECONDS: float = 14.0
const HINTS: Array = [["WASD", "mover"], ["Mouse", "mirar"], ["J", "atacar"], ["Shift", "esquivar"], ["E", "interagir"]]

var game: Node
var title_font: Font
var body_font: Font
var time: float = 0.0
var health_display: float = 1.0
var last_health: float = -1.0
var hurt_flash: float = 0.0
var area: String = ""
var area_fade: float = 1.0
var visited: Dictionary = {}
var card: String = ""
var card_time: float = -1.0
var notice_seen: String = ""
var notice_age: float = 0.0
var map_image: Image
var map_texture: ImageTexture
var map_min: Vector2
var map_scale: float = 1.0
var revealed: Dictionary = {}
var map_dirty: bool = true
var reveal_timer: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body_font = ThemeDB.fallback_font
	# Serif titles from the system (no bundled font = no new dependency); falls back
	# to the default font where none of these exist.
	var serif: SystemFont = SystemFont.new()
	serif.font_names = PackedStringArray(["Cinzel", "Trajan Pro", "Palatino Linotype", "Book Antiqua", "Georgia", "Cambria", "Times New Roman", "serif"])
	serif.font_weight = 600
	serif.fallbacks = [body_font]
	title_font = serif
	_prepare_map()

# --- state ------------------------------------------------------------------------

func _process(delta: float) -> void:
	time += delta
	if not is_instance_valid(game.player): return
	var p: Node = game.player
	if last_health >= 0.0 and float(p.health) < last_health: hurt_flash = 0.3
	last_health = float(p.health)
	hurt_flash = maxf(0.0, hurt_flash - delta)
	var ratio: float = float(p.health) / float(p.max_health)
	health_display = maxf(ratio, move_toward(health_display, ratio, delta * 0.6))
	var current: String = game.world.room_name(p.position)
	if current != area:
		area = current
		area_fade = 0.0
		map_dirty = true
		if not visited.has(area):
			visited[area] = true
			card = area
			card_time = -1.0
	area_fade = minf(1.0, area_fade + delta * 2.5)
	# Area title cards wait for any banner to finish, then play once per area.
	# A wave/relic banner always wins: a card in progress is dropped.
	if card != "" and card_time >= 0.0 and float(game.notice_timer) > 0.0 and notice_age < 0.2: card = ""
	if card != "":
		if card_time < 0.0:
			if float(game.notice_timer) <= 0.0: card_time = 0.0
		else:
			card_time += delta
			if card_time > 3.2: card = ""
	if String(game.notice) != notice_seen:
		notice_seen = String(game.notice)
		notice_age = 0.0
	notice_age += delta
	reveal_timer -= delta
	if reveal_timer <= 0.0:
		reveal_timer = 0.2
		_reveal(IsoMath.world_to_cell(p.position))
	if map_dirty: _rebuild_map()
	queue_redraw()

# --- minimap ------------------------------------------------------------------------

func _prepare_map() -> void:
	var low: Vector2 = Vector2(INF, INF)
	var high: Vector2 = -low
	for cell: Vector2i in game.world.floor_cells:
		var projected: Vector2 = _project(Vector2(cell))
		low = low.min(projected)
		high = high.max(projected)
	map_min = low
	map_scale = minf((MAP_PIXELS.x - 6.0) / maxf(1.0, high.x - low.x + 2.0), (MAP_PIXELS.y - 6.0) / maxf(1.0, high.y - low.y + 1.0))
	map_image = Image.create(MAP_PIXELS.x, MAP_PIXELS.y, false, Image.FORMAT_RGBA8)
	map_texture = ImageTexture.create_from_image(map_image)

static func _project(cell: Vector2) -> Vector2:
	return Vector2(cell.x - cell.y, (cell.x + cell.y) * 0.5)

## Cell (float, cell units) -> minimap texel.
func _map_texel(cell: Vector2) -> Vector2:
	return (_project(cell) - map_min) * map_scale + Vector2(3, 3)

## World position -> logical HUD position on the minimap.
func _map_point(world: Vector2) -> Vector2:
	return MAP_ORIGIN + _map_texel(world / IsoMath.CELL - Vector2(0.5, 0.5)) * 0.5

func _reveal(center: Vector2i) -> void:
	for dy in range(-REVEAL_RADIUS, REVEAL_RADIUS + 1):
		for dx in range(-REVEAL_RADIUS, REVEAL_RADIUS + 1):
			var cell: Vector2i = center + Vector2i(dx, dy)
			if dx * dx + dy * dy > REVEAL_RADIUS * REVEAL_RADIUS or revealed.has(cell): continue
			if game.world.floor_cells.has(cell):
				revealed[cell] = true
				map_dirty = true

func is_revealed(world: Vector2) -> bool:
	return revealed.has(IsoMath.world_to_cell(world))

func _rebuild_map() -> void:
	map_dirty = false
	map_image.fill(Color.TRANSPARENT)
	var edges: Array[Vector2i] = []
	for cell: Vector2i in revealed:
		var symbol: String = Layout.char_at(cell)
		var ink: Color = Color("27324d")
		if game.world.room_name(IsoMath.cell_center(cell)) == area: ink = Color("33456a")
		if symbol == "w": ink = Color("1d4552")
		elif "^=OEA".contains(symbol): ink = Color("5a4f3c")
		_texel(cell, ink)
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not game.world.is_floor(cell + offset):
				edges.append(cell)
				break
	for cell in edges: _texel(cell, Color("7486ad"))
	map_texture.update(map_image)

func _texel(cell: Vector2i, ink: Color) -> void:
	var at: Vector2i = Vector2i(_map_texel(Vector2(cell)).floor())
	for x in range(2):
		if Rect2i(Vector2i.ZERO, MAP_PIXELS).has_point(at + Vector2i(x, 0)): map_image.set_pixelv(at + Vector2i(x, 0), ink)

# --- drawing helpers -------------------------------------------------------------------

func _text(font: Font, at: Vector2, text: String, size: int, ink: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string_outline(font, at, text, align, width, size, 2, Color(SHADE, ink.a * 0.9))
	draw_string(font, at, text, align, width, size, ink)

func _text_width(font: Font, text: String, size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

func _centered(font: Font, center_x: float, baseline: float, text: String, size: int, ink: Color) -> float:
	var width: float = _text_width(font, text, size)
	_text(font, Vector2(center_x - width * 0.5, baseline), text, size, ink)
	return width

func _diamond(center: Vector2, radius: float, fill: Color, outline: Color = Color.TRANSPARENT) -> void:
	var points: PackedVector2Array = PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
	if fill.a > 0.0: draw_colored_polygon(points, fill)
	if outline.a > 0.0:
		points.append(points[0])
		draw_polyline(points, outline, 1.0)

## Hairline that fades from `a` (opaque) to `b` (transparent).
func _fade_line(a: Vector2, b: Vector2, ink: Color) -> void:
	for i in range(8):
		draw_line(a.lerp(b, i / 8.0), a.lerp(b, (i + 1) / 8.0), Color(ink, ink.a * (1.0 - i / 8.0)), 1.0)

## Ornamental divider centred on x: two fading gold lines with diamond studs.
func _ornament(center_x: float, y: float, gap: float, reach: float, alpha: float) -> void:
	for side in [-1.0, 1.0]:
		var start: Vector2 = Vector2(center_x + side * gap, y)
		_fade_line(start, start + Vector2(side * reach, 0), Color(GOLD_DARK, 0.9 * alpha))
		_diamond(start - Vector2(side * 2.0, 0), 1.5, Color(GOLD, alpha))

## Horizontal band that is darkest in the middle and fades out at both ends.
func _band(center: Vector2, half_width: float, half_height: float, alpha: float) -> void:
	var dark: Color = Color(SHADE, 0.62 * alpha)
	var clear: Color = Color(SHADE, 0.0)
	for side in [-1.0, 1.0]:
		draw_polygon(PackedVector2Array([center + Vector2(0, -half_height), center + Vector2(side * half_width, -half_height), center + Vector2(side * half_width, half_height), center + Vector2(0, half_height)]), PackedColorArray([dark, clear, clear, dark]))

func _keycap(at: Vector2, key: String, ink: Color, size: int = 7) -> float:
	var width: float = maxf(9.0, _text_width(body_font, key, size) + 5.0)
	var rect: Rect2 = Rect2(at, Vector2(width, 10))
	draw_rect(rect, Color(SHADE, 0.85 * ink.a))
	draw_rect(rect, Color(ink, 0.85 * ink.a), false, 1.0)
	draw_line(rect.position + Vector2(1, 9), rect.position + Vector2(width - 1, 9), Color(ink, 0.35 * ink.a))
	_text(body_font, Vector2(at.x + width * 0.5 - _text_width(body_font, key, size) * 0.5, at.y + 7.5), key, size, ink)
	return width

# --- draw --------------------------------------------------------------------------------

func _draw() -> void:
	if not is_instance_valid(game.player): return
	var p: Node = game.player
	_draw_danger(p)
	_draw_indicators()
	_draw_player(p)
	_draw_area()
	_draw_minimap(p)
	_draw_sockets(p)
	_draw_prompt()
	_draw_banner()
	_draw_card()
	_draw_ending()

func _draw_danger(p: Node) -> void:
	var ratio: float = float(p.health) / float(p.max_health)
	if ratio >= 0.3 or game.game_finished: return
	var pulse: float = 0.55 + sin(time * 5.0) * 0.45
	for i in range(6):
		draw_rect(Rect2(Vector2(i, i), CANVAS - Vector2(i, i) * 2.0), Color(0.75, 0.12, 0.22, (0.2 - i * 0.032) * pulse), false, 1.0)

func _draw_player(p: Node) -> void:
	# Soft backing that fades to the right instead of a hard box.
	var left: Color = Color(SHADE, 0.72)
	var right: Color = Color(SHADE, 0.0)
	draw_polygon(PackedVector2Array([Vector2(2, 2), Vector2(134, 2), Vector2(134, 37), Vector2(2, 37)]), PackedColorArray([left, right, right, left]))
	_fade_line(Vector2(4, 37), Vector2(132, 37), Color(GOLD_DEEP, 0.9))
	# Octagonal portrait in a gilded frame.
	var center: Vector2 = Vector2(19, 19)
	var shape: PackedVector2Array = PackedVector2Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	for i in range(8):
		var direction: Vector2 = Vector2.from_angle(TAU * i / 8.0 + PI / 8.0)
		shape.append(center + direction * 14.0)
		uvs.append(Vector2(0.5, 0.45) + direction * 0.5)
	draw_colored_polygon(shape, Color(1.0, 0.62, 0.62) if hurt_flash > 0.0 else Color.WHITE, uvs, PORTRAIT)
	for ring in [[15.5, Color(GOLD_DARK)], [17.0, Color(SHADE, 0.9)]]:
		var frame: PackedVector2Array = PackedVector2Array()
		for i in range(9): frame.append(center + Vector2.from_angle(TAU * i / 8.0 + PI / 8.0) * float(ring[0]))
		draw_polyline(frame, ring[1], 1.0)
	_diamond(center + Vector2(0, -16), 1.5, GOLD)
	# Level gem.
	var gem: Vector2 = Vector2(31, 31)
	_diamond(gem, 6.5, Color("2a1f3d"), GOLD)
	_diamond(gem, 4.5, Color.TRANSPARENT, Color(PURPLE_LIGHT, 0.35))
	_centered(body_font, gem.x + 0.5, gem.y + 2.5, str(int(p.level)), 7, PARCHMENT)
	# Name and health numbers.
	_text(title_font, Vector2(40, 11), "Kael", 9, GOLD)
	_text(body_font, Vector2(70, 11), "%d / %d" % [int(ceilf(float(p.health))), int(p.max_health)], 7, PARCHMENT, HORIZONTAL_ALIGNMENT_RIGHT, 52)
	# Health: slanted bar, delayed chip, quarter ticks, flash on hit, pulse when low.
	var ratio: float = float(p.health) / float(p.max_health)
	draw_colored_polygon(_slant(39, 13, 84, 8), Color(SHADE, 0.92))
	draw_colored_polygon(_slant(40, 14, 82 * health_display, 6), Color(CHIP, 0.75))
	var fill: Color = HEALTH.lerp(HEALTH_LIGHT, (0.5 + sin(time * 6.0) * 0.5) * 0.35) if ratio < 0.3 else HEALTH
	if ratio > 0.0: draw_colored_polygon(_slant(40, 14, 82 * ratio, 6), fill)
	if ratio > 0.0: draw_line(Vector2(40, 14.5), Vector2(40 + 82 * ratio + 2.5, 14.5), HEALTH_LIGHT)
	if hurt_flash > 0.0: draw_colored_polygon(_slant(40, 14, 82 * ratio, 6), Color(1, 1, 1, hurt_flash * 1.5))
	for tick in [0.25, 0.5, 0.75]: draw_line(Vector2(40 + 82 * tick, 15), Vector2(40 + 82 * tick, 20), Color(SHADE, 0.45))
	var outline: PackedVector2Array = _slant(39, 13, 84, 8)
	outline.append(outline[0])
	draw_polyline(outline, GOLD_DEEP, 1.0)
	# Echoes (experience).
	var xp: float = clampf(float(p.experience) / float(p.experience_to_next), 0.0, 1.0)
	draw_rect(Rect2(40, 24, 66, 3), Color(SHADE, 0.92))
	draw_rect(Rect2(40, 24, floorf(66 * xp), 3), CYAN_DEEP.lerp(CYAN, 0.75))
	if xp > 0.0: draw_line(Vector2(40, 24.5), Vector2(40 + floorf(66 * xp), 24.5), Color("c9fbf3"))
	_text(body_font, Vector2(109, 28), "ecos", 6, Color(CYAN, 0.8))
	# Corruption (reserved system): five empty sigils until it is implemented.
	var corruption: float = float(p.get("corruption")) if p.get("corruption") != null else 0.0
	_text(body_font, Vector2(40, 35), "corrupção", 6, Color(PURPLE_LIGHT, 0.7))
	for i in range(5):
		var lit: bool = corruption > i * 20.0
		_diamond(Vector2(80 + i * 7, 32.5), 2.5, PURPLE_LIGHT if lit else Color(PURPLE, 0.4), Color(PURPLE_LIGHT, 0.55))

static func _slant(x: float, y: float, width: float, height: float) -> PackedVector2Array:
	var skew: float = minf(3.0, width)
	return PackedVector2Array([Vector2(x, y), Vector2(x + width + skew, y), Vector2(x + width, y + height), Vector2(x, y + height)])

func _draw_area() -> void:
	# While the title card plays, the small header waits (no duplicated name).
	var alpha: float = area_fade * (1.0 - _card_alpha())
	var width: float = _centered(title_font, 192, 12, area, 9, Color(PARCHMENT, alpha))
	_ornament(192, 8.5, width * 0.5 + 6.0, 12.0, alpha)
	var line: String = ""
	var fighting: bool = game.combat_started and not game.room_cleared and not game.game_finished
	if fighting:
		line = "Onda %d de %d   ·   %d inimigos" % [maxi(1, int(game.wave)), int(game.wave_total()), get_tree().get_nodes_in_group("enemies").size()]
	elif game.has_method("objective"):
		line = game.objective()
	if line == "": return
	_centered(body_font, 192, 23, line, 7, Color(CYAN.lerp(PARCHMENT, 0.25), 0.95))
	if fighting:
		for i in range(int(game.wave_total())):
			var done: bool = i < int(game.wave)
			_diamond(Vector2(192 - (int(game.wave_total()) - 1) * 3.5 + i * 7, 29.5), 2.2, PURPLE_LIGHT if done else Color(SHADE, 0.8), Color(PURPLE_LIGHT, 0.8))

func _draw_minimap(p: Node) -> void:
	var r: Rect2 = MAP_FRAME
	var cut: float = 4.0
	var frame: PackedVector2Array = PackedVector2Array([
		r.position + Vector2(cut, 0), Vector2(r.end.x - cut, r.position.y), Vector2(r.end.x, r.position.y + cut), Vector2(r.end.x, r.end.y - cut),
		Vector2(r.end.x - cut, r.end.y), Vector2(r.position.x + cut, r.end.y), Vector2(r.position.x, r.end.y - cut), r.position + Vector2(0, cut)])
	draw_colored_polygon(frame, Color(SHADE, 0.8))
	draw_set_transform(MAP_ORIGIN, 0.0, Vector2(0.5, 0.5))
	draw_texture(map_texture, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var world: Node = game.world
	if is_revealed(world.chest_position) and not game.chest_open: _diamond(_map_point(world.chest_position), 1.5, GOLD)
	if is_revealed(world.exit_position): _diamond(_map_point(world.exit_position), 1.5 + sin(time * 3.0) * 0.3, CYAN)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		draw_rect(Rect2(_map_point(enemy.position) - Vector2(0.5, 0.5), Vector2(1, 1)), DANGER)
	var me: Vector2 = _map_point(p.position)
	var pulse: float = fmod(time * 1.2, 1.0)
	draw_arc(me, 1.5 + pulse * 3.0, 0.0, TAU, 12, Color(GOLD, 0.6 * (1.0 - pulse)), 0.5)
	draw_rect(Rect2(me - Vector2(1, 1), Vector2(2, 2)), Color("f3e3b5"))
	frame.append(frame[0])
	draw_polyline(frame, GOLD_DEEP, 1.0)
	for corner in [Vector2(r.position.x + r.size.x * 0.5, r.position.y), Vector2(r.position.x + r.size.x * 0.5, r.end.y)]:
		_diamond(corner, 2.0, GOLD, Color(SHADE, 0.9))

func _draw_sockets(p: Node) -> void:
	_socket(Vector2(16, 196), 1.0 - clampf(float(p.attack_cooldown) / 0.22, 0.0, 1.0), GOLD, "J", false)
	_socket(Vector2(38, 196), 1.0 - clampf(float(p.dash_cooldown) / 0.9, 0.0, 1.0), CYAN, "Shift", true)

func _socket(center: Vector2, ready: float, ink: Color, key: String, dash: bool) -> void:
	var radius: float = 9.0
	var shape: PackedVector2Array = PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
	draw_colored_polygon(shape, Color(SHADE, 0.82))
	if ready < 1.0:
		var level: float = center.y + radius - 2.0 * radius * ready
		var clip: PackedVector2Array = PackedVector2Array([Vector2(center.x - radius, level), Vector2(center.x + radius, level), center + Vector2(radius, radius), center + Vector2(-radius, radius)])
		for piece in Geometry2D.intersect_polygons(shape, clip): draw_colored_polygon(piece, Color(ink, 0.22))
	else:
		_diamond(center, radius - 2.0, Color(ink, 0.08 + sin(time * 3.0) * 0.04))
	var bright: Color = ink if ready >= 1.0 else Color(ink, 0.45)
	var outline: PackedVector2Array = shape.duplicate()
	outline.append(shape[0])
	draw_polyline(outline, bright, 1.0)
	_diamond(center + Vector2(0, -radius - 1.5), 1.2, Color(GOLD, 0.9))
	if dash:
		for offset in [-2.0, 2.0]:
			draw_polyline(PackedVector2Array([center + Vector2(offset - 2, -3), center + Vector2(offset + 1, 0), center + Vector2(offset - 2, 3)]), bright, 1.0)
	else:
		draw_line(center + Vector2(-3.5, 3.5), center + Vector2(3.5, -3.5), Color(PARCHMENT, bright.a), 1.0)
		draw_line(center + Vector2(-3.5, 0.5), center + Vector2(-0.5, 3.5), Color(GOLD, bright.a), 1.0)
		draw_rect(Rect2(center + Vector2(-5, 4), Vector2(1, 1)), Color(GOLD, bright.a))
	_centered(body_font, center.x, center.y + radius + 7.5, key, 6, Color(PARCHMENT, 0.75))

func _draw_prompt() -> void:
	if game.game_finished: return
	var action: Dictionary = game.action_prompt() if game.has_method("action_prompt") else {}
	if not action.is_empty():
		var text: String = String(action["text"])
		var key: String = String(action.get("key", ""))
		var width: float = _text_width(body_font, text, 7) + (16.0 if key != "" else 4.0) + 10.0
		var x0: float = 192.0 - width * 0.5
		var x1: float = 192.0 + width * 0.5
		var y: float = 202.0
		var pill: PackedVector2Array = PackedVector2Array([Vector2(x0 - 5, y), Vector2(x0, y - 7), Vector2(x1, y - 7), Vector2(x1 + 5, y), Vector2(x1, y + 7), Vector2(x0, y + 7)])
		draw_colored_polygon(pill, Color(SHADE, 0.85))
		pill.append(pill[0])
		draw_polyline(pill, GOLD_DEEP if key != "" else Color(PURPLE_LIGHT, 0.45), 1.0)
		var x: float = x0 + 5.0
		if key != "": x += _keycap(Vector2(x, y - 5), key, Color(GOLD, 0.85 + sin(time * 4.0) * 0.15)) + 6.0
		_text(body_font, Vector2(x, y + 2.5), text, 7, PARCHMENT if key != "" else Color(PARCHMENT, 0.75))
		return
	# Onboarding hints: only at the start, before the first fight, then they fade away.
	var hint_alpha: float = clampf((HINT_SECONDS - time) / 2.0, 0.0, 1.0) * clampf(time - 0.5, 0.0, 1.0)
	if game.combat_started or hint_alpha <= 0.0: return
	var total: float = 0.0
	for hint in HINTS: total += maxf(9.0, _text_width(body_font, hint[0], 6) + 5.0) + _text_width(body_font, hint[1], 6) + 12.0
	var cursor: float = 192.0 - total * 0.5
	_band(Vector2(192, 203), total * 0.5 + 20.0, 8.0, hint_alpha)
	for hint in HINTS:
		cursor += _keycap(Vector2(cursor, 198), hint[0], Color(GOLD, 0.75 * hint_alpha), 6) + 3.0
		_text(body_font, Vector2(cursor, 205.5), hint[1], 6, Color(PARCHMENT, 0.7 * hint_alpha))
		cursor += _text_width(body_font, hint[1], 6) + 9.0

## Accent of a banner from its wording (waves violet, relics/levels gold, release cyan).
static func _accent(text: String) -> Color:
	if text.contains("ONDA") or text.contains("SELOS SE FECHAM"): return PURPLE_LIGHT
	if text.contains("ASCENSÃO") or text.contains("RELÍQUIA"): return GOLD
	return CYAN

func _draw_banner() -> void:
	if float(game.notice_timer) <= 0.0 or String(game.notice) == "" or game.game_finished: return
	var parts: PackedStringArray = String(game.notice).split("  ·  ")
	var title: String = parts[0]
	var subtitle: String = "  ·  ".join(parts.slice(1))
	var alpha: float = minf(1.0, notice_age * 4.0) * minf(1.0, float(game.notice_timer) * 1.5)
	var grow: float = ease(minf(1.0, notice_age * 3.0), 0.4)
	var accent: Color = _accent(title)
	var y: float = 54.0
	_band(Vector2(192, y - 2), 140.0, 15.0, alpha)
	var width: float = _centered(title_font, 192, y, title, 12, Color(accent.lerp(PARCHMENT, 0.45), alpha))
	_ornament(192, y - 4, width * 0.5 + 8.0, 10.0 + 40.0 * grow, alpha)
	if subtitle != "": _centered(body_font, 192, y + 10, subtitle, 7, Color(PARCHMENT, 0.85 * alpha))
	_fade_line(Vector2(192, y + 14), Vector2(192 - 60 * grow, y + 14), Color(accent, 0.5 * alpha))
	_fade_line(Vector2(192, y + 14), Vector2(192 + 60 * grow, y + 14), Color(accent, 0.5 * alpha))

func _draw_card() -> void:
	if card == "" or card_time < 0.0 or game.game_finished: return
	var alpha: float = _card_alpha()
	var y: float = 54.0
	_band(Vector2(192, y - 3), 120.0, 16.0, alpha * 0.8)
	var width: float = _centered(title_font, 192, y, card, 14, Color(PARCHMENT, alpha))
	_ornament(192, y - 5, width * 0.5 + 8.0, 34.0, alpha)
	_centered(body_font, 192, y + 11, "CATACUMBAS DO ECLIPSE", 6, Color(CYAN, 0.8 * alpha))

func _draw_indicators() -> void:
	if game.game_finished: return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.enemy_type != "stalker": continue
		var screen: Vector2 = game.canvas_point(enemy) / scale
		if Rect2(6, 44, 372, 146).has_point(screen): continue
		var at: Vector2 = screen.clamp(Vector2(8, 46), Vector2(376, 186)).round()
		var aim: Vector2 = (screen - CANVAS * 0.5).normalized()
		var side: Vector2 = aim.orthogonal() * 3.0
		var arrow: PackedVector2Array = PackedVector2Array([at + aim * 4.0, at - aim * 2.0 + side, at - aim * 0.5, at - aim * 2.0 - side])
		draw_colored_polygon(arrow, Color(DANGER, 0.75 + sin(time * 6.0) * 0.25))
		arrow.append(arrow[0])
		draw_polyline(arrow, Color(SHADE, 0.9), 1.0)

func _draw_ending() -> void:
	if not game.game_finished or String(game.ending_text) == "": return
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.01, 0.01, 0.03, 0.6))
	var lines: PackedStringArray = String(game.ending_text).split("\n", false)
	var title: String = lines[0]
	var restart: String = lines[lines.size() - 1] if lines.size() > 1 else ""
	var victory: bool = not title.contains("ABISMO")
	var accent: Color = GOLD if victory else Color("d2748f")
	var panel: Rect2 = Rect2(62, 64, 260, 90)
	draw_rect(panel, Color(SHADE, 0.94))
	draw_rect(panel, Color(accent, 0.8), false, 1.0)
	draw_rect(panel.grow(-3), Color(accent, 0.25), false, 1.0)
	for corner in [panel.position, Vector2(panel.end.x, panel.position.y), panel.end, Vector2(panel.position.x, panel.end.y)]:
		_diamond(corner, 3.0, accent, Color(SHADE, 1.0))
	draw_arc(Vector2(192, panel.position.y), 5.0, PI * 0.25, PI * 1.25, 12, accent, 1.0)
	var width: float = _centered(title_font, 192, panel.position.y + 26, title, 12, accent.lerp(PARCHMENT, 0.3))
	_ornament(192, panel.position.y + 33, 6.0, minf(width * 0.5, 80.0), 1.0)
	var y: float = panel.position.y + 48
	for i in range(1, lines.size() - 1):
		_centered(body_font, 192, y, lines[i], 8, PARCHMENT)
		y += 11
	if restart.contains("·"):
		var bits: PackedStringArray = restart.split("·")
		var key: String = bits[0].strip_edges()
		var label: String = bits[1].strip_edges()
		var label_width: float = _text_width(body_font, label, 7)
		var x: float = 192 - (label_width + 16) * 0.5
		x += _keycap(Vector2(x, panel.end.y - 18), key, accent) + 6
		_text(body_font, Vector2(x, panel.end.y - 10.5), label, 7, Color(PARCHMENT, 0.85))

func _card_alpha() -> float:
	if card == "" or card_time < 0.0 or game.game_finished: return 0.0
	return clampf(card_time / 0.5, 0.0, 1.0) * clampf((3.2 - card_time) / 0.8, 0.0, 1.0)
