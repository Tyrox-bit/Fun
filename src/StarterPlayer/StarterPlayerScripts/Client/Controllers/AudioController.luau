-- AudioController: every non-voice sound on the client.
--   * Sound groups (Ambience / SFX / Creature / UI) for clean mixing and ducking
--   * Ambience: wind outside, electric hum inside the building, generators (3D)
--   * Footsteps for every nearby character, by floor material (local, no network)
--   * Server-triggered 3D effects via the "Sfx" remote
-- Sounds play only when their id is set in Shared/Assets.luau; otherwise silently skipped.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Net = require(Shared.Net)

local AudioController = {}

local groups: { [string]: SoundGroup } = {}
local settings = nil
local scareFactor = 0.85
local duckFactor = 1
local inMenu = true
local tension: { [string]: Sound? } = {}
local tensionLevel = { music_menu = 0, tension_low = 0, tension_high = 0 }
local currentReverb: Enum.ReverbType? = nil

local BUILDING_MIN = Vector3.new(-100, -5, -85)
local BUILDING_MAX = Vector3.new(100, 20, 85)

local function insideBuilding(position: Vector3): boolean
	return position.X > BUILDING_MIN.X and position.X < BUILDING_MAX.X and position.Z > BUILDING_MIN.Z and position.Z < BUILDING_MAX.Z and position.Y < BUILDING_MAX.Y
end

local function group(name: string, volume: number): SoundGroup
	local g = Instance.new("SoundGroup")
	g.Name = "FZ_" .. name
	g.Volume = volume
	g.Parent = SoundService
	groups[name] = g
	return g
end

function AudioController.Id(name: string): string?
	local id = Assets.Sounds[name]
	if type(id) == "string" and id ~= "" then
		return id
	end
	return nil
end

