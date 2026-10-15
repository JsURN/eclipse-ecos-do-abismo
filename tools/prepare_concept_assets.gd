extends SceneTree
## Mechanical extraction of the supplied sheets, not image generation.
## Every rectangle/pivot was selected individually; rows are NOT a sprite grid.
const KAEL: String = "res://assets/source_art/kael_concept.png"
const ENEMIES: String = "res://assets/source_art/enemies_concept.png"
const SCENERY: String = "res://assets/source_art/catacombs_concept.png"
var sources: Dictionary = {}
var manifest: Dictionary = {"actors": {}, "props": {}, "effects": {}, "sources": {}, "crops": []}
var contact: Image
var contact_index: int = 0
var saved_paths: Array[String] = []

func _initialize() -> void:
	for path in [KAEL, ENEMIES, SCENERY]:
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null:
			push_error("Missing source: " + path)
			quit(1)
			return
		sources[path] = image
		manifest["sources"][path] = {"width": image.get_width(), "height": image.get_height(), "alpha": image.detect_alpha()}
	contact = Image.create(1280, 1280, false, Image.FORMAT_RGBA8)
	contact.fill(Color("202a38"))
	_kael()
	_enemies()
	_props()
	_tiles()
	_effects()
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	contact.save_png("res://artifacts/extraction_contact.png")
	var file: FileAccess = FileAccess.open("res://assets/concept_manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	saved_paths.append("res://assets/concept_manifest.json")
	saved_paths.append("res://assets/tilesets/catacombs/catacombs.tres")
	saved_paths.append_array([KAEL,ENEMIES,SCENERY])
	saved_paths.sort()
	var inventory: FileAccess = FileAccess.open("res://assets/INTEGRATED_FILES.txt",FileAccess.WRITE)
	inventory.store_string("\n".join(saved_paths)+"\n")
	print("PREPARED: ", manifest["crops"].size(), " individually mapped crops; original alpha preserved")
	quit()

func _kael() -> void:
	_actor("kael", "characters/kael", KAEL, 0.6, {
		"idle": [[396,65,110,139,452,190]],
		"idle_up": [[884,71,101,136,937,192]],
		"walk": [[375,245,112,141,432,365],[482,245,114,141,540,365]],
		"walk_up": [[809,245,104,143,866,373],[914,245,112,143,969,373]],
		"attack": [[354,430,157,145,425,550],[902,416,184,182,968,550],[1274,430,164,146,1350,550]],
		"dash": [[40,626,145,128,113,738],[226,623,166,138,318,738],[817,631,200,133,951,738]],
		"hurt": [[40,800,130,130,100,913],[190,804,150,125,263,913]],
		"death": [[35,968,127,112,99,1064],[178,968,125,112,235,1064],[300,970,142,107,370,1064],[444,984,185,96,525,1064],[615,995,183,83,702,1064],[799,997,173,81,878,1064]]
	})
	var portrait: Image = _region(KAEL, [33,28,213,207])
	portrait.resize(56,56,Image.INTERPOLATE_NEAREST)
	_save(portrait, "res://assets/characters/kael/portrait.png")

func _enemies() -> void:
	_actor("crawler", "enemies/shadow_crawler", ENEMIES, 0.8, {
		"idle": [[389,36,109,50,457,77]],
		"walk": [[531,98,139,65,615,151],[666,99,121,66,743,151]],
		"attack": [[560,164,132,76,626,235],[697,164,141,86,771,235],[1092,164,171,84,1184,235]],
		"hurt": [[402,264,89,60,447,317],[499,260,112,67,558,317]],
		"death": [[966,269,110,64,1024,320],[1079,271,118,62,1156,320],[1201,257,115,78,1270,320]]
	})
	_actor("archer", "enemies/spectral_archer", ENEMIES, 0.8, {
		"idle": [[542,346,93,85,590,420]],
		"walk": [[547,434,83,77,591,509],[637,433,92,78,682,509]],
		"attack": [[785,517,124,100,841,603],[923,525,122,86,980,603]],
		"hurt": [[590,624,91,82,634,696]],
		"death": [[930,651,148,74,992,707],[1080,656,151,62,1153,707]]
	})
	_actor("guardian", "enemies/stone_guardian", ENEMIES, 0.8, {
		"idle": [[542,719,111,84,601,793]],
		"walk": [[554,806,117,77,619,879],[672,807,119,79,739,879]],
		"attack": [[602,885,135,92,682,969],[894,894,157,91,974,969]],
		"hurt": [[629,986,125,89,688,1072]],
		"death": [[946,994,115,82,1005,1072],[1066,1005,127,71,1121,1072],[1202,1011,181,67,1284,1072]]
	})

func _actor(key: String, directory: String, source: String, factor: float, states: Dictionary) -> void:
	var output: Dictionary = {"animations": {}, "frame_size": 160, "pivot": [80,140], "world_scale": 0.5, "fps": {}}
	for state in states:
		var paths: Array[String] = []
		var rects: Array = states[state]
		for i in range(rects.size()):
			var spec: Array = rects[i]
			var cropped: Image = _region(source, spec)
			# Only the label tail, outside the corpse, in this otherwise usable crop.
			if key == "guardian" and state == "death" and i == 0:
				cropped.fill_rect(Rect2i(0,0,23,18),Color.TRANSPARENT)
			var canvas: Image = Image.create(160,160,false,Image.FORMAT_RGBA8)
			canvas.fill(Color.TRANSPARENT)
			cropped.resize(roundi(cropped.get_width()*factor),roundi(cropped.get_height()*factor),Image.INTERPOLATE_NEAREST)
			var pivot: Vector2i = Vector2i(roundi((float(spec[4])-float(spec[0]))*factor),roundi((float(spec[5])-float(spec[1]))*factor))
			canvas.blit_rect(cropped,Rect2i(Vector2i.ZERO,cropped.get_size()),Vector2i(80,140)-pivot)
			var path: String = "res://assets/%s/%s_%02d.png" % [directory,state,i]
			_save(canvas,path)
			paths.append(path)
			manifest["crops"].append({"file":path,"source":source,"rect":spec.slice(0,4),"foot":spec.slice(4,6),"resample":factor})
			_preview(canvas)
		output["animations"][state] = paths
		var fps: float = 5.0
		if String(state).begins_with("walk"): fps = 8.0
		if state == "attack": fps = float(paths.size()) / 0.18
		if state == "dash": fps = float(paths.size()) / 0.16
		if state == "hurt": fps = 12.0
		if state == "death": fps = float(paths.size()) / 0.4
		output["fps"][state] = fps
	manifest["actors"][key] = output

func _region(source: String, spec: Array) -> Image:
	var image: Image = sources[source]
	return image.get_region(Rect2i(int(spec[0]),int(spec[1]),int(spec[2]),int(spec[3])))

func _save(image: Image, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	saved_paths.append(path)

func _preview(image: Image) -> void:
	var preview: Image = image.duplicate()
	preview.resize(128,128,Image.INTERPOLATE_NEAREST)
	var at: Vector2i = Vector2i(contact_index % 10 * 128, contact_index / 10 * 128)
	contact.blend_rect(preview,Rect2i(Vector2i.ZERO,preview.get_size()),at)
	contact_index += 1

func _fit(source: Image, size: Vector2i, factor: float, pivot: Vector2i) -> Image:
	var image: Image = source.duplicate()
	image.resize(roundi(image.get_width()*factor),roundi(image.get_height()*factor),Image.INTERPOLATE_NEAREST)
	var canvas: Image = Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	canvas.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),pivot-Vector2i(image.get_width()/2,image.get_height()))
	return canvas

