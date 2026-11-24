extends Node2D
## EXPERIMENTAL isometric slice of Catacumbas do Eclipse (main.tscn is untouched).
##
## Scene layout:
##   LogicWorld (hidden)  - player/enemy bodies, projectiles, collision, A*.
##   CatacumbasIsometricas - projected floor + Y-sorted depth layer + lights.
##   Atmosphere           - mist, embers, motes, dust and vignette (visual only).
##   PixelCamera          - follows Kael's VIEW proxy, integer positions.
##   HUD                  - iso_hud.gd (own HUD; the top-down hud.gd is untouched).
## This node offers the same "game" interface main.gd gives to player.gd,
## enemy.gd and projectile.gd, translating world positions to the view, plus the
## read-only hooks the HUD uses (objective, action_prompt, wave_total, canvas_point).
const IsoMath = preload("res://isometric/iso_math.gd")
const Layout = preload("res://isometric/catacomb_layout.gd")
const IsoWorld = preload("res://isometric/iso_world.gd")
const IsoPlayer = preload("res://isometric/iso_player.gd")
const IsoActorView = preload("res://isometric/iso_actor_view.gd")
const IsoProjectileView = preload("res://isometric/iso_projectile_view.gd")
const OcclusionFader = preload("res://isometric/iso_occlusion_fader.gd")
const Enemy = preload("res://enemy.gd")
const Projectile = preload("res://projectile.gd")
const HUD = preload("res://isometric/iso_hud.gd")
const Effect = preload("res://effects.gd")
const PixelCamera = preload("res://pixel_camera.gd")
const InputSetup = preload("res://input_setup.gd")
const Atmosphere = preload("res://isometric/iso_atmosphere.gd")
const WAVES: int = 3

var logic: Node2D
var world: IsoWorld
## Alias: shared scripts reach the map through `game.dungeon`.
var dungeon: IsoWorld
var player: IsoPlayer
var player_view: IsoActorView
var camera: PixelCamera
var fader: OcclusionFader
var hud: HUD
var atmosphere: Atmosphere
var wave: int = 0
var combat_started: bool = false
var room_cleared: bool = false
var game_finished: bool = false
var chest_open: bool = false
var wave_timer: float = -1.0
## The HUD opens with an area title card instead of a start banner.
var notice: String = ""
var notice_timer: float = 0.0
var ending_text: String = ""

func _ready() -> void:
	InputSetup.ensure()
	logic = Node2D.new()
	logic.name = "LogicWorld"
	# Hidden: physics and AI still run, nothing in cartesian space is drawn.
	logic.visible = false
	add_child(logic)
	world = IsoWorld.new()
	world.logic_root = logic
	add_child(world)
	dungeon = world
	player = IsoPlayer.new()
	player.name = "Kael"
	player.game = self
	player.position = world.start_position
	player.died.connect(_on_player_died)
	player.leveled_up.connect(_on_player_leveled_up)
	logic.add_child(player)
	player_view = _attach_view(player, 8.0)
	player.view = player_view
	camera = PixelCamera.new()
	camera.world_bounds = world.camera_bounds
	camera.target = player_view
	add_child(camera)
	fader = OcclusionFader.new()
	fader.name = "OcclusionFader"
	fader.world = world
	fader.body = player
	fader.view = player_view
	add_child(fader)
	atmosphere = Atmosphere.new()
	add_child(atmosphere)
	atmosphere.setup(world, camera, 1)
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "HUD"
	# Above the atmosphere vignette (layer 1).
	canvas.layer = 2
	add_child(canvas)
	hud = HUD.new()
	hud.scale = Vector2(2, 2)
	hud.game = self
	canvas.add_child(hud)

func _process(delta: float) -> void:
	notice_timer = maxf(0.0, notice_timer - delta)
	if game_finished: return
	if not combat_started and Layout.COMBAT_TRIGGER.has_point(IsoMath.world_to_cell(player.position)):
		combat_started = true
		world.set_seals(true)
		_start_wave()
	if wave_timer >= 0.0:
		wave_timer -= delta
		if wave_timer <= 0.0:
			wave_timer = -1.0
			_start_wave()
	if Input.is_action_just_pressed("interact"):
		_interact()

func _start_wave() -> void:
	wave += 1
	_message("OS SELOS SE FECHAM  ·  ONDA %d / %d" % [wave, WAVES], 3.0)
	for i in range(1 + wave):
		var enemy: Enemy = Enemy.new()
		enemy.enemy_type = ["shade", "stalker", "brute"][i % 3]
		enemy.target = player
		enemy.game = self
		enemy.position = IsoMath.cell_center(Layout.SPAWNS[(i + wave * 2) % Layout.SPAWNS.size()])
		enemy.died.connect(_on_enemy_died)
		logic.add_child(enemy)
		_attach_view(enemy, 11.0 if enemy.enemy_type == "brute" else 8.0)
		effect(enemy.position, Color("59426c"))

func _attach_view(body: Node2D, shadow: float) -> IsoActorView:
	var view: IsoActorView = IsoActorView.new()
	view.bind(body, world, shadow)
	world.depth.add_child(view)
	return view

# --- interface used by player.gd / enemy.gd / projectile.gd / hud.gd ----------

