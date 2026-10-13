extends SceneTree
## Rendered screenshots for visual QA; this script needs a graphical renderer.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.camera.snap_to_target()
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	_save("vestibule")
	game.player.position = Vector2(632, 300)
	game.camera.snap_to_target()
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	_save("combat")
	for wave_index in range(3):
		for enemy in get_nodes_in_group("enemies"): enemy.take_damage(enemy.health)
		await process_frame
		if wave_index < 2:
			game.wave_timer = 0.001
			await process_frame
			await process_frame
	await create_timer(0.7).timeout
	game.player.position = Vector2(968, 312)
	game.camera.snap_to_target()
	game._interact()
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	_save("treasure")
	# Dedicated visual check for attack/impact/afterimage and projectile identity.
	game.player.position = Vector2(632, 300)
	game.camera.snap_to_target()
	game.notice_timer = 0.0
	game.player.attack()
	game.dash_echo(game.player.position - Vector2(15, 0), game.player.visual.sprite_frames.get_frame_texture("dash", 0), false, Vector2.RIGHT)
	game.effect(Vector2(678, 294), Color("c4f4ed"), "impact")
	game.spawn_projectile(Vector2(690, 264), Vector2.LEFT, 10, true)
	game.spawn_projectile(Vector2(650, 304), Vector2.RIGHT, 18)
	await create_timer(0.06).timeout
	await RenderingServer.frame_post_draw
	_save("feedback")
	print("CAPTURE: vestibule, combat, treasure and feedback rendered")
	quit()

func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png("res://artifacts/%s.png" % name)
	# Match the default 3x integer window, keeping each source pixel intact.
	image.resize(image.get_width() * 3, image.get_height() * 3, Image.INTERPOLATE_NEAREST)
	image.save_png("res://artifacts/%s_window.png" % name)
