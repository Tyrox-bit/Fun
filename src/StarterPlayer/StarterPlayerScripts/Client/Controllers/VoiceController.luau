-- VoiceController: hearing voices on this client.
--
-- Proximity voice: one AudioListener on the camera hears every player's head emitter
-- (spatial, quieter with distance). Your own emitter is silenced locally so you never
-- hear yourself. Muting a teammate only changes YOUR local copy of their fader.
--
-- Radio (walkie-talkie, like Escape the Backrooms): while someone transmits, their
-- microphone is wired through a radio filter (band-pass + distortion) straight to your
-- speakers. Volume falls with distance and static rises; far away only static remains.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VoiceChatService = game:GetService("VoiceChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)

local AudioController = require(script.Parent.AudioController)

local VoiceController = {}
VoiceController.ReceivingChanged = Signal.new() -- (names: { string })

local localPlayer = Players.LocalPlayer
local output: Instance? = nil
local available = false
local locallyMuted: { [number]: boolean } = {}

type RadioChain = { nodes: { Instance }, fader: Instance, static: Sound? }
local radioChains: { [Player]: RadioChain } = {}

local function create(className: string, props: { [string]: any }, parent: Instance): Instance
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function wire(source: Instance, target: Instance, parent: Instance): Instance
	return create("Wire", { SourceInstance = source, TargetInstance = target }, parent)
end

local function voiceFader(player: Player): Instance?
	local head = player.Character and player.Character:FindFirstChild("Head")
	return head and head:FindFirstChild("FZ_VoiceFader")
end

local function applyLocalVolume(player: Player)
	local fader = voiceFader(player)
	if fader then
		local volume = if player == localPlayer or locallyMuted[player.UserId] then 0 else 1
		pcall(function()
			(fader :: any).Volume = volume
		end)
	end
end

local function distanceTo(player: Player): number
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = workspace.CurrentCamera
	if not root or not camera then
		return math.huge
	end
	return (root.Position - camera.CFrame.Position).Magnitude
end

local function radioVolume(distance: number): (number, number)
	local V = Config.Voice
	if distance <= V.RadioFull then
		return 1, 0.05
	end
	local t = math.clamp((distance - V.RadioFull) / (V.RadioMax - V.RadioFull), 0, 1)
	local voice = math.max(V.RadioMinVolume, (1 - t) ^ 1.6) * (if t >= 1 then 0 else 1)
	return voice, 0.05 + t * 0.5
end

local function stopRadio(player: Player)
	local chain = radioChains[player]
	if not chain then
		return
	end
	radioChains[player] = nil
	for _, node in chain.nodes do
		node:Destroy()
	end
	if chain.static then
		chain.static:Destroy()
	end
	AudioController.Play("radio_squelch_off", nil, 0.6, "SFX")
end

local function startRadio(player: Player)
	if radioChains[player] or player == localPlayer or locallyMuted[player.UserId] or not output then
		return
	end
	AudioController.Play("radio_squelch_on", nil, 0.6, "SFX")
	local static = AudioController.Loop("radio_static_loop", game:GetService("SoundService"), 0.05, "SFX")
	local input = player:FindFirstChildOfClass("AudioDeviceInput")
	local nodes = {}
	local fader = nil
	if input and available then
		local ok = pcall(function()
			local holder = Instance.new("Folder")
			holder.Name = "FZ_Radio_" .. player.UserId
			holder.Parent = localPlayer
			table.insert(nodes, holder)
			local bandpass = create("AudioFilter", { FilterType = Enum.AudioFilterType.Bandpass, Frequency = 1700, Q = 0.9 }, holder)
			local distortion = create("AudioDistortion", { Level = 0.35 }, holder)
			fader = create("AudioFader", { Volume = 1 }, holder)
			wire(input, bandpass, holder)
			wire(bandpass, distortion, holder)
			wire(distortion, fader, holder)
			wire(fader, output :: Instance, holder)
		end)
		if not ok then
			for _, node in nodes do
				node:Destroy()
			end
			nodes = {}
			fader = nil
		end
	end
	radioChains[player] = { nodes = nodes, fader = fader :: any, static = static }
end

local function refreshReceiving()
	local names = {}
	for player in radioChains do
		table.insert(names, player.DisplayName)
	end
	VoiceController.ReceivingChanged:Fire(names)
end

local function watchPlayer(player: Player)
	player:GetAttributeChangedSignal("FZ_RadioTx"):Connect(function()
		if player:GetAttribute("FZ_RadioTx") then
			startRadio(player)
		else
			stopRadio(player)
		end
		refreshReceiving()
	end)
	player.CharacterAdded:Connect(function(character)
		local head = character:WaitForChild("Head", 10)
		if head then
			head.ChildAdded:Connect(function(child)
				if child.Name == "FZ_VoiceFader" then
					applyLocalVolume(player)
				end
			end)
			applyLocalVolume(player)
		end
	end)
	applyLocalVolume(player)
end

function VoiceController.IsAvailable(): boolean
	return available
end

function VoiceController.SetMuted(player: Player, muted: boolean)
	locallyMuted[player.UserId] = muted or nil
	applyLocalVolume(player)
	if muted then
		stopRadio(player)
		refreshReceiving()
	end
end

function VoiceController.IsMuted(player: Player): boolean
	return locallyMuted[player.UserId] == true
end

function VoiceController.Init()
	local ok, enabled = pcall(function()
		return VoiceChatService:IsVoiceEnabledForUserIdAsync(localPlayer.UserId)
	end)
	available = ok and enabled == true

	pcall(function()
		local camera = workspace.CurrentCamera
		local listener = create("AudioListener", { Name = "FZ_Listener" }, camera)
		output = create("AudioDeviceOutput", { Name = "FZ_Output" }, localPlayer)
		wire(listener, output :: Instance, listener)
		workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			if workspace.CurrentCamera then
				listener.Parent = workspace.CurrentCamera
			end
		end)
	end)

	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player)
		stopRadio(player)
		refreshReceiving()
	end)

	-- Distance-based radio mix, 10 Hz
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 or next(radioChains) == nil then
			return
		end
		accumulator = 0
		for player, chain in radioChains do
			local voice, staticVolume = radioVolume(distanceTo(player))
			if chain.fader then
				pcall(function()
					(chain.fader :: any).Volume = voice
				end)
			end
			if chain.static then
				chain.static.Volume = staticVolume
			end
		end
	end)
end

return VoiceController
