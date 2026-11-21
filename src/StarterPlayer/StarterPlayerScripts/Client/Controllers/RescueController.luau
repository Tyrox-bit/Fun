-- RescueController: everything around being down and helping someone up.
--   * You are down: bleed-out countdown, camera near the floor, hint about the syringe
--   * A teammate is down: an atmospheric "help" marker with the remaining time
--   * You are helping: you kneel (lower camera) and cannot move - you are vulnerable;
--     taking damage cancels the rescue. The prompt only shows if you carry a medkit.
--   * You are out: spectate your teammates (click / tap / A = next) until the team
--     reaches the next checkpoint or the survival break

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared.Localization)
local Net = require(Shared.Net)

local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)

local RescueController = {}

local player = Players.LocalPlayer
local markers: { [Player]: BillboardGui } = {}
local activeRescue: ProximityPrompt? = nil
local spectateIndex = 1

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function setCameraLow(depth: number)
	local h = humanoid()
	if h then
		h.CameraOffset = Vector3.new(0, -depth, 0)
	end
end

local function marker(target: Player)
	local old = markers[target]
	if old then
		old:Destroy()
		markers[target] = nil
	end
	if target == player or not target:GetAttribute("FZ_Downed") then
		return
	end
	local head = target.Character and target.Character:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "FZ_HelpMarker"
	gui.Size = UDim2.fromOffset(150, 46)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.AutoLocalize = false
	gui.Adornee = head :: BasePart
	local label = Components.Text({ Text = "", Font = Theme.Fonts.Mono, TextSize = 15, Color = Theme.Colors.Accent, XAlign = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = gui })
	label.TextStrokeTransparency = 0.3
	gui.Parent = player:WaitForChild("PlayerGui")
	markers[target] = gui
	task.spawn(function()
		while gui.Parent and target:GetAttribute("FZ_Downed") do
			local untilTime = target:GetAttribute("FZ_DownedUntil")
			local seconds = if type(untilTime) == "number" then math.max(0, math.ceil(untilTime - workspace:GetServerTimeNow())) else 0
			-- slow pulse instead of a bright blinking icon
			label.TextTransparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(os.clock() * 3))
			label.Text = Localization.T("HELP_MARKER", { name = target.DisplayName, seconds = seconds })
			task.wait(0.1)
		end
		gui:Destroy()
	end)
end

local function watch(target: Player)
	target:GetAttributeChangedSignal("FZ_Downed"):Connect(function()
		marker(target)
	end)
	target.CharacterAdded:Connect(function()
		task.wait(0.5)
		marker(target)
	end)
	marker(target)
end

-- Spectator camera while eliminated
local function teammates(): { Player }
	local list = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("FZ_InGame") and not other:GetAttribute("FZ_Eliminated") and other.Character then
			table.insert(list, other)
		end
	end
	return list
end

local function spectate()
	local camera = workspace.CurrentCamera
	local list = teammates()
	if #list == 0 or not camera then
		return
	end
	spectateIndex = ((spectateIndex - 1) % #list) + 1
	local target = list[spectateIndex]
	local h = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if h then
		camera.CameraSubject = h
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 8
	end
end

function RescueController.Init(hudGui: ScreenGui)
	local downedPanel = Components.Text({ Text = "", Font = Theme.Fonts.Medium, TextSize = Theme.Sizes.TextBody, Color = Theme.Colors.TextBright, XAlign = Enum.TextXAlignment.Center, AutoY = true, Size = UDim2.new(0.7, 0, 0, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = hudGui })
	downedPanel.TextStrokeTransparency = 0.4
	downedPanel.Visible = false

	local function refreshSelf()
		local downed = player:GetAttribute("FZ_Downed") == true
		local eliminated = player:GetAttribute("FZ_Eliminated") == true
		downedPanel.Visible = downed or eliminated
		setCameraLow(if downed then 2.2 else 0)
		if eliminated then
			spectateIndex = 1
			spectate()
		else
			local h = humanoid()
			local camera = workspace.CurrentCamera
			if h and camera and camera.CameraSubject ~= h then
				camera.CameraSubject = h
			end
			if player.CameraMode ~= Enum.CameraMode.LockFirstPerson and not player:GetAttribute("FZ_MonsterMode") then
				player.CameraMode = Enum.CameraMode.LockFirstPerson
				player.CameraMinZoomDistance = 0.5
			end
		end
	end
	player:GetAttributeChangedSignal("FZ_Downed"):Connect(refreshSelf)
	player:GetAttributeChangedSignal("FZ_Eliminated"):Connect(refreshSelf)

	RunService.Heartbeat:Connect(function()
		if not downedPanel.Visible then
			return
		end
		if player:GetAttribute("FZ_Eliminated") then
			downedPanel.Text = Localization.T("HUD_SPECTATING")
		else
			local untilTime = player:GetAttribute("FZ_DownedUntil")
			local seconds = if type(untilTime) == "number" then math.max(0, math.ceil(untilTime - workspace:GetServerTimeNow())) else 0
			downedPanel.Text = Localization.T("HUD_DOWNED_TIMER", { seconds = seconds })
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not player:GetAttribute("FZ_Eliminated") then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
			spectateIndex += 1
			spectate()
		end
	end)

	-- Helping someone up: kneel, frozen, cancelled by damage
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		if prompt:GetAttribute("FZ_Object") == "OBJECT_TEAMMATE" then
			activeRescue = prompt
			player:SetAttribute("FZ_Rescuing", true)
			setCameraLow(1.4)
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		if prompt == activeRescue then
			activeRescue = nil
			player:SetAttribute("FZ_Rescuing", nil)
			setCameraLow(0)
		end
	end)
	Net.Event("Hurt").OnClientEvent:Connect(function()
		local prompt = activeRescue
		if prompt then
			pcall(function()
				prompt:InputHoldEnd()
			end)
			activeRescue = nil
			player:SetAttribute("FZ_Rescuing", nil)
			setCameraLow(0)
		end
	end)

	for _, other in Players:GetPlayers() do
		watch(other)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(other)
		if markers[other] then
			markers[other]:Destroy()
			markers[other] = nil
		end
	end)
end

return RescueController
