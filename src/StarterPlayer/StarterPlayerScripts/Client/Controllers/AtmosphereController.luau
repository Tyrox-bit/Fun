-- AtmosphereController: weather and time-layer effects driven by SessionState.
--   Weather = "storm": rain around the camera (off under a roof), lightning flashes
--   TimeLayer = "2009": warm, faded colour grade; every layer change flashes once
-- Uses only built-in textures (no uploaded assets). Respects "reduce flicker" and the
-- particle budget of the graphics profile.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SessionState = require(Shared.SessionState)

local GraphicsController = require(script.Parent.GraphicsController)

local AtmosphereController = {}

local settings = nil
local rainPart: Part? = nil
local rain: ParticleEmitter? = nil
local flash: ColorCorrectionEffect? = nil
local layerGrade: ColorCorrectionEffect? = nil
local nextLightning = 0

local function ensureEffects()
	if not flash then
		local effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "FZ_Flash"
		effect.Parent = Lighting
		flash = effect
	end
	if not layerGrade then
		local effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "FZ_TimeLayer"
		effect.Parent = Lighting
		layerGrade = effect
	end
	if not rainPart then
		local part = Instance.new("Part")
		part.Name = "FZ_Rain"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.new(80, 1, 80)
		part.Parent = workspace.CurrentCamera
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.Speed = NumberRange.new(90, 110)
		emitter.Lifetime = NumberRange.new(0.55, 0.7)
		emitter.Size = NumberSequence.new(0.12)
		emitter.Squash = NumberSequence.new(-3.5) -- long thin streaks
		emitter.Transparency = NumberSequence.new(0.45)
		emitter.Color = ColorSequence.new(Color3.fromRGB(190, 205, 220))
		emitter.LightInfluence = 0.6
		emitter.LightEmission = 0.1
		emitter.Rate = 0
		emitter.Acceleration = Vector3.new(4, 0, 0) -- wind
		emitter.Parent = part
		rainPart = part
		rain = emitter
	end
end

local function flashOnce(strength: number, duration: number)
	local effect = flash :: ColorCorrectionEffect
	if settings and settings.Get("reduceFlicker") then
		strength *= 0.25
	end
	effect.Brightness = strength
	effect.Contrast = strength * 0.4
	TweenService:Create(effect, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0, Contrast = 0 }):Play()
end

-- Under a roof? (one ray straight up from the camera)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function covered(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	rayParams.FilterDescendantsInstances = { camera :: Instance, game:GetService("Players").LocalPlayer.Character :: Instance }
	return workspace:Raycast(position, Vector3.new(0, 60, 0), rayParams) ~= nil
end

local function applyLayer()
	local effect = layerGrade :: ColorCorrectionEffect
	local layer = SessionState.Get("TimeLayer")
	local goal = if layer == "2009"
		then { TintColor = Color3.fromRGB(255, 226, 192), Saturation = -0.35, Contrast = 0.12, Brightness = 0.03 }
		else { TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0, Brightness = 0 }
	TweenService:Create(effect, TweenInfo.new(1.2, Enum.EasingStyle.Sine), goal):Play()
	if layer ~= nil then
		flashOnce(0.45, 1.1)
	end
end

-- Map dressing (MapDress): light cones follow their lamp (power cuts switch them off) and
-- the graphics profile; mist/steam rates follow the particle budget; some tubes flicker.
local function updateDressing()
	local profile = GraphicsController.GetProfileName()
	local particleScale = GraphicsController.GetParticleScale()
	for _, beam in CollectionService:GetTagged("FZ_LightCone") do
		if beam:IsA("Beam") then
			local lamp = beam.Parent
			local light = lamp and lamp:FindFirstChildWhichIsA("Light")
			local powered = lamp ~= nil and lamp:GetAttribute("Powered") ~= false and (light == nil or light.Enabled)
			beam.Enabled = profile ~= "low" and powered
		end
	end
	for _, emitter in CollectionService:GetTagged("FZ_Mist") do
		if emitter:IsA("ParticleEmitter") then
			local base = emitter:GetAttribute("BaseRate")
			if type(base) == "number" then
				emitter.Rate = if profile == "low" then 0 else base * particleScale
			end
		end
	end
end

local flickering: { [Instance]: boolean } = {}
local function flickerOnce(fixture: BasePart)
	if flickering[fixture] or fixture:GetAttribute("Powered") == false then
		return
	end
	local light = fixture:FindFirstChildWhichIsA("Light")
	if not light or not light.Enabled then
		return
	end
	flickering[fixture] = true
	local color = fixture.Color
	task.spawn(function()
		for _ = 1, math.random(2, 5) do
			light.Enabled = false
			fixture.Color = color:Lerp(Color3.new(0, 0, 0), 0.7)
			task.wait(math.random(3, 9) / 100)
			local powered = fixture:GetAttribute("Powered") ~= false
			light.Enabled = powered
			if powered then
				fixture.Color = color
			end
			task.wait(math.random(5, 25) / 100)
		end
		flickering[fixture] = nil
	end)
end

function AtmosphereController.Init(settingsController)
	settings = settingsController
	ensureEffects()
	task.spawn(function()
		while true do
			pcall(updateDressing)
			task.wait(0.5)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(math.random(30, 80) / 10)
			if not (settings and settings.Get("reduceFlicker")) then
				local list = CollectionService:GetTagged("FZ_Flicker")
				local camera = workspace.CurrentCamera
				if #list > 0 and camera then
					-- only tubes near the player flicker (nobody sees the others anyway)
					local fixture = list[math.random(1, #list)]
					if fixture:IsA("BasePart") and (fixture.Position - camera.CFrame.Position).Magnitude < 90 then
						flickerOnce(fixture)
					end
				end
			end
		end
	end)
	SessionState.Observe("TimeLayer", applyLayer)
	applyLayer()

	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local part = rainPart
		if not camera or not part or not rain then
			return
		end
		if part.Parent ~= camera then
			part.Parent = camera
		end
		local storm = SessionState.Get("Weather") == "storm"
		local position = camera.CFrame.Position
		part.CFrame = CFrame.new(position + Vector3.new(0, 28, 0))
		accumulator += dt
		if accumulator >= 0.25 then
			accumulator = 0
			local indoors = storm and covered(position)
			rain.Rate = if storm and not indoors then 700 * GraphicsController.GetParticleScale() else 0
		end
		if storm and os.clock() >= nextLightning then
			nextLightning = os.clock() + math.random(9, 22)
			if not covered(position) then
				flashOnce(0.55, 0.35)
				task.delay(0.12, function()
					flashOnce(0.35, 0.5)
				end)
			end
		end
	end)
end

return AtmosphereController