func spawn_projectile(origin: Vector2, direction: Vector2, damage: float, hostile: bool = false) -> void:
	var projectile: Projectile = Projectile.new()
	projectile.position = origin
	projectile.direction = direction.normalized()
	projectile.damage = damage
	projectile.game = self
	projectile.hostile = hostile
	logic.add_child(projectile)
	var view: IsoProjectileView = IsoProjectileView.new()
	view.bind(projectile)
	world.depth.add_child(view)

## Orbs are not projected yet (see docs); XP is granted at the death point.
func spawn_experience(at: Vector2, amount: int) -> void:
	if game_finished: return
	effect(at, Color("65dddb"), "collect")
	player.gain_experience(amount)

func effect(at: Vector2, ink: Color, kind: String = "impact", direction: Vector2 = Vector2.RIGHT) -> void:
	if get_tree().get_nodes_in_group("visual_effects").size() >= 64: return
	var visual: Effect = Effect.new()
	visual.position = _view_point(at)
	visual.ink = ink
	visual.kind = kind
	visual.direction = IsoMath.direction_to_screen(direction)
	world.add_child(visual)

func dash_echo(at: Vector2, texture: Texture2D, flipped: bool, direction: Vector2) -> void:
	if get_tree().get_nodes_in_group("visual_effects").size() >= 64: return
	var visual: Effect = Effect.new()
	visual.position = _view_point(at)
	visual.kind = "dash"
	visual.ghost = texture
	visual.flipped = flipped
	visual.direction = IsoMath.direction_to_screen(direction)
	world.add_child(visual)

func damage_number(at: Vector2, amount: float, player_hit: bool = false) -> void:
	if get_tree().get_nodes_in_group("visual_effects").size() >= 64: return
	var visual: Effect = Effect.new()
	visual.position = _view_point(at)
	visual.kind = "number"
	visual.caption = str(int(amount))
	visual.ink = Color("ff947f") if player_hit else Color("e8c48b")
	world.add_child(visual)

func canvas_point(node: Node2D) -> Vector2:
	var view: Variant = node.get_meta("iso_view", null)
	if is_instance_valid(view): return (view as CanvasItem).get_global_transform_with_canvas().origin
	return node.get_global_transform_with_canvas().origin

func _view_point(at: Vector2) -> Vector2:
	return IsoMath.world_to_screen(at) - Vector2(0, world.height_at(at))

# --- progression (same rules and rewards as main.gd) -------------------------

func _on_enemy_died(enemy: Node2D, experience: int) -> void:
	spawn_experience(enemy.position, experience)
	if game_finished or not get_tree().get_nodes_in_group("enemies").is_empty(): return
	if wave < WAVES:
		wave_timer = 2.5
		_message("ECOS DISPERSOS  ·  próxima onda em 2,5s", 2.5)
	else:
		room_cleared = true
		player.reset_for_room()
		world.set_seals(false)
		_message("CÂMARA PURIFICADA  ·  o ossário ao sul guarda a relíquia", 5.0)

func _on_player_leveled_up(level: int) -> void:
	effect(player.position, Color("c4a66b"), "collect")
	_message("ASCENSÃO %d  ·  vida e dano aumentados" % level, 2.0)

func _on_player_died() -> void:
	game_finished = true
	ending_text = "O ABISMO RECLAMA KAEL\n\nR  ·  recomeçar"

func _interact() -> void:
	if room_cleared and not chest_open and player.position.distance_to(world.chest_position) < 30.0:
		chest_open = true
		world.open_chest()
		player.attack_damage += 6.0
		player.gain_experience(12)
		player.health = minf(player.max_health, player.health + 35.0)
		player.health_changed.emit(player.health, player.max_health)
		effect(world.chest_position, Color("c4a66b"), "collect")
		_message("RELÍQUIA LUNAR  ·  +6 dano  ·  +12 ecos  ·  cura", 5.0)
	elif chest_open and player.position.distance_to(world.exit_position) < 24.0:
		game_finished = true
		ending_text = "CATACUMBAS CONQUISTADAS\nKael atravessa o eclipse.\n\nR  ·  nova partida"

## --- HUD hooks (read-only) ---------------------------------------------------

func wave_total() -> int:
	return WAVES

## The single current goal shown under the area name (waves are shown separately).
func objective() -> String:
	if game_finished: return ""
	if not combat_started: return "Siga a leste, rumo à Câmara"
	if not room_cleared: return ""
	if not chest_open: return "Busque a relíquia no Ossário, ao sul"
	return "Atravesse o selo lunar nas Ruínas"

## Contextual prompt near the chest or the exit seal. "key" is empty when the
## player cannot act yet (the text then explains why).
func action_prompt() -> Dictionary:
	if game_finished: return {}
	if not chest_open and player.position.distance_to(world.chest_position) < 30.0:
		if room_cleared: return {"key": "E", "text": "Abrir o baú lunar"}
		return {"key": "", "text": "O baú está selado pelos ecos da câmara"}
	if player.position.distance_to(world.exit_position) < 24.0:
		if chest_open: return {"key": "E", "text": "Atravessar o selo lunar"}
		return {"key": "", "text": "O selo exige a relíquia do Ossário"}
	return {}

func _message(text: String, duration: float) -> void:
	notice = text
	notice_timer = duration

func _unhandled_input(event: InputEvent) -> void:
	if game_finished and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
