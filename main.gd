extends Node2D

const Player = preload("res://player.gd")
const Enemy = preload("res://enemy.gd")
const Projectile = preload("res://projectile.gd")
const ExperienceOrb = preload("res://experience_orb.gd")
const Dungeon = preload("res://dungeon.gd")
const HUD = preload("res://hud.gd")
const Effect = preload("res://effects.gd")
const PixelCamera = preload("res://pixel_camera.gd")

var player: Player
var dungeon: Dungeon
var hud: HUD
var wave: int = 0
var combat_started: bool = false
var room_cleared: bool = false
var game_finished: bool = false
var chest_open: bool = false
var wave_timer: float = -1.0
var notice: String = "KAEL, O ESQUECIDO  ·  siga os ecos azuis"
var notice_timer: float = 5.0
var ending_text: String = ""
var chest: Sprite2D
var portal: Sprite2D
var camera: PixelCamera

func _ready() -> void:
	_ensure_input_map()
	dungeon = Dungeon.new()
	dungeon.name = "CatacumbasDoEclipse"
	add_child(dungeon)
	player = Player.new()
	player.name = "Kael"
	player.game = self
	player.position = Dungeon.START
	player.died.connect(_on_player_died)
	player.leveled_up.connect(_on_player_leveled_up)
	dungeon.actors.add_child(player)
	camera = PixelCamera.new()
	camera.target = player
	add_child(camera)
	chest = _prop(Dungeon.CHEST, 0)
	portal = _prop(Dungeon.EXIT, 2)
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)
	hud = HUD.new()
	hud.game = self
	canvas.add_child(hud)

func _process(delta: float) -> void:
	notice_timer = maxf(0.0, notice_timer - delta)
	if game_finished: return
	if not combat_started and player.position.x > 488.0 and Dungeon.COMBAT.has_point(player.position):
		combat_started = true
		dungeon.set_gate(0, true)
		effect(dungeon.gate_positions[0], Color("bd627e"), "gate")
		_start_wave()
	if wave_timer >= 0.0:
		wave_timer -= delta
		if wave_timer <= 0.0:
			wave_timer = -1.0
			_start_wave()
	if Input.is_action_just_pressed("interact"):
		_interact()
	if room_cleared:
		portal.modulate = Color(0.8, 1.0, 1.0, 0.85 + sin(Time.get_ticks_msec() * 0.004) * 0.15)

func _start_wave() -> void:
	wave += 1
	_message("AS GRADES SE FECHAM  ·  ONDA %d / 3" % wave, 3.0)
	var points: Array[Vector2] = [Vector2(552, 184), Vector2(712, 184), Vector2(568, 392), Vector2(728, 392), Vector2(632, 248), Vector2(760, 312)]
	for i in range(3 + wave):
		var enemy: Enemy = Enemy.new()
		enemy.enemy_type = ["shade", "stalker", "brute"][i % 3]
		enemy.target = player
		enemy.game = self
		enemy.position = points[i]
		enemy.died.connect(_on_enemy_died)
		dungeon.actors.add_child(enemy)
		effect(enemy.position, Color("59426c"))

func spawn_projectile(origin: Vector2, direction: Vector2, damage: float, hostile: bool = false) -> void:
	var projectile: Projectile = Projectile.new()
	projectile.position = origin
	projectile.direction = direction.normalized()
	projectile.damage = damage
	projectile.game = self
	projectile.hostile = hostile
	add_child(projectile)

func spawn_experience(at: Vector2, amount: int) -> void:
	var orb: ExperienceOrb = ExperienceOrb.new()
	orb.position = at
	orb.amount = amount
	orb.target = player
	orb.game = self
	orb.collected.connect(_on_experience_collected)
	add_child(orb)

func effect(at: Vector2, ink: Color, kind: String = "impact", direction: Vector2 = Vector2.RIGHT) -> void:
	if get_tree().get_nodes_in_group("visual_effects").size() >= 64: return
	var visual: Effect = Effect.new()
	visual.position = at
	visual.ink = ink
	visual.kind = kind
	visual.direction = direction
	add_child(visual)

