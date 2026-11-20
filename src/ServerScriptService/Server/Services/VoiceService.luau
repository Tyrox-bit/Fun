-- VoiceService: proximity voice + walkie-talkie radio on top of the Roblox Audio API.
--
-- Per player (server):  AudioDeviceInput (microphone)
--   -> AudioFader "FZ_VoiceFader" (clients use it to mute someone locally)
--   -> AudioEmitter "FZ_VoiceEmitter" in the head (spatial: quieter with distance)
-- The radio is mixed on every client (VoiceController): while a player transmits, each
-- listener wires that player's microphone through a radio filter whose volume and static
-- depend on the distance between them.
--
-- Requirements (Studio, not scriptable): VoiceChatService.UseAudioApi = Enabled and
-- VoiceChatService.EnableDefaultVoice = false (both set in default.project.json).
-- Players without Roblox voice chat simply have no microphone; everything else works.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local NoiseService = require(script.Parent.NoiseService)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local VoiceService = {}

local transmitting: { [Player]: boolean } = {}

local function wire(source: Instance, target: Instance, parent: Instance)
	local w = Instance.new("Wire")
	w.SourceInstance = source
	w.TargetInstance = target
	w.Parent = parent
	return w
end

local function getInput(player: Player): Instance?
	local existing = player:FindFirstChildOfClass("AudioDeviceInput")
	if existing then
		return existing
	end
	local ok, input = pcall(function()
		local created = Instance.new("AudioDeviceInput")
		created.Name = "FZ_Microphone"
		;(created :: any).Player = player
		created.Parent = player
		return created
	end)
	if not ok then
		warn("[FZ-Voice] Audio API unavailable: " .. tostring(input))
		return nil
	end
	return input
end

local function setupCharacter(player: Player, character: Model)
	local input = getInput(player)
	local head = character:WaitForChild("Head", 10)
	if not input or not head then
		return
	end
	pcall(function()
		local fader = Instance.new("AudioFader")
		fader.Name = "FZ_VoiceFader"
		fader.Parent = head
		local emitter = Instance.new("AudioEmitter")
		emitter.Name = "FZ_VoiceEmitter"
		emitter.Parent = head
		;(emitter :: any):SetDistanceAttenuation({
			[0] = 1,
			[Config.Voice.ProximityFull] = 1,
			[Config.Voice.ProximityFull * 3] = 0.35,
			[Config.Voice.ProximityMax] = 0,
		})
		wire(input, fader, fader)
		wire(fader, emitter, emitter)
	end)
end

local function setTransmitting(player: Player, value: boolean)
	transmitting[player] = value or nil
	player:SetAttribute("FZ_RadioTx", value)
end

function VoiceService.Start()
	local radioLimiter = RateLimiter.new(8, 4)
	local muteLimiter = RateLimiter.new(6, 2)

	Net.Event("RadioState").OnServerEvent:Connect(function(player: Player, value: any)
		if type(value) ~= "boolean" or not radioLimiter:Allow(player) then
			return
		end
		if value and not player:GetAttribute("FZ_InGame") then
			return
		end
		setTransmitting(player, value)
	end)

	Net.Event("MicMute").OnServerEvent:Connect(function(player: Player, muted: any)
		if type(muted) ~= "boolean" or not muteLimiter:Allow(player) then
			return
		end
		local input = getInput(player)
		if input then
			pcall(function()
				(input :: any).Muted = muted
			end)
		end
		player:SetAttribute("FZ_MicMuted", muted)
	end)

	local function onPlayer(player: Player)
		player:SetAttribute("FZ_MicMuted", false)
		player:SetAttribute("FZ_RadioTx", false)
		player.CharacterAdded:Connect(function(character)
			setupCharacter(player, character)
		end)
		if player.Character then
			task.spawn(setupCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		transmitting[player] = nil
	end)

	-- A live radio is audible to the creature at the sender's position.
	task.spawn(function()
		while true do
			task.wait(1)
			for player in transmitting do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root then
					NoiseService.Emit((root :: BasePart).Position, Config.Noise.Radio, player)
				end
			end
		end
	end)
end

return VoiceService
