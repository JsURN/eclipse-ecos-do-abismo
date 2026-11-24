extends SceneTree
## Rendered screenshots of the isometric prototype for visual QA (needs a GPU window).
##   godot --path . --script tests/iso_capture.gd
## Images are written to artifacts/iso_*.png (ignored by Git).
const IsoMath = preload("res://isometric/iso_math.gd")
var game: Node2D

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	game = load("res://isometric/isometric_prototype.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.notice_timer = 0.0
	# Onboarding hints and the first area title card are on screen at ~2 s.
	game.camera.snap_to_target()
	await create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	_save("iso_hud_start")
	await _shot("iso_vestibule", game.world.start_position)
	await _shot("iso_corridor", IsoMath.cell_center(Vector2i(19, 12)))
	# Kael north of (behind) and south of (in front of) the same pillar.
	await _shot("iso_behind_pillar", IsoMath.cell_center(Vector2i(30, 8)))
	await _shot("iso_front_pillar", IsoMath.cell_center(Vector2i(32, 10)))
	var hidden_spot: Vector2 = _cell_behind_full_wall()
	await _shot("iso_behind_wall", hidden_spot)
	await _shot("iso_dais", IsoMath.cell_center(Vector2i(37, 17)))
	game.world.set_seals(true)
	await _shot("iso_seals", IsoMath.cell_center(Vector2i(36, 24)))
	game.world.set_seals(false)
	await _shot("iso_crypt", IsoMath.cell_center(Vector2i(35, 39)))
	await _shot("iso_ruins", IsoMath.cell_center(Vector2i(53, 37)))
	await _shot("iso_passage", IsoMath.cell_center(Vector2i(45, 40)))
	await _shot("iso_arch", IsoMath.cell_center(Vector2i(17, 8)))
	await _shot("iso_exit", IsoMath.cell_center(Vector2i(53, 37)))
	game.room_cleared = true
	await _shot("iso_hud_prompt", IsoMath.cell_center(Vector2i(35, 41)))
	game.player.position = IsoMath.cell_center(Vector2i(35, 41))
	game._interact()
	await _shot("iso_chest_open", IsoMath.cell_center(Vector2i(34, 40)))
	game.room_cleared = false
	game.chest_open = false
	# Combat feedback in the projection.
	game.player.position = IsoMath.cell_center(Vector2i(36, 21))
	game.combat_started = true
	game._start_wave()
	game.camera.snap_to_target()
	await create_timer(0.8).timeout
	game.player.attack()
	await create_timer(0.08).timeout
	await RenderingServer.frame_post_draw
	_save("iso_combat")
	game.game_finished = true
	game.ending_text = "CATACUMBAS CONQUISTADAS\nKael atravessa o eclipse.\n\nR  ·  nova partida"
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	_save("iso_ending")
	print("ISO CAPTURE DONE; wall test spot=", hidden_spot)
	quit()

func _shot(file: String, at: Vector2) -> void:
	game.player.position = at
	game.player.velocity = Vector2.ZERO
	await physics_frame
	game.player_view._sync(0.0)
	game.camera.snap_to_target()
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	_save(file)

## A walkable cell whose screen-front neighbour (+1,+1) is a full-height wall.
func _cell_behind_full_wall() -> Vector2:
	for cell: Vector2i in game.world.occluders:
		var behind: Vector2i = cell - Vector2i(1, 1)
		if game.world.is_walkable(behind) and String(game.world.occluders[cell][0].name).begins_with("Wall") and game.world.room_name(IsoMath.cell_center(behind)) == "Passagem das Cinzas":
			return IsoMath.cell_center(behind)
	return game.world.start_position

func _save(file: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	image.save_png("res://artifacts/%s.png" % file)
