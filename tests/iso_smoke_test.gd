extends SceneTree
## Integration checks for the isometric prototype (real scene, physics and input).
##   godot --headless --path . --script tests/iso_smoke_test.gd
const IsoMath = preload("res://isometric/iso_math.gd")
const Layout = preload("res://isometric/catacomb_layout.gd")
var failures: int = 0
var checks: int = 0
var game: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition: print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _frames(count: int) -> void:
	for i in range(count): await physics_frame

func _place(cell: Vector2i) -> void:
	game.player.position = IsoMath.cell_center(cell)
	game.player.velocity = Vector2.ZERO
	game.player.dash_timer = 0.0
	game.player_view._sync(0.0)
	game.camera.snap_to_target()

## Holds actions for `count` physics frames and returns the WORLD displacement.
func _hold(actions: Array, count: int) -> Vector2:
	var before: Vector2 = game.player.position
	for action in actions: Input.action_press(action)
	await _frames(count)
	for action in actions: Input.action_release(action)
	await _frames(1)
	return game.player.position - before

func _run() -> void:
	# --- pure coordinate contract -------------------------------------------
	var sample: Vector2 = Vector2(123.5, -47.25)
	_check(IsoMath.screen_to_world(IsoMath.world_to_screen(sample)).is_equal_approx(sample), "World <-> screen projection round-trips")
	_check(IsoMath.BASIS.basis_xform(sample).is_equal_approx(IsoMath.world_to_screen(sample)), "Projection basis matches position transform")
	_check(IsoMath.direction_to_screen(IsoMath.input_to_world(Vector2.UP)).is_equal_approx(Vector2.UP), "W moves straight up on screen")
	_check(IsoMath.direction_to_screen(IsoMath.input_to_world(Vector2.RIGHT)).is_equal_approx(Vector2.RIGHT), "D moves straight right on screen")
	_check(IsoMath.input_to_world(Vector2(1, -1).normalized()).is_equal_approx(Vector2(0, -1)), "W+D follows the grid axis (parallel to walls)")
	var widths_equal: bool = true
	for row in Layout.ROWS: widths_equal = widths_equal and row.length() == Layout.ROWS[0].length()
	_check(widths_equal, "Layout rows share one width")

	game = load("res://isometric/isometric_prototype.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(5)
	var world: Node2D = game.world
	_check(world.ground is TileMapLayer and world.ground.tile_set.tile_shape == TileSet.TILE_SHAPE_ISOMETRIC, "Floor is an isometric diamond TileMapLayer")
	var aligned: bool = true
	for cell in [Vector2i(3, 5), Vector2i(36, 15), Vector2i(53, 41)]:
		aligned = aligned and (world.ground.map_to_local(cell) + world.ground.position).is_equal_approx(IsoMath.cell_to_screen(cell))
	_check(aligned, "TileMapLayer cells line up with IsoMath projection")
	_check(world.depth.y_sort_enabled and game.player_view.get_parent() == world.depth, "Kael's view is Y-sorted with walls and props")
	_check(not game.logic.visible and game.player.get_parent() == game.logic, "Gameplay bodies live in the hidden logic layer")

	# --- continuous map ------------------------------------------------------
	var start: Vector2i = Layout.find("K")
	var reached: Dictionary = {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + step
			if not reached.has(next) and world.is_walkable(next):
				reached[next] = true
				frontier.append(next)
	var walkable: int = 0
	for cell in world.floor_cells: if world.is_walkable(cell): walkable += 1
	_check(reached.size() == walkable and walkable > 600, "Every walkable cell (%d) is one connected world" % walkable)
	var named: Dictionary = {}
	for cell in reached: named[world.room_name(IsoMath.cell_center(cell))] = true
	_check(named.size() >= 8, "Exploration spans %d named areas" % named.size())
	# The chest itself is a solid prop; path to the cell in front of it.
	_check(world.navigation.get_point_path(start, Layout.find("C") + Vector2i(0, -1)).size() > 0 and world.navigation.get_point_path(start, Layout.find("E")).size() > 0, "A* reaches the chest and the exit seal")
	var spawns_ok: bool = true
	for cell in Layout.SPAWNS: spawns_ok = spawns_ok and world.is_walkable(cell) and Layout.COMBAT_TRIGGER.has_point(cell)
	_check(spawns_ok, "Enemy spawns are walkable cells inside the chamber")

	# --- movement ------------------------------------------------------------
	_place(Vector2i(8, 8))
	var view_before: Vector2 = game.player_view.position
	var moved: Vector2 = await _hold(["move_right"], 12)
	var view_delta: Vector2 = game.player_view.position - view_before
	_check(view_delta.x > 15 and absf(view_delta.y) <= 1.0, "D moves Kael right on screen (%s)" % view_delta)
	_check(moved.normalized().is_equal_approx(Vector2(1, -1).normalized()) or moved.normalized().distance_to(Vector2(1, -1).normalized()) < 0.02, "D maps to the world (1,-1) diagonal")
	var cardinal_speed: float = moved.length()
	var horizontal_screen: float = view_delta.x
	_place(Vector2i(8, 8))
	view_before = game.player_view.position
	moved = await _hold(["move_up"], 12)
	view_delta = game.player_view.position - view_before
	_check(view_delta.y < -6 and absf(view_delta.x) <= 1.0, "W moves Kael up on screen (%s)" % view_delta)
	_check(absf(absf(view_delta.y) * 2.0 - horizontal_screen) <= 2.0, "Same world speed reads 2:1 on screen (%.0f px across vs %.0f px up)" % [horizontal_screen, absf(view_delta.y)])
	_place(Vector2i(8, 8))
	moved = await _hold(["move_up", "move_right"], 12)
	_check(absf(moved.x) < 0.5 and moved.y < -10, "W+D walks along the grid axis")
	_check(absf(moved.length() - cardinal_speed) < 2.0, "Diagonal input keeps the same world speed (%.1f vs %.1f)" % [moved.length(), cardinal_speed])
	_check(game.player.visual.animation == "walk_up" or game.player.visual.animation == "idle_up", "Moving away from the camera shows Kael's back")
	_place(Vector2i(8, 8))
	await _hold(["move_down", "move_left"], 6)
	_check(not game.player.visual.animation.ends_with("_up"), "Moving toward the camera shows Kael's front")

	# --- collision -----------------------------------------------------------
	_place(Vector2i(8, 3))
	await _hold(["move_up"], 40)
	_check(game.player.position.y >= 3 * 16 + 4.0 and game.player.position.x >= 3 * 16, "Back wall stops Kael (%s)" % game.player.position)
	_place(Vector2i(8, 12))
	await _hold(["move_down"], 40)
	_check(world.is_floor(IsoMath.world_to_cell(game.player.position)) and game.player.position.y <= 14 * 16 - 4.0, "Lowered front wall still blocks Kael")
	var pillar: Vector2 = IsoMath.cell_center(Vector2i(31, 9))
	# S walks world (+1,+1): from (29,7) the path runs straight into the pillar at (31,9).
	_place(Vector2i(29, 7))
	var closest: float = 999.0
	Input.action_press("move_down")
	for i in range(40):
		await physics_frame
		closest = minf(closest, game.player.position.distance_to(pillar))
	Input.action_release("move_down")
	_check(closest >= 7.0 + 5.0 - 0.6 and closest < 14.0, "Pillar footprint blocks Kael (closest %.1f)" % closest)
	_place(Vector2i(4, 4))
	await _hold(["move_left"], 40)
	_check(world.is_floor(IsoMath.world_to_cell(game.player.position)), "Chamfered corners never let Kael into rock")

	# --- depth ordering & contextual transparency ----------------------------
	var pillar_sprite: Sprite2D = world.props_by_cell[Vector2i(31, 9)]
	# Same screen column as the pillar: (-1,-1) is directly behind, (+1,+1) directly in front.
	_place(Vector2i(30, 8))
	await _frames(2)
	_check(game.player_view.position.y < pillar_sprite.position.y, "Behind the pillar Kael sorts before it")
	await _frames(30)
	_check(game.fader.is_faded(pillar_sprite), "A pillar hiding Kael becomes translucent")
	_place(Vector2i(32, 10))
	await _frames(40)
	_check(game.player_view.position.y > pillar_sprite.position.y and pillar_sprite.modulate.a == 1.0, "In front of the pillar Kael sorts after it and it is opaque")
	var wall_cell: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in world.occluders:
		if String(world.occluders[cell][0].name).begins_with("Wall") and world.is_walkable(cell - Vector2i(1, 1)):
			wall_cell = cell
			break
	var wall_sprite: Sprite2D = world.occluders[wall_cell][0]
	_place(wall_cell - Vector2i(1, 1))
	await _frames(30)
	_check(game.player_view.position.y < wall_sprite.position.y and game.fader.is_faded(wall_sprite), "Back wall in front of Kael sorts after him and fades")
	_place(Vector2i(8, 8))
	await _frames(40)
	_check(wall_sprite.modulate.a == 1.0, "Wall regains full opacity once Kael leaves")
	var low_walls: int = 0
	var full_walls: int = 0
	for child in world.depth.get_children():
		if child is Sprite2D and String(child.name).begins_with("Wall"):
			if child.texture.resource_path.ends_with("wall_low.png"): low_walls += 1
			elif child.texture.resource_path.ends_with("wall_full.png"): full_walls += 1
	_check(low_walls > 50 and full_walls > 50, "Front walls are lowered (%d) and back walls full height (%d)" % [low_walls, full_walls])

	# --- visual polish (art kit, decoration, atmosphere) ----------------------
	var placeholders: int = 0
	var connected_tops: int = 0
	var decorated_walls: int = 0
	for child in world.depth.get_children():
		if child is Sprite2D and child.texture and child.texture.resource_path.contains("placeholder"): placeholders += 1
		if child is Sprite2D and child.has_meta("wall_row"):
			if child.region_rect.position.x > 0.0: connected_tops += 1
			if int(child.get_meta("wall_row")) >= 5 and child.texture.resource_path.ends_with("wall_full.png"): decorated_walls += 1
	_check(placeholders == 0 and connected_tops > 100, "Walls use the art kit with connected tops (%d), no placeholders" % connected_tops)
	_check(decorated_walls >= 8 and world.arches.size() >= 10 and world.sconces.size() >= 4, "Back walls carry decorations (%d), arches (%d) and sconces (%d)" % [decorated_walls, world.arches.size(), world.sconces.size()])
	_check(world.detail.get_used_cells().size() > 40 and world.wall_shade.get_used_cells().size() > 150, "Floor has decals and wall-base shading")
	_check(world.occluders.has(Vector2i(15, 8)) and world.occluders[Vector2i(15, 8)][0].name.begins_with("Arch"), "Arches are occluders, so they fade over Kael")
	var atmosphere_ok: bool = is_instance_valid(game.atmosphere) and game.atmosphere.dust.emitting and game.atmosphere.mist_patches.size() > 0
	_check(atmosphere_ok and world.mist.size() > 0 and world.flames.size() >= 8, "Atmosphere: dust, mist and embers over %d flames" % world.flames.size())
	_check(game.get_node("HUD").layer > game.atmosphere.get_node("Vignette").layer, "Vignette stays under the HUD")
	_check(game.hud.get_script().resource_path.ends_with("iso_hud.gd") and game.hud.revealed.size() > 20, "Isometric HUD with a minimap revealed by exploration (%d cells)" % game.hud.revealed.size())
	_check((game.objective() != "") != (game.combat_started and not game.room_cleared) and game.action_prompt().is_empty(), "Objective line (waves replace it in combat); no prompt away from chest/exit")
	game.hud.visited.erase("Fenda Colapsada")
	_place(Vector2i(45, 40))
	await _frames(3)
	var fenda_card: bool = game.hud.card == "Fenda Colapsada"
	_place(Vector2i(35, 39))
	await _frames(3)
	_check(fenda_card and game.hud.card != "Fenda Colapsada", "Area title card is dropped when Kael leaves that area")
	_check(world.rock.get_used_cells().size() > 300 and world.glow.water_cells.size() >= 15 and world.shafts.size() >= 3, "Rock mass, water pools and moonlight shafts are built")

	# --- elevation -----------------------------------------------------------
	_place(Vector2i(36, 13))
	await _frames(2)
	_check(game.player_view.lift_root.position.y == -6.0 and game.player_view.position == IsoMath.world_to_screen(game.player.position).round(), "Dais lifts the sprite without moving the sort point")

	# --- camera --------------------------------------------------------------
	var view_size: Vector2 = game.camera.get_viewport_rect().size / game.camera.zoom
	_check(game.camera.zoom == Vector2(2, 2) and view_size.x >= 384, "Camera keeps the integer 2x pixel zoom")
	_place(Vector2i(10, 8))
	var camera_before: Vector2 = game.camera.position
	game.player.position += Vector2(48, -48)
	await _frames(24)
	_check(game.camera.position.x > camera_before.x and game.camera.position == game.camera.position.round(), "Camera follows smoothly at integer pixel positions")
	var contained: bool = true
	for cell in [Vector2i(4, 6), Vector2i(53, 43), Vector2i(29, 41), Vector2i(44, 6)]:
		_place(cell)
		var visible: Rect2 = Rect2(game.camera.get_screen_center_position() - view_size / 2, view_size)
		contained = contained and game.camera.world_bounds.encloses(visible)
	_check(contained, "Camera stays inside the projected map bounds")

	# --- dash ----------------------------------------------------------------
	_place(Vector2i(8, 8))
	await _frames(2)
	game.player.dash_cooldown = 0.0
	var dash_from: Vector2 = game.player.position
	Input.action_press("move_right")
	Input.action_press("dash")
	await _frames(3)
	Input.action_release("dash")
	_check(game.player.dash_cooldown > 0.8 and game.player.invulnerability > 0.0, "Dash keeps its 0.9s cooldown and invulnerability")
	await _frames(8)
	Input.action_release("move_right")
	var dash_move: Vector2 = game.player.position - dash_from
	_check(dash_move.length() > 40.0 and dash_move.normalized().distance_to(Vector2(1, -1).normalized()) < 0.05, "Dash bursts along the isometric input direction")

	# --- encounter -----------------------------------------------------------
	_place(Vector2i(36, 21))
	await _frames(4)
	_check(game.combat_started and game.wave == 1 and get_nodes_in_group("enemies").size() == 2, "Entering the chamber starts wave 1")
	var sealed: bool = true
	for seal in world.seals: sealed = sealed and seal.closed
	_check(sealed and world.navigation.is_point_solid(Vector2i(36, 26)), "All chamber passages are sealed")
	var enemy_views: bool = true
	for enemy in get_nodes_in_group("enemies"):
		enemy_views = enemy_views and enemy.has_meta("iso_view") and enemy.get_meta("iso_view").get_parent() == world.depth
	_check(enemy_views, "Every enemy has a Y-sorted view")
	game.player.invulnerability = 30.0
	_place(Vector2i(36, 24))
	await _hold(["move_down"], 40)
	_check(IsoMath.world_to_cell(game.player.position).y < 26, "Closed seal physically blocks the south passage")
	var foe: Node2D = get_nodes_in_group("enemies")[0]
	var foe_start: Vector2 = foe.position
	await _frames(30)
	_check(foe.position.distance_to(game.player.position) < foe_start.distance_to(game.player.position), "Enemies path toward Kael on the logic grid")
	var health_before: float = foe.health
	game.spawn_projectile(foe.position - Vector2(14, 0), Vector2.RIGHT, 5)
	var projectile_views: int = 0
	for child in world.depth.get_children(): if String(child.name).begins_with("ProjectileView"): projectile_views += 1
	_check(projectile_views >= 1, "Projectiles get an isometric view")
	await _frames(4)
	_check(foe.health < health_before, "Projectile damages an enemy in world space")
	var screen_point: Vector2 = game.canvas_point(foe)
	_check(screen_point.is_equal_approx(foe.get_meta("iso_view").get_global_transform_with_canvas().origin), "HUD indicators use the projected enemy position")
	var level_before: int = game.player.level
	for expected in range(1, 4):
		_check(game.wave == expected, "Progression to wave %d" % expected)
		for enemy in get_nodes_in_group("enemies"): enemy.take_damage(10000.0)
		await _frames(3)
		if expected < 3:
			game.wave_timer = 0.001
			await _frames(4)
	await _frames(30)
	var opened: bool = true
	for seal in world.seals: opened = opened and not seal.closed
	_check(game.room_cleared and opened, "Clearing the chamber opens the seals")
	_check(game.player.level > level_before, "Experience still levels Kael up")
	_place(Layout.find("C") + Vector2i(0, -1))
	_check(String(game.action_prompt().get("key", "")) == "E", "Chest shows the E prompt once the chamber is clear")
	var damage_before: float = game.player.attack_damage
	game._interact()
	_check(game.chest_open and game.player.attack_damage >= damage_before + 6.0, "Relic chest rewards once")
	_check(world.props_by_cell[Layout.find("C")].texture.resource_path.ends_with("chest_open.png"), "Opened chest shows its open art")
	game._interact()
	_check(game.player.attack_damage < damage_before + 12.0, "Chest cannot reward twice")
	_place(Layout.find("E"))
	game._interact()
	_check(game.game_finished and game.ending_text.contains("CONQUISTADAS"), "Exit seal finishes the run with victory")
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://main.tscn", "Original top-down scene remains the main scene")
	print("RESULT: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