-- Variants: "creature_growl" -> creature_growl_1 / _2 / _3 (only uploaded ones), never the
-- same one twice in a row, so repeated events do not sound repeated.
local lastVariant: { [string]: string } = {}
function AudioController.Variant(base: string): string
	local options = {}
	for i = 1, 9 do
		local name = base .. "_" .. i
		if AudioController.Id(name) and name ~= lastVariant[base] then
			table.insert(options, name)
		end
	end
	if #options == 0 then
		return lastVariant[base] or base
	end
	local choice = options[math.random(1, #options)]
	lastVariant[base] = choice
	return choice
end

-- Muffles a 3D sound when a wall is between the listener and the source.
local occlusionParams = RaycastParams.new()
occlusionParams.FilterType = Enum.RaycastFilterType.Exclude
local function occlude(sound: Sound, position: Vector3)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local filter: { Instance } = { camera }
	if Players.LocalPlayer.Character then
		table.insert(filter, Players.LocalPlayer.Character :: Instance)
	end
	occlusionParams.FilterDescendantsInstances = filter
	local origin = camera.CFrame.Position
	local hit = workspace:Raycast(origin, position - origin, occlusionParams)
	if hit and (hit.Position - position).Magnitude > 2 then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = 2
		eq.MidGain = -10
		eq.HighGain = -26
		eq.Parent = sound
		sound.Volume *= 0.75
	end
end

-- Plays a one-shot. `at` may be a Vector3, a BasePart/Attachment, or nil (2D).
-- muffle = true: sounds behind walls are low-passed (spatial credibility).
function AudioController.Play(name: string, at: any?, volume: number?, groupName: string?, muffle: boolean?): Sound?
	local id = AudioController.Id(name)
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.8
	sound.SoundGroup = groups[groupName or "SFX"]
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 120
	if typeof(at) == "Vector3" then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = at
		attachment.Parent = workspace.Terrain
		sound.Parent = attachment
		sound.Ended:Once(function()
			attachment:Destroy()
		end)
	elseif typeof(at) == "Instance" and (at:IsA("BasePart") or at:IsA("Attachment")) then
		sound.Parent = at
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	else
		sound.Parent = SoundService
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end
	if muffle then
		local position = if typeof(at) == "Vector3" then at elseif typeof(at) == "Instance" and at:IsA("BasePart") then at.Position elseif typeof(at) == "Instance" and at:IsA("Attachment") then at.WorldPosition else nil
		if position then
			occlude(sound, position)
		end
	end
	sound:Play()
	return sound
end

function AudioController.PlayVariant(base: string, at: any?, volume: number?, groupName: string?, muffle: boolean?): Sound?
	return AudioController.Play(AudioController.Variant(base), at, volume, groupName, muffle)
end

function AudioController.Loop(name: string, parent: Instance, volume: number, groupName: string?): Sound?
	local id = AudioController.Id(name)
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Loop_" .. name
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = volume
	sound.SoundGroup = groups[groupName or "Ambience"]
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 6
	sound.RollOffMaxDistance = 70
	sound.Parent = parent
	sound:Play()
	return sound
end

local function setting(key: string): number
	local value = settings and settings.Get(key)
	return (if type(value) == "number" then value else 10) / 10
end

-- Applies the volume sliders (Settings -> Audio) to the sound groups.
function AudioController.ApplyVolumes()
	if not groups.SFX then
		return
	end
	local master = setting("volumeMaster")
	groups.SFX.Volume = master * setting("volumeEffects")
	groups.Creature.Volume = master * setting("volumeEffects") * scareFactor
	groups.Ambience.Volume = master * setting("volumeAmbience") * duckFactor
	groups.Music.Volume = master * setting("volumeMusic") * (0.6 + 0.4 * duckFactor)
	groups.UI.Volume = master * setting("volumeUI")
end

-- Scare intensity / medic set dampen creature sounds.
function AudioController.SetScareFactor(value: number)
	scareFactor = value
	AudioController.ApplyVolumes()
end

-- Lowers ambience and music while important voices/radio play.
local duckToken = 0
function AudioController.Duck(seconds: number)
	duckToken += 1
	local token = duckToken
	duckFactor = 0.45
	AudioController.ApplyVolumes()
	task.delay(seconds, function()
		if token == duckToken then
			duckFactor = 1
			AudioController.ApplyVolumes()
		end
	end)
end

function AudioController.SetMenu(value: boolean)
	inMenu = value
end

local function updateMusic(position: Vector3, elapsed: number)
	local targets = { music_menu = 0, tension_low = 0, tension_high = 0 }
	if inMenu then
		targets.music_menu = 0.6
	else
		local nearest, chasing = math.huge, false
		for _, model in CollectionService:GetTagged("FZ_CreatureRig") do
			local root = model:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and model ~= Players.LocalPlayer.Character and not model:GetAttribute("Hidden") then
				local d = (root.Position - position).Magnitude
				if d < nearest then
					nearest = d
					chasing = model:GetAttribute("State") == "Chase" or model:GetAttribute("State") == "Attack"
				end
			end
		end
		if chasing and nearest < 90 then
			targets.tension_high, targets.tension_low = 0.8, 0.3
		elseif nearest < 45 then
			targets.tension_low = 0.75
		elseif nearest < math.huge then
			targets.tension_low = 0.25
		end
	end
	for name, target in targets do
		local sound = tension[name]
		if sound then
			-- fade in slowly, fade out a bit faster (silence is a tool)
			local speed = if target > tensionLevel[name] then 0.6 else 1.2
			tensionLevel[name] += (target - tensionLevel[name]) * math.min(1, elapsed * speed)
			sound.Volume = tensionLevel[name]
		end
	end
end

local function updateReverb(position: Vector3)
	local reverb
	if math.abs(position.X) < 22 and math.abs(position.Z) < 22 then
		reverb = Enum.ReverbType.ConcertHall -- the round core
	elseif insideBuilding(position) then
		reverb = Enum.ReverbType.Hallway
	else
		reverb = Enum.ReverbType.Forest
	end
	if reverb ~= currentReverb then
		currentReverb = reverb
		SoundService.AmbientReverb = reverb
	end
end


local function materialSound(material: Enum.Material): string
	if material == Enum.Material.Metal or material == Enum.Material.DiamondPlate or material == Enum.Material.CorrodedMetal then
		return "footstep_metal_" .. math.random(1, 2)
	elseif material == Enum.Material.Grass or material == Enum.Material.Ground or material == Enum.Material.Mud or material == Enum.Material.LeafyGrass then
		return "footstep_grass_" .. math.random(1, 2)
	end
	return "footstep_concrete_" .. math.random(1, 3)
end

function AudioController.Init(settingsController)
	settings = settingsController
	group("Ambience", 1)
	group("SFX", 1)
	group("Creature", 1)
	group("UI", 0.7)
	group("Music", 0.6)
	AudioController.ApplyVolumes()
	settingsController.Changed:Connect(function(key)
		if string.sub(key, 1, 6) == "volume" then
			AudioController.ApplyVolumes()
		end
	end)
	for name in tensionLevel do
		tension[name] = AudioController.Loop(name, SoundService, 0, "Music")
	end

	-- Ambient beds (2D), crossfaded by position
	local wind = AudioController.Loop("ambience_wind_loop", SoundService, 0)
	local hum = AudioController.Loop("hum_electric_loop", SoundService, 0)
	if wind then
		wind.RollOffMaxDistance = 10000
	end

	for _, source in CollectionService:GetTagged("FZ_AmbientSource") do
		local loopName = source:GetAttribute("SoundLoop")
		if type(loopName) == "string" then
			AudioController.Loop(loopName, source, 0.6)
		end
	end
	CollectionService:GetInstanceAddedSignal("FZ_AmbientSource"):Connect(function(source)
		local loopName = source:GetAttribute("SoundLoop")
		if type(loopName) == "string" then
			AudioController.Loop(loopName, source, 0.6)
		end
	end)

	Net.Event("Sfx").OnClientEvent:Connect(function(name, at, volume)
		if type(name) ~= "string" then
			return
		end
		local groupName = if string.sub(name, 1, 8) == "creature" then "Creature" else "SFX"
		AudioController.Play(name, at, if type(volume) == "number" then volume else nil, groupName)
	end)

	-- Footsteps + ambience mix, 10 Hz is enough
	local stepTimers: { [Model]: number } = {}
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		for model, timer in stepTimers do
			stepTimers[model] = timer - dt
		end
		if accumulator < 0.1 then
			return
		end
		local elapsed = accumulator
		accumulator = 0
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local inside = insideBuilding(camera.CFrame.Position)
		updateMusic(camera.CFrame.Position, elapsed)
		updateReverb(camera.CFrame.Position)
		if wind then
			wind.Volume += ((if inside then 0.12 else 0.55) - wind.Volume) * math.min(1, elapsed * 2)
		end
		if hum then
			hum.Volume += ((if inside then 0.35 else 0) - hum.Volume) * math.min(1, elapsed * 2)
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and not player:GetAttribute("FZ_MonsterMode") and (root.Position - camera.CFrame.Position).Magnitude < 60 then
				local velocity = root.AssemblyLinearVelocity
				local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				if speed > 2 and humanoid.FloorMaterial ~= Enum.Material.Air then
					local remaining = stepTimers[character :: Model] or 0
					if remaining <= 0 then
						local interval = math.clamp(4.2 / speed, 0.26, 0.65)
						stepTimers[character :: Model] = interval
						AudioController.Play(materialSound(humanoid.FloorMaterial), root.Position - Vector3.new(0, 2.5, 0), if speed > 13 then 0.9 else 0.55)
					end
				end
			end
		end
		for model in stepTimers do
			if not model.Parent then
				stepTimers[model] = nil
			end
		end
	end)
end

function AudioController.UI(name: string)
	AudioController.Play(name, nil, 0.5, "UI")
end

return AudioController
