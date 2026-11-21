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

local ORDER = { "low", "medium", "high" }
local autoLevel: string? = nil

local function resolve(name: string): string
	if name ~= "auto" then
		return name
	end
	if autoLevel then
		return autoLevel
	end
	-- Conservative start: phones/tablets at medium, everything else at high. The measured
	-- frame rate then adjusts it (see startAutoTuning).
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "medium"
	end
	return "high"
end

local watched: { [Instance]: boolean } = {}

local function applyDecor(fixture: Instance)
	-- A fixture without power stays off no matter which profile is selected.
	local on = resolvedProfile.decorLights and fixture:GetAttribute("Powered") ~= false
	for _, descendant in fixture:GetDescendants() do
		if descendant:IsA("Light") then
			descendant.Enabled = on
		end
	end
	if not watched[fixture] then
		watched[fixture] = true
		fixture:GetAttributeChangedSignal("Powered"):Connect(function()
			applyDecor(fixture)
		end)
		fixture.Destroying:Connect(function()
			watched[fixture] = nil
		end)
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

-- "Automatic": measured FPS steps the profile down (< 28 fps for 10 s) or up
-- (> 55 fps for 30 s), never above "high". Roblox's own quality slider stays untouched.
local function startAutoTuning(settings)
	local RunService = game:GetService("RunService")
	local frames, elapsed, goodFor = 0, 0, 0
	RunService.Heartbeat:Connect(function(dt)
		if settings.Get("graphics") ~= "auto" then
			return
		end
		frames += 1
		elapsed += dt
		if elapsed < 10 then
			return
		end
		local fps = frames / elapsed
		frames, elapsed = 0, 0
		local level = table.find(ORDER, resolve("auto")) or 2
		if fps < 28 and level > 1 then
			autoLevel = ORDER[level - 1]
			goodFor = 0
			apply()
		elseif fps > 55 then
			goodFor += 10
			if goodFor >= 30 and level < #ORDER then
				autoLevel = ORDER[level + 1]
				goodFor = 0
				apply()
			end
		else
			goodFor = 0
		end
	end)
end

function GraphicsController.Init(settings)
	startAutoTuning(settings)
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
