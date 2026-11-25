extends RefCounted
## Art direction of every area of the Catacumbas do Eclipse, as pure data: what each
## region looks like, never where things are (positions stay in catacomb_layout.gd).
## Read by iso_world.gd (floor), iso_architecture.gd (walls) and iso_lighting.gd (mood).
##
## Floor
##   special   [floor atlas column, % of cells]: 6 cracked, 7 worn, 8 mossy, 9 engraved, 10 ash
##   decals    [decal column, % of cells]: 0 cracks, 1 moss, 2 puddle, 3 pebbles, 4 bones,
##             5 corruption, 6 ritual scratches, 7 soot, 8 dust, 9 coins
##   tint      floor tint alternative (iso_world.gd TINTS)
##   ordered   true = regular paving (two slab layouts on a checkerboard) instead of
##             random flagstones: built, cared-for spaces
## Walls (iso_architecture.gd)
##   signature back-wall decoration that defines the area (placed most often)
##   walls     other decorations allowed, in order of preference
##   wear      0..1 how much of the masonry is settled/displaced or cracked
##   moss      0..1 damp: mossy and seeping walls
##   broken    % of back walls collapsed into rubble sections
##   pier      pilaster spacing (cells) on long walls; 0 = none
##   low       style of the lowered front walls
## Light (iso_lighting.gd)
##   mood      [colour, energy] of the faint area fill, or null
##   candles   votive candle budget near sarcophagi/statues
##   mist      ground fog colour, or null
const THEMES: Dictionary = {
	# Entrance of a sacred building: preserved, solemn, cold light, lunar inscriptions.
	"Vestíbulo dos Esquecidos": {
		"special": [[7, 8], [9, 4]], "decals": [[8, 6], [0, 2]], "tint": 0, "ordered": true,
		"signature": "inscription", "walls": ["banner", "sconce", "rune"], "wear": 0.05, "moss": 0.0,
		"broken": 0, "pier": 4, "low": "plain",
		"mood": [Color("8fb4e8"), 0.22], "candles": 4, "mist": null},
	# A corridor where a fire once raged: soot, scorched and cracked masonry, ash.
	"Passagem das Cinzas": {
		"special": [[10, 38], [6, 12]], "decals": [[7, 16], [3, 8], [0, 7]], "tint": 1, "ordered": false,
		"signature": "scorched", "walls": ["cracked", "sconce", "displaced"], "wear": 0.55, "moss": 0.0,
		"broken": 14, "pier": 0, "low": "scorched",
		"mood": [Color("6a5a78"), 0.26], "candles": 0, "mist": null},
	# Ritual arena: monumental, carved Eclipse reliefs, banners, strong pilaster rhythm.
	"Câmara do Eclipse": {
		"special": [[9, 7], [7, 6], [6, 3]], "decals": [[5, 3], [6, 4], [0, 3], [8, 4]], "tint": 0, "ordered": true,
		"signature": "relief", "walls": ["banner", "rune", "sconce"], "wear": 0.1, "moss": 0.0,
		"broken": 0, "pier": 4, "low": "plain",
		"mood": [Color("5b4b9a"), 0.35], "candles": 0, "mist": null},
	# Stair down to the crypt: burial slots begin to line the walls.
	"Descida do Ossário": {
		"special": [[6, 8], [8, 5]], "decals": [[4, 6], [3, 6]], "tint": 3, "ordered": false,
		"signature": "loculi", "walls": ["niche", "sconce"], "wear": 0.3, "moss": 0.1,
		"broken": 0, "pier": 0, "low": "cracked",
		"mood": [Color("5d4a8a"), 0.2], "candles": 2, "mist": null},
	# Funerary hall: loculi and niches, sarcophagi, candles, quiet violet light.
	"Ossário Lunar": {
		"special": [[9, 6], [7, 8]], "decals": [[4, 7], [9, 2], [5, 3], [8, 4], [6, 2]], "tint": 3, "ordered": false,
		"signature": "loculi", "walls": ["niche", "sconce", "banner"], "wear": 0.2, "moss": 0.05,
		"broken": 0, "pier": 5, "low": "plain",
		"mood": [Color("6a4a8c"), 0.4], "candles": 8, "mist": Color("7d5aa6")},
	# Narrow rift where the vault gave way: fractures, rubble, damp.
	"Fenda Colapsada": {
		"special": [[6, 24], [8, 16]], "decals": [[3, 14], [1, 8], [0, 10]], "tint": 4, "ordered": false,
		"signature": "displaced", "walls": ["cracked", "seep"], "wear": 0.8, "moss": 0.5,
		"broken": 30, "pier": 0, "low": "displaced",
		"mood": [Color("3d6f86"), 0.22], "candles": 0, "mist": Color("4fb3b0")},
	# Gallery whose ceiling partly fell: broken walls, moss, displaced stones.
	"Galeria Quebrada": {
		"special": [[6, 16], [8, 16]], "decals": [[1, 10], [3, 8], [0, 7]], "tint": 4, "ordered": false,
		"signature": "displaced", "walls": ["mossy", "cracked", "sconce"], "wear": 0.7, "moss": 0.5,
		"broken": 22, "pier": 0, "low": "displaced",
		"mood": [Color("2f6f7a"), 0.24], "candles": 0, "mist": null},
	# Flooded ruins: seeping, mossy walls, pools, collapsed sections, teal light.
	"Ruínas Submersas": {
		"special": [[8, 26], [6, 12], [7, 6]], "decals": [[1, 9], [2, 9], [0, 6], [3, 5]], "tint": 4, "ordered": false,
		"signature": "seep", "walls": ["mossy", "cracked", "sconce", "rune"], "wear": 0.6, "moss": 0.8,
		"broken": 18, "pier": 0, "low": "mossy",
		"mood": [Color("2f7d85"), 0.4], "candles": 0, "mist": Color("4fb3b0")},
}
const DEFAULT: String = "Vestíbulo dos Esquecidos"

static func theme(area: String) -> Dictionary:
	return THEMES.get(area, THEMES[DEFAULT])
