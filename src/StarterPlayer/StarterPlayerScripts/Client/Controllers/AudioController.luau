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
local BUILDING_MIN = Vector3.new(-100, -5, -85)
local BUILDING_MAX = Vector3.new(100, 20, 85)

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

-- Plays a one-shot. `at` may be a Vector3, a BasePart/Attachment, or nil (2D).
function AudioController.Play(name: string, at: any?, volume: number?, groupName: string?): Sound?
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
	sound:Play()
	return sound
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

-- Lowers ambience while important voices/radio play (simple ducking).
function AudioController.Duck(active: boolean)
	local target = if active then 0.45 else 1
	TweenService:Create(groups.Ambience, TweenInfo.new(0.4), { Volume = target }):Play()
end

local function insideBuilding(position: Vector3): boolean
	return position.X > BUILDING_MIN.X and position.X < BUILDING_MAX.X and position.Z > BUILDING_MIN.Z and position.Z < BUILDING_MAX.Z and position.Y < BUILDING_MAX.Y
end

local function materialSound(material: Enum.Material): string
	if material == Enum.Material.Metal or material == Enum.Material.DiamondPlate or material == Enum.Material.CorrodedMetal then
		return "footstep_metal_" .. math.random(1, 2)
	elseif material == Enum.Material.Grass or material == Enum.Material.Ground or material == Enum.Material.Mud or material == Enum.Material.LeafyGrass then
		return "footstep_grass_" .. math.random(1, 2)
	end
	return "footstep_concrete_" .. math.random(1, 3)
end

function AudioController.Init()
	group("Ambience", 1)
	group("SFX", 1)
	group("Creature", 1)
	group("UI", 0.7)

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
