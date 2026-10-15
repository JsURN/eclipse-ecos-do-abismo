extends SceneTree
## Integration checks exercise the real scene/physics. Run with --headless --script.
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

func _run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(5)
	var view_size: Vector2 = game.camera.get_viewport_rect().size / game.camera.zoom
	_check(view_size.x >= 384 and view_size.y >= 216, "Closer camera retains a useful combat field")
	var camera_contained: bool = true
	for edge in [Vector2(32,112), Vector2(1072,112), Vector2(32,480), Vector2(1072,480)]:
		game.player.position = edge
		game.camera.snap_to_target()
		var visible: Rect2 = Rect2(game.camera.get_screen_center_position() - view_size / 2, view_size)
		camera_contained = camera_contained and game.camera.world_bounds.encloses(visible)
	_check(camera_contained, "Camera shows no area beyond dungeon bounds at all four edges")
	game.player.position = game.Dungeon.START
	game.camera.snap_to_target()
	var camera_before: Vector2 = game.camera.position
	game.player.position += Vector2(120, 0)
	await _frames(24)
	_check(game.camera.position.x > camera_before.x and game.camera.position == game.camera.position.round(), "Camera follows smoothly at integer pixel positions")
	game.player.position = game.Dungeon.START
	game.camera.snap_to_target()
	_check(game.dungeon.torches[0].texture == game.dungeon.torches[1].texture, "Localized lights share one cached texture")
	for i in range(80): game.effect(game.player.position, Color.WHITE)
	_check(get_nodes_in_group("visual_effects").size() <= 64, "Transient visual effects are capped")
	await _frames(45)
	_check(get_nodes_in_group("visual_effects").is_empty(), "Visual bursts expire and free themselves")
	_check(game.dungeon.ground is TileMapLayer, "Dungeon uses TileMapLayer")
	var states_present: bool = true
	for state in ["idle","walk","attack","dash","hurt","death"]:
		states_present = states_present and game.player.visual.sprite_frames.has_animation(state)
	_check(states_present,"Kael has six states from individually extracted frames")
	var texture: Texture2D = game.player.visual.sprite_frames.get_frame_texture("idle",0)
	_check(texture.resource_path.begins_with("res://assets/characters/kael/"),"Kael uses the supplied sheet, not the old generated atlas")
	Input.action_press("move_up")
	await _frames(10)
	Input.action_release("move_up")
	_check(game.player.visual.animation=="walk_up" and game.player.visual.frame>0,"Rear walk uses actual extracted frames and advances")
	game.player.attack()
	await _frames(8)
	_check(game.player.visual.animation=="attack" and game.player.visual.frame>0,"Attack frames advance after the real projectile is spawned")
	_check(game.player.get_child(0).shape.radius==5.0 and game.player.visual.position==Vector2(0,-30),"Animations preserve the foot pivot and player collision")
	# Let the test shot expire before later wall-blocking assertions.
	await _frames(110)
	game.player.take_damage(8.0)
	await _frames(9)
	_check(game.player.visual.animation=="hurt" and game.player.visual.frame>0,"Kael hurt reaction advances during actual damage feedback")
	game.player.health = 100.0
	game.player.invulnerability = 0.0
	game.player.position = game.Dungeon.START
	_check(game.dungeon.ground.tile_set.resource_path.ends_with("catacombs/catacombs.tres") and game.dungeon.ground.get_used_cells().size()>100,"Scenery is an editable TileSet applied across individual cells")
	_check(game.dungeon.navigation.get_point_path(Vector2i(10, 19), Vector2i(38, 18)).size() > 0, "Start and combat chamber are connected")
	_check(game.dungeon.navigation.get_point_path(Vector2i(38, 18), Vector2i(60, 19)).is_empty(), "Treasure gate blocks access before combat")
	var initial: Vector2 = game.player.position
	Input.action_press("move_right")
	await _frames(12)
	Input.action_release("move_right")
	_check(game.player.position.x > initial.x + 10, "Movement responds to input")
	Input.action_press("dash")
	await _frames(3)
	Input.action_release("dash")
	_check(game.player.dash_cooldown > 0.0 and game.player.invulnerability > 0.0, "Dash cooldown and invulnerability")
	await _frames(3)
	_check(game.player.visual.animation=="dash" and game.player.visual.frame>0,"Dash uses the extracted action frames")
	# Real wall collision: west edge of the start room is x=48.
	game.player.position = Vector2(56, 300)
	Input.action_press("move_left")
	await _frames(24)
	Input.action_release("move_left")
	_check(game.player.position.x >= 52.0, "Stone walls stop movement")
	# Sealed chest cannot reward the player before the chamber is cleared.
	game.player.position = game.Dungeon.CHEST
	game._interact()
	_check(not game.chest_open, "Chest reward is locked before clear")
	game.player.position = Vector2(496, 296)
	await _frames(4)
	_check(game.combat_started and game.wave == 1, "Entering chamber triggers combat")
	_check(game.dungeon.gates_closed[0] and game.dungeon.gates_closed[1], "Both combat doors close")
	_check(get_nodes_in_group("enemies").size() == 4, "First wave spawns four enemies")
	var supplied_enemies: bool = true
	for enemy in get_nodes_in_group("enemies"):
		var art: Texture2D = enemy.visual.sprite_frames.get_frame_texture("idle",0)
		supplied_enemies = supplied_enemies and art.resource_path.begins_with("res://assets/enemies/")
	_check(supplied_enemies,"All three enemy archetypes use supplied sprites")
	Input.action_press("move_left")
	await _frames(24)
	Input.action_release("move_left")
	_check(game.player.position.x >= 466.0, "Closed entrance gate physically stops escape")
	var obstacle_path: Array[Vector2i] = game.dungeon.navigation.get_id_path(Vector2i(32, 12), Vector2i(34, 12))
	_check(obstacle_path.size() > 3 and not obstacle_path.has(Vector2i(33, 12)), "Enemy path goes around pillar")
	# A projectile aimed into a pillar is consumed, not passed through it.
	game.spawn_projectile(Vector2(520, 200), Vector2.RIGHT, 18)
	await _frames(20)
	_check(_projectile_count() == 0, "Pillars block projectiles")
	var foe = get_nodes_in_group("enemies")[0]
	var before: float = float(foe.health)
	game.spawn_projectile(foe.position - Vector2(12, 0), Vector2.RIGHT, 5)
	await _frames(3)
	_check(float(foe.health) < before, "Player projectile damages enemy")
	var archer: Node2D
	var guardian: Node2D
	for enemy in get_nodes_in_group("enemies"):
		if enemy.enemy_type == "stalker": archer = enemy
		if enemy.enemy_type == "brute": guardian = enemy
	_check(guardian.max_health == 78.0 and guardian.speed < foe.speed, "Guardian retains heavy archetype")
	game.player.position = Vector2(580, 300)
	game.player.invulnerability = 0.0
	archer.position = Vector2(640, 300)
	archer.shot_timer = 0.0
	await _frames(2)
	_check(_projectile_count() > 0, "Spectral archer fires a projectile")
	_check(archer.visual.animation=="attack","Archer release pose is connected to AI firing")
	var hp_before: float = game.player.health
	await _frames(32)
	_check(game.player.health < hp_before, "Hostile projectile damages Kael")
	# Freeze the player in test only while exercising all waves and callbacks.
	game.player.invulnerability = 30.0
	for expected_wave in range(1, 4):
		_check(game.wave == expected_wave, "Progression to wave %d" % expected_wave)
		var enemies: Array[Node] = get_nodes_in_group("enemies")
		for enemy in enemies: enemy.take_damage(10000.0)
		await _frames(3)
		if expected_wave==1:
			await _frames(9)
			_check(is_instance_valid(enemies[0]) and enemies[0].visual.animation=="death" and enemies[0].visual.frame>0,"Enemy corpse plays the extracted death sequence before being freed")
		if expected_wave < 3:
			game.wave_timer = 0.001
			await _frames(5)
	await _frames(60)
	_check(game.room_cleared and not game.dungeon.gates_closed[0] and not game.dungeon.gates_closed[1], "Clear unlocks both doors")
	_check(game.player.level > 1, "Experience collection raises player level")
	_check(game.dungeon.navigation.get_point_path(Vector2i(38, 18), Vector2i(60, 19)).size() > 0, "Treasure route opens after clear")
	game.player.position = game.Dungeon.CHEST
	game.player.health = 10.0
	var damage_before: float = game.player.attack_damage
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	_check(game.chest_open and game.chest.region_rect.position.x == game.PROP_FRAME_WIDTH, "Chest opens visually")
	_check(game.player.health > 10.0 and game.player.attack_damage >= damage_before + 6, "Chest provides healing, XP and damage (including level-up bonus)")
	var rewarded_damage: float = game.player.attack_damage
	game._interact()
	_check(game.player.attack_damage == rewarded_damage, "Chest cannot reward twice")
	game.player.position = game.Dungeon.EXIT
	game._interact()
	_check(game.game_finished and game.ending_text.contains("CONQUISTADAS"), "Portal finishes the run with victory")
	game.queue_free()
	await _frames(3)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(3)
	game.player.take_damage(1000.0)
	_check(game.game_finished and game.player.visual.animation == "death", "Defeat triggers death animation and ending")
	await _frames(10)
	_check(game.player.visual.frame>0,"Kael death sequence keeps animating after defeat")
	var restart: InputEventKey = InputEventKey.new()
	restart.keycode = KEY_R
	restart.physical_keycode = KEY_R
	restart.pressed = true
	Input.parse_input_event(restart)
	await _frames(6)
	_check(current_scene != game and not current_scene.game_finished and current_scene.player.health == 100.0, "R reloads a fresh playable run")
	print("RESULT: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _projectile_count() -> int:
	var count: int = 0
	for node in game.get_children():
		if node is Area2D: count += 1
	return count