func _props() -> void:
	var specs: Dictionary = {
		"statue": [1266,425,123,177,0.48], "pillar": [812,428,79,169,0.5],
		"sarcophagus": [18,611,216,128,0.29], "crystal": [1397,607,78,139,0.6],
		"roots": [1097,774,67,65,0.8], "altar": [708,607,202,167,0.3],
		"sarcophagus_open": [241,611,192,129,0.32], "statue_sword": [1509,425,146,179,0.43],
		"torch": [23,749,57,137,0.4], "torch_alt": [95,759,49,111,0.4],
		"banner": [165,750,77,135,0.4], "bones": [610,861,80,63,0.6],
		"rubble": [624,773,103,86,0.6], "corruption": [1343,779,103,64,0.6]
	}
	var atlas: Image = Image.create(64*specs.size(),112,false,Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var index: int = 0
	for key in specs:
		var spec: Array = specs[key]
		var image: Image = _fit(_region(SCENERY,spec),Vector2i(64,112),float(spec[4]),Vector2i(32,104))
		var path: String = "res://assets/environments/props/%s.png" % key
		_save(image,path)
		atlas.blit_rect(image,Rect2i(0,0,64,112),Vector2i(index*64,0))
		manifest["props"][key] = {"path":path,"index":index,"rect":spec.slice(0,4)}
		_preview(image)
		index += 1
	_save(atlas,"res://assets/environments/props/details_atlas.png")
	# Door frames share a center, not a foot pivot; they rotate for east/west passages.
	var doors: Image = Image.create(512,128,false,Image.FORMAT_RGBA8)
	doors.fill(Color.TRANSPARENT)
	var door_rects: Array = [[22,429,182,158],[212,429,180,158],[405,429,146,158],[556,429,232,158]]
	for i in range(4):
		var cropped: Image = _region(SCENERY,door_rects[i])
		cropped.resize(roundi(cropped.get_width()*0.5),roundi(cropped.get_height()*0.5),Image.INTERPOLATE_NEAREST)
		doors.blit_rect(cropped,Rect2i(Vector2i.ZERO,cropped.get_size()),Vector2i(i*128+64-cropped.get_width()/2,64-cropped.get_height()/2))
	_save(doors,"res://assets/environments/props/doors.png")
	var rewards: Image = Image.create(256,96,false,Image.FORMAT_RGBA8)
	rewards.fill(Color.TRANSPARENT)
	var reward_rects: Array = [[1204,633,81,91,0.7],[1296,628,90,99,0.65],[22,429,182,158,0.32],[556,429,232,158,0.26]]
	for i in range(4):
		var spec: Array = reward_rects[i]
		var image: Image = _fit(_region(SCENERY,spec),Vector2i(64,96),float(spec[4]),Vector2i(32,88))
		rewards.blit_rect(image,Rect2i(0,0,64,96),Vector2i(i*64,0))
	_save(rewards,"res://assets/environments/props/rewards_atlas.png")

func _tiles() -> void:
	var atlas: Image = Image.create(256,256,false,Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var floors: Array = [[26,37,78,78],[121,37,77,78],[225,131,77,77],[320,130,77,77],[605,37,70,76],[699,37,72,76],[26,229,78,78],[121,131,77,77],[407,37,77,78],[501,37,77,78],[320,37,77,78],[225,37,77,78]]
	for index in range(64):
		var image: Image
		if index < 8 or (index >= 32 and index < 40):
			image = _region(SCENERY,floors[index % floors.size()])
			var side: int = mini(image.get_width(),image.get_height())
			image = image.get_region(Rect2i((image.get_width()-side)/2,(image.get_height()-side)/2,side,side))
			image.resize(32,32,Image.INTERPOLATE_NEAREST)
		elif index >= 16 and index < 32:
			image = _wall(index-16)
		elif index >= 52 and index < 56:
			var seal: Image = _region(SCENERY,[409,226,175,177])
			seal = seal.get_region(Rect2i(0,1,175,175))
			seal.resize(64,64,Image.INTERPOLATE_NEAREST)
			image = seal.get_region(Rect2i((index-52)%2*32,(index-52)/2*32,32,32))
		else:
			var props: Dictionary = {8:"pillar",9:"rubble",10:"sarcophagus",11:"bones",12:"torch",13:"rubble",14:"altar",15:"statue",40:"roots",41:"crystal",42:"torch_alt",43:"banner",44:"rubble",45:"corruption",46:"sarcophagus_open",47:"bones",48:"torch",49:"torch_alt",50:"torch"}
			image = Image.create(32,32,false,Image.FORMAT_RGBA8)
			image.fill(Color.TRANSPARENT)
			# Solid bases remain transparent: the detailed fixture above has the same footprint.
			if props.has(index) and index != 8 and index != 10:
				var data: Dictionary = manifest["props"][props[index]]
				var source: Image = _region(SCENERY,data["rect"])
				var fit: float = minf(28.0/source.get_width(),28.0/source.get_height())
				image = _fit(source,Vector2i(32,32),fit,Vector2i(16,31))
		atlas.blit_rect(image,Rect2i(0,0,32,32),Vector2i(index%8*32,index/8*32))
	_save(atlas,"res://assets/tilesets/catacombs/atlas.png")

func _wall(mask: int) -> Image:
	var image: Image = _region(SCENERY,[938,35,32,32])
	var edge: Image = _region(SCENERY,[932,76,32,32])
	if mask == 0: return _region(SCENERY,[1294,112,32,32])
	for bit in [1,2,4,8]:
		if not mask & bit: continue
		var face: Image = edge.duplicate()
		if bit == 1: face.flip_y()
		if bit == 2: face.rotate_90(COUNTERCLOCKWISE)
		if bit == 8: face.rotate_90(CLOCKWISE)
		var rect: Rect2i = Rect2i(0,0,32,32)
		if bit == 1: rect = Rect2i(0,0,32,18)
		if bit == 4: rect = Rect2i(0,14,32,18)
		if bit == 2: rect = Rect2i(14,0,18,32)
		if bit == 8: rect = Rect2i(0,0,18,32)
		image.blit_rect(face,rect,rect.position)
	return image

func _effects() -> void:
	var specs: Dictionary = {"sword_arc":[KAEL,1092,848,161,151],"impact":[KAEL,1358,843,53,73],"spectral_projectile":[ENEMIES,1239,534,183,68],"corruption":[SCENERY,1343,779,103,64]}
	for key in specs:
		var spec: Array = specs[key]
		var image: Image = _region(String(spec[0]),spec.slice(1,5))
		var factor: float = minf(80.0/image.get_width(),48.0/image.get_height())
		image = _fit(image,Vector2i(96,64),factor,Vector2i(48,56))
		var path: String = "res://assets/effects/%s.png" % key
		_save(image,path)
		manifest["effects"][key] = path
