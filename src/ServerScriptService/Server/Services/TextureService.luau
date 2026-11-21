-- TextureService: turns the photo-scanned textures into Roblox MaterialVariants.
--   * override variants replace their base material everywhere (all parts + terrain)
--   * surface variants exist for the parts MapDress.Surfaces assigned them to
--   * grime decals (tag FZ_Grime, attribute Kind) get their image
-- Image ids: Shared/Assets.luau (Textures, Grime). Variants: Shared/Textures.luau.
-- The place file can already contain all of this (tools/bake_map.luau bakes it when the
-- ids are set); this service fills gaps, e.g. after ids were pasted in Studio.

local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Textures = require(Shared.Textures)

local TextureService = {}

local PROPERTY = { color = "ColorMap", normal = "NormalMap", roughness = "RoughnessMap", metalness = "MetalnessMap" }

function TextureService.VariantName(name: string): string
	return "SR_" .. name
end

local function applyGrime(decal: Instance)
	if not decal:IsA("Decal") then
		return
	end
	local kind = decal:GetAttribute("Kind")
	local id = type(kind) == "string" and (Assets.Grime or {})[kind]
	if type(id) == "string" and id ~= "" and decal.Texture == "" then
		decal.Texture = id
	end
end

function TextureService.Start()
	local ids = Assets.Textures or {}
	local applied, failed = 0, 0
	for name, spec in Textures.Variants do
		local set = ids[name]
		if set and type(set.color) == "string" and set.color ~= "" then
			local ok, err = pcall(function()
				local variantName = TextureService.VariantName(name)
				local variant = MaterialService:FindFirstChild(variantName)
				if not variant then
					variant = Instance.new("MaterialVariant")
					variant.Name = variantName
					variant.BaseMaterial = (Enum.Material :: any)[spec.base]
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
				if spec.override then
					MaterialService:SetBaseMaterialOverride((Enum.Material :: any)[spec.base], variantName)
				end
			end)
			if ok then
				applied += 1
			else
				failed += 1
				warn("[FZ-Textures] " .. name .. ": " .. tostring(err))
			end
		end
	end
	for _, decal in CollectionService:GetTagged("FZ_Grime") do
		applyGrime(decal)
	end
	CollectionService:GetInstanceAddedSignal("FZ_Grime"):Connect(applyGrime)
	if applied + failed > 0 then
		print(string.format("[FZ-Textures] %d texture variants, %d failed", applied, failed))
	end
end

return TextureService
