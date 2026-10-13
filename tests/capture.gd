extends SceneTree
## Rendered screenshots for visual QA; this script needs a graphical renderer.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.camera.position_smoothing_enabled = false
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/vestibule.png")
	game.player.position = Vector2(632, 300)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/combat.png")
	for wave_index in range(3):
		for enemy in get_nodes_in_group("enemies"): enemy.take_damage(10000.0)
		await process_frame
		if wave_index < 2:
			game.wave_timer = 0.001
			await process_frame
			await process_frame
	game.player.position = Vector2(968, 312)
	game._interact()
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/treasure.png")
	print("CAPTURE: vestibule, combat and treasure rendered")
	quit()
