extends SceneTree
## Run after importing the extracted PNGs. World cells stay 16px via layer scale.
func _initialize() -> void:
	var tiles: TileSet = TileSet.new()
	tiles.tile_size = Vector2i(32,32)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0,1)
	var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas.texture = load("res://assets/tilesets/catacombs/atlas.png") as Texture2D
	atlas.texture_region_size = Vector2i(32,32)
	tiles.add_source(atlas,0)
	for i in range(64):
		var coords: Vector2i = Vector2i(i%8,i/8)
		atlas.create_tile(coords)
		if (i>=16 and i<32) or i==8 or i==10:
			var data: TileData = atlas.get_tile_data(coords,0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-16,-16),Vector2(16,-16),Vector2(16,16),Vector2(-16,16)]))
	var error: Error = ResourceSaver.save(tiles,"res://assets/tilesets/catacombs/catacombs.tres")
	print("TileSet saved; result=",error)
	quit(0 if error==OK else 1)
