-- GraphicsController: quality profiles for the parts an experience may control itself.
-- Roblox's own graphics quality slider is respected and never overridden.
--
-- Invariants on EVERY profile (fairness + atmosphere):
--   * Atmosphere/fog is identical, so creatures are never easier/harder to see.
--   * Lights tagged "FZ_KeyLight" (gameplay-relevant lighting) are always on.
--   * Only decoration scales: post effects, lights tagged "FZ_DecorLight",
--     and the particle multiplier other systems read via GetParticleScale().

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local GraphicsController = {}

local PROFILES = {
	low = { bloom = false, decorLights = false, particles = 0.35, grade = 0.8 },
	medium = { bloom = true, decorLights = false, particles = 0.65, grade = 1 },
	high = { bloom = true, decorLights = true, particles = 1, grade = 1 },
	ultra = { bloom = true, decorLights = true, particles = 1.4, grade = 1 },
}

local current = "high"
local resolvedProfile = PROFILES.high
local brightness = 5
local grade: ColorCorrectionEffect? = nil
local bloom: BloomEffect? = nil
local decorConnection: RBXScriptConnection? = nil

local function ensureEffects()
	-- Created on the client: these effects exist only for this player.
	if not grade then
		local effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "FZ_Grade"
		effect.Parent = Lighting
		grade = effect
	end
	if not bloom then
		local effect = Instance.new("BloomEffect")
		effect.Name = "FZ_Bloom"
		effect.Intensity = 0.35
		effect.Size = 22
		effect.Threshold = 1.6
		effect.Parent = Lighting
		bloom = effect
	end
end

local function resolve(name: string): string
	if name ~= "auto" then
		return name
	end
	-- Conservative default: phones/tablets start at medium, everything else at high.
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "medium"
	end
	return "high"
end

local function applyDecor(light: Instance)
	for _, descendant in light:GetDescendants() do
		if descendant:IsA("Light") then
			descendant.Enabled = resolvedProfile.decorLights
		end
	end
	if light:IsA("Light") then
		light.Enabled = resolvedProfile.decorLights
	end
end

local function apply()
	ensureEffects()
	resolvedProfile = PROFILES[resolve(current)] or PROFILES.high
	local g = grade :: ColorCorrectionEffect
	-- Base grade: slightly desaturated, cool shadows. Brightness setting 0..10 (5 = neutral).
	g.Saturation = -0.18 * resolvedProfile.grade
	g.Contrast = 0.08 * resolvedProfile.grade
	g.TintColor = Color3.fromRGB(236, 242, 244)
	g.Brightness = (brightness - 5) * 0.025
	;(bloom :: BloomEffect).Enabled = resolvedProfile.bloom
	for _, light in CollectionService:GetTagged("FZ_DecorLight") do
		applyDecor(light)
	end
	if not decorConnection then
		decorConnection = CollectionService:GetInstanceAddedSignal("FZ_DecorLight"):Connect(applyDecor)
	end
end

function GraphicsController.Init(settings)
	current = settings.Get("graphics") or "auto"
	brightness = settings.Get("brightness") or 5
	apply()
	settings.Changed:Connect(function(key, value)
		if key == "graphics" then
			current = value
			apply()
		elseif key == "brightness" then
			brightness = value
			apply()
		end
	end)
end

function GraphicsController.GetParticleScale(): number
	return resolvedProfile.particles
end

function GraphicsController.GetProfileName(): string
	return resolve(current)
end

function GraphicsController.GetRobloxQualityLevel(): number
	local ok, level = pcall(function()
		return UserSettings().GameSettings.SavedQualityLevel.Value
	end)
	return if ok then level else -1
end

return GraphicsController
