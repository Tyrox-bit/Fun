-- Texture registry (generated from assets/textures/manifest.json by hand-off from
-- tools/prepare_textures.py). Which Roblox base materials get a photo-scanned PBR
-- MaterialVariant, how large one tile is, and which maps exist. The uploaded image ids
-- live in Shared/Assets.luau (Textures). Sources: assets/textures/CREDITS.md (all CC0).

return {
	Concrete = { studsPerTile = 10.7, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "concrete_wall_003" },
	Plaster = { studsPerTile = 3.6, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "grey_plaster_02" },
	CeramicTiles = { studsPerTile = 8.1, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "dirty_tiles" },
	Metal = { studsPerTile = 8.9, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "blue_metal_plate" },
	DiamondPlate = { studsPerTile = 3, pattern = "Regular", maps = { "color", "normal", "roughness", "metalness" }, source = "metal_plate" },
	CorrodedMetal = { studsPerTile = 3.6, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "rusty_metal_02" },
	Wood = { studsPerTile = 3, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "wood_table_worn" },
	WoodPlanks = { studsPerTile = 6.4, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "weathered_brown_planks" },
	Asphalt = { studsPerTile = 7.1, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "worn_asphalt" },
	Cobblestone = { studsPerTile = 5.4, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "rustic_stone_wall_02" },
	Slate = { studsPerTile = 8.2, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "slate_floor" },
	Rock = { studsPerTile = 9.6, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "rock_face_03" },
	Brick = { studsPerTile = 3.6, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "red_brick_03" },
	Fabric = { studsPerTile = 3, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "rough_linen" },
	Carpet = { studsPerTile = 3, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "dirty_carpet" },
	RoofShingles = { studsPerTile = 10.7, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "roof_slates_02" },
	Pebble = { studsPerTile = 8.0, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "gravel_floor" },
	Pavement = { studsPerTile = 6.4, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "concrete_pavement" },
	Ground = { studsPerTile = 11.3, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "forest_ground_04" },
}
