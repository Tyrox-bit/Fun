-- Texture registry (from assets/textures/manifest.json, see tools/prepare_textures.py).
-- Every entry becomes a MaterialVariant "SR_<name>". override = true: it replaces its base
-- material everywhere (parts + terrain). The others are put on specific parts by
-- MapDress.Surfaces. Image ids: Shared/Assets.luau. Sources: assets/textures/CREDITS.md (CC0).

local Textures = {}

Textures.Variants = {
	Concrete = { base = "Concrete", override = true, studsPerTile = 10.7, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "concrete_wall_003" },
	Plaster = { base = "Plaster", override = true, studsPerTile = 3.6, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "grey_plaster_02" },
	CeramicTiles = { base = "CeramicTiles", override = true, studsPerTile = 8.1, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "dirty_tiles" },
	Metal = { base = "Metal", override = true, studsPerTile = 8.9, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "blue_metal_plate" },
	DiamondPlate = { base = "DiamondPlate", override = true, studsPerTile = 3, pattern = "Regular", maps = { "color", "normal", "roughness", "metalness" }, source = "metal_plate" },
	CorrodedMetal = { base = "CorrodedMetal", override = true, studsPerTile = 3.6, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "rusty_metal_02" },
	Wood = { base = "Wood", override = true, studsPerTile = 3, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "wood_table_worn" },
	WoodPlanks = { base = "WoodPlanks", override = true, studsPerTile = 6.4, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "weathered_brown_planks" },
	Asphalt = { base = "Asphalt", override = true, studsPerTile = 7.1, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "worn_asphalt" },
	Cobblestone = { base = "Cobblestone", override = true, studsPerTile = 5.4, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "rustic_stone_wall_02" },
	Slate = { base = "Slate", override = true, studsPerTile = 8.2, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "slate_floor" },
	Rock = { base = "Rock", override = true, studsPerTile = 9.6, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "rock_face_03" },
	Brick = { base = "Brick", override = true, studsPerTile = 3.6, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "red_brick_03" },
	Fabric = { base = "Fabric", override = true, studsPerTile = 3, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "rough_linen" },
	Carpet = { base = "Carpet", override = true, studsPerTile = 3, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "dirty_carpet" },
	RoofShingles = { base = "RoofShingles", override = true, studsPerTile = 10.7, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "roof_slates_02" },
	Pebble = { base = "Pebble", override = true, studsPerTile = 8.0, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "gravel_floor" },
	Pavement = { base = "Pavement", override = true, studsPerTile = 6.4, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "concrete_pavement" },
	Ground = { base = "Ground", override = true, studsPerTile = 11.3, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "forest_ground_04" },
	Granite = { base = "Granite", override = true, studsPerTile = 7.1, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "lichen_rock" },
	Marble = { base = "Marble", override = true, studsPerTile = 5.4, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "marble_01" },
	Mud = { base = "Mud", override = true, studsPerTile = 4.6, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "brown_mud_02" },
	ConcreteFloor = { base = "Concrete", override = false, studsPerTile = 10.7, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "concrete_floor_worn_001" },
	DamConcrete = { base = "Concrete", override = false, studsPerTile = 9.7, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "concrete_wall_008" },
	CrackedWall = { base = "Concrete", override = false, studsPerTile = 8.0, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "cracked_concrete_wall" },
	Ceiling = { base = "Concrete", override = false, studsPerTile = 7.1, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "ceiling_interior" },
	RoofConcrete = { base = "Concrete", override = false, studsPerTile = 7.1, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "concrete_layers_02" },
	DoorMetal = { base = "Metal", override = false, studsPerTile = 7.9, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "rusty_painted_metal" },
	Machine = { base = "Metal", override = false, studsPerTile = 5.0, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "green_metal_rust" },
	Container = { base = "CorrodedMetal", override = false, studsPerTile = 6.9, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "container_side" },
	Corrugated = { base = "CorrodedMetal", override = false, studsPerTile = 7.1, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "rusty_corrugated_iron" },
	Bark = { base = "Wood", override = false, studsPerTile = 3.0, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "pine_bark" },
	Timber = { base = "Wood", override = false, studsPerTile = 4.0, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "rough_wood" },
	DarkWood = { base = "Wood", override = false, studsPerTile = 7.1, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "dark_wood" },
	OldFloor = { base = "WoodPlanks", override = false, studsPerTile = 10.7, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "old_wood_floor" },
	ChapelFloor = { base = "Slate", override = false, studsPerTile = 6.4, pattern = "Regular", maps = { "color", "normal", "roughness" }, source = "monastery_stone_floor" },
	Rubble = { base = "Slate", override = false, studsPerTile = 7.1, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "rubble" },
	MineFloor = { base = "Ground", override = false, studsPerTile = 7.1, pattern = "Organic", maps = { "color", "normal", "roughness" }, source = "rocky_trail" },
}

-- Grime decals (tools/generate_grime.py), placed on walls by MapDress.Grime.
Textures.Grime = { "water_stain", "rust_streak", "mould", "soot", "cracks", "tally" }

return Textures
