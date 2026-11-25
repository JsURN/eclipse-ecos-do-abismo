extends SceneTree
## Close-ups of every arched passage of the isometric prototype, for visual QA of the
## portals (needs a GPU window):
##   godot --path . --script tests/iso_passage_capture.gd
## Images go to artifacts/passage_*.png (ignored by Git). HUD hidden; the camera is
## framed on the passage itself, with Kael beside it, behind it or walking under it.
## Passages: four along the grid y axis (the arch spans down-left on screen) and one
## along the x axis (spans down-right), so both isometric orientations are covered.
const IsoMath = preload("res://isometric/iso_math.gd")

## Passage centres in cells (world = cells * 16).
const GATE: Vector2 = Vector2(15.5, 8.5)       # vestibule -> ash corridor, y axis, 3 cells
const GALLERY: Vector2 = Vector2(46.5, 15.5)   # chamber -> gallery, y axis, 3 cells, sealable
const DESCENT: Vector2 = Vector2(36.5, 26.5)   # chamber -> crypt descent, x axis, 3 cells, sealable
const RIFT: Vector2 = Vector2(42.5, 39.0)      # ossuary -> rift, y axis, 2 cells
const RUINED: Vector2 = Vector2(26.5, 13.5)    # ash corridor -> chamber, y axis, collapsed, sealable

## [file, passage centre, Kael position (cells), zoom, seals closed]
const SHOTS: Array = [
	["passage_y_gate", GATE, Vector2(18.5, 8.5), 2, false],
	["passage_y_gate_detail", GATE, Vector2(18.5, 8.5), 3, false],
	["passage_y_gate_behind", GATE, Vector2(14.0, 8.5), 3, false],
	["passage_y_gate_under", GATE, Vector2(15.3, 8.6), 3, false],
	["passage_y_gallery", GALLERY, Vector2(48.5, 16.0), 3, false],
	["passage_y_gallery_sealed", GALLERY, Vector2(48.5, 16.0), 3, true],
	["passage_x_descent", DESCENT, Vector2(36.5, 28.5), 3, false],
	["passage_x_descent_context", DESCENT, Vector2(36.5, 28.5), 2, false],
	["passage_x_descent_sealed", DESCENT, Vector2(36.5, 28.5), 3, true],
	["passage_x_descent_behind", DESCENT, Vector2(36.5, 24.5), 3, false],
	["passage_x_descent_under", DESCENT, Vector2(36.5, 26.3), 3, false],
	["passage_y_rift", RIFT, Vector2(44.5, 40.0), 3, false],
	["passage_y_ruined", RUINED, Vector2(28.5, 14.5), 3, false],
	["passage_y_ruined_sealed", RUINED, Vector2(28.5, 14.5), 3, true],
]

var game: Node2D

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	game = load("res://isometric/isometric_prototype.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.notice_timer = 0.0
	game.get_node("HUD").visible = false
	var focus: Node2D = Node2D.new()
	game.add_child(focus)
	game.camera.target = focus
	await create_timer(0.3).timeout
	for shot: Array in SHOTS:
		game.world.set_seals(bool(shot[4]))
		game.camera.zoom = Vector2.ONE * float(shot[3])
		# Frame the arch: its feet sit a little below the centre of the view.
		focus.global_position = IsoMath.world_to_screen(Vector2(shot[1]) * IsoMath.CELL) - Vector2(0, 38)
		game.player.position = Vector2(shot[2]) * IsoMath.CELL
		game.player.velocity = Vector2.ZERO
		await physics_frame
		game.player_view._sync(0.0)
		game.camera.snap_to_target()
		await create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
		image.save_png("res://artifacts/%s.png" % shot[0])
	print("PASSAGE CAPTURE DONE: %d shots" % SHOTS.size())
	quit()
