-- TextureService: turns the photo-scanned textures into Roblox MaterialVariants and makes
-- them the override for their base material - every part AND the terrain using that
-- material looks real at once, on every map, without touching a single part.
--
-- Image ids: Shared/Assets.luau (Textures). Tile sizes / maps: Shared/Textures.luau.
-- The place file can already contain the variants (tools/bake_map.luau bakes them when the
-- ids are set); then this service only fills gaps.

local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Textures = require(Shared.Textures)

local TextureService = {}

local PROPERTY = { color = "ColorMap", normal = "NormalMap", roughness = "RoughnessMap", metalness = "MetalnessMap" }

function TextureService.VariantName(material: string): string
	return "SR_" .. material
end

function TextureService.Start()
	local ids = Assets.Textures or {}
	local applied, failed = 0, 0
	for material, spec in Textures do
		local set = ids[material]
		if set and type(set.color) == "string" and set.color ~= "" then
			local ok, err = pcall(function()
				local name = TextureService.VariantName(material)
				local variant = MaterialService:FindFirstChild(name)
				if not variant then
					variant = Instance.new("MaterialVariant")
					variant.Name = name
					variant.BaseMaterial = (Enum.Material :: any)[material]
					variant.StudsPerTile = spec.studsPerTile
					variant.MaterialPattern = (Enum.MaterialPattern :: any)[spec.pattern]
					for map, property in PROPERTY do
						local id = set[map]
						if type(id) == "string" and id ~= "" then
							(variant :: any)[property] = id
						end
					end
					variant.Parent = MaterialService
				end
				MaterialService:SetBaseMaterialOverride((Enum.Material :: any)[material], name)
			end)
			if ok then
				applied += 1
			else
				failed += 1
				warn("[FZ-Textures] " .. material .. ": " .. tostring(err))
			end
		end
	end
	if applied + failed > 0 then
		print(string.format("[FZ-Textures] %d materials textured, %d failed", applied, failed))
	end
end

return TextureService