func dash_echo(at: Vector2, texture: Texture2D, flipped: bool, direction: Vector2) -> void:
	if get_tree().get_nodes_in_group("visual_effects").size() >= 64: return
	var visual: Effect = Effect.new()
	visual.position = at
	visual.kind = "dash"
	visual.ghost = texture
	visual.flipped = flipped
	visual.direction = direction
	add_child(visual)

func damage_number(at: Vector2, amount: float, player_hit: bool = false) -> void:
	if get_tree().get_nodes_in_group("visual_effects").size() >= 64: return
	var visual: Effect = Effect.new()
	visual.position = at
	visual.kind = "number"
	visual.caption = str(int(amount))
	visual.ink = Color("ff947f") if player_hit else Color("e8c48b")
	add_child(visual)

func _on_enemy_died(enemy: Node2D, experience: int) -> void:
	spawn_experience(enemy.position, experience)
	# Enemy removes itself from the group before emitting, avoiding deferred-free races.
	if game_finished or not get_tree().get_nodes_in_group("enemies").is_empty(): return
	if wave < 3:
		wave_timer = 2.5
		_message("ECOS DISPERSOS  ·  próxima onda em 2,5s", 2.5)
	else:
		room_cleared = true
		player.reset_for_room()
		dungeon.set_gate(0, false)
		dungeon.set_gate(1, false)
		portal.region_rect.position.x = 72
		for at in dungeon.gate_positions: effect(at, Color("65dddb"), "gate")
		_message("CÂMARA PURIFICADA  ·  o relicário está aberto", 5.0)

func _on_experience_collected(amount: int) -> void:
	if not game_finished: player.gain_experience(amount)

func _on_player_leveled_up(level: int) -> void:
	effect(player.position, Color("c4a66b"), "collect")
	_message("ASCENSÃO %d  ·  vida e dano aumentados" % level, 2.0)

func _on_player_died() -> void:
	game_finished = true
	ending_text = "O ABISMO RECLAMA KAEL\n\nR  ·  recomeçar"

func _interact() -> void:
	if room_cleared and not chest_open and player.position.distance_to(Dungeon.CHEST) < 38.0:
		chest_open = true
		chest.region_rect.position.x = 24
		player.attack_damage += 6.0
		player.gain_experience(12)
		player.health = minf(player.max_health, player.health + 35.0)
		player.health_changed.emit(player.health, player.max_health)
		effect(Dungeon.CHEST, Color("c4a66b"), "collect")
		_message("RELÍQUIA LUNAR  ·  +6 dano  ·  +12 ecos  ·  cura", 5.0)
	elif chest_open and player.position.distance_to(Dungeon.EXIT) < 32.0:
		game_finished = true
		ending_text = "CATACUMBAS CONQUISTADAS\nKael atravessa o eclipse.\n\nR  ·  nova partida"

func interaction_prompt() -> String:
	if game_finished: return ""
	if player.position.distance_to(Dungeon.CHEST) < 38.0:
		return "Baú aberto  ·  siga até o selo lunar" if chest_open else "E  ·  abrir baú lunar"
	if player.position.distance_to(Dungeon.EXIT) < 38.0:
		return "E  ·  atravessar o selo" if chest_open else "Encontre a relíquia no baú"
	if not combat_started: return "Explore a passagem a leste e entre na câmara."
	if room_cleared: return "Ecos livres  ·  procure o baú no relicário a leste."
	return "Derrote as três ondas para abrir as grades."

func _message(text: String, duration: float) -> void:
	notice = text
	notice_timer = duration

func _prop(at: Vector2, frame: int) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = preload("res://assets/props.png")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(frame * 24, 0, 24, 32)
	sprite.position = at - Vector2(0, 8)
	dungeon.actors.add_child(sprite)
	return sprite

func _unhandled_input(event: InputEvent) -> void:
	if game_finished and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func _ensure_input_map() -> void:
	var keys: Dictionary = {"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "attack": [KEY_SPACE, KEY_J], "dash": [KEY_SHIFT], "interact": [KEY_E]}
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in keys[action]:
			var event: InputEventKey = InputEventKey.new()
			event.physical_keycode = int(key)
			if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	if not InputMap.action_has_event("attack", mouse): InputMap.action_add_event("attack", mouse)
